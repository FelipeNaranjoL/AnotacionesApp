import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import 'image_storage.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const int _dbVersion = 3;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'notas.db');
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 -> v2: notas fijadas y color.
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE notes ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE notes ADD COLUMN color INTEGER NOT NULL DEFAULT 0');
        }
        // v2 -> v3: grupos fijados.
        if (oldVersion < 3) {
          await db.execute(
              'ALTER TABLE groups ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE groups(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            pinned INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            group_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            pinned INTEGER NOT NULL DEFAULT 0,
            color INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(group_id) REFERENCES groups(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE note_images(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            note_id INTEGER NOT NULL,
            path TEXT NOT NULL,
            FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_notes_group ON notes(group_id)');
        await db
            .execute('CREATE INDEX idx_images_note ON note_images(note_id)');
      },
    );
  }

  // ---------- Grupos ----------

  Future<List<NoteGroup>> getGroups() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT g.*,
        (SELECT COUNT(*) FROM notes n WHERE n.group_id = g.id) AS note_count
      FROM groups g
      ORDER BY g.pinned DESC, g.name COLLATE NOCASE
    ''');
    return rows.map(NoteGroup.fromMap).toList();
  }

  Future<void> insertGroup(String name) async {
    final db = await database;
    await db.insert('groups', {
      'name': name,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'pinned': 0,
    });
  }

  Future<void> renameGroup(int id, String name) async {
    final db = await database;
    await db.update('groups', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setGroupPinned(int id, bool pinned) async {
    final db = await database;
    await db.update('groups', {'pinned': pinned ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteGroup(int id) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT i.path FROM note_images i
      JOIN notes n ON n.id = i.note_id
      WHERE n.group_id = ?
    ''', [id]);
    final paths = rows.map((r) => r['path'] as String).toList();
    await db.delete('groups', where: 'id = ?', whereArgs: [id]);
    await ImageStorage.deleteFiles(paths);
  }

  // ---------- Notas ----------

  Future<List<Note>> getNotes(int groupId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT n.*,
        (SELECT COUNT(*) FROM note_images i WHERE i.note_id = n.id) AS image_count
      FROM notes n
      WHERE n.group_id = ?
      ORDER BY n.pinned DESC, n.updated_at DESC
    ''', [groupId]);
    return rows.map(Note.fromMap).toList();
  }

  Future<List<Note>> searchNotes(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final db = await database;
    final like = '%$q%';
    final rows = await db.rawQuery('''
      SELECT n.*, g.name AS group_name,
        (SELECT COUNT(*) FROM note_images i WHERE i.note_id = n.id) AS image_count
      FROM notes n
      JOIN groups g ON g.id = n.group_id
      WHERE n.title LIKE ? OR n.content LIKE ? OR g.name LIKE ?
      ORDER BY n.pinned DESC, n.updated_at DESC
    ''', [like, like, like]);
    return rows.map(Note.fromMap).toList();
  }

  Future<List<String>> getImages(int noteId) async {
    final db = await database;
    final rows = await db.query('note_images',
        where: 'note_id = ?', whereArgs: [noteId], orderBy: 'id');
    return rows.map((r) => r['path'] as String).toList();
  }

  /// Fija o desfija una nota sin alterar su fecha de edición.
  Future<void> setNotePinned(int id, bool pinned) async {
    final db = await database;
    await db.update('notes', {'pinned': pinned ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Inserta o actualiza la nota y reemplaza sus imágenes. Devuelve el id.
  Future<int> saveNote(Note note, List<String> images) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction((txn) async {
      int id;
      if (note.id == null) {
        id = await txn.insert('notes', {
          'group_id': note.groupId,
          'title': note.title,
          'content': note.content,
          'created_at': now,
          'updated_at': now,
          'pinned': note.pinned ? 1 : 0,
          'color': note.color,
        });
      } else {
        id = note.id!;
        await txn.update(
          'notes',
          {
            'title': note.title,
            'content': note.content,
            'updated_at': now,
            'pinned': note.pinned ? 1 : 0,
            'color': note.color,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.delete('note_images', where: 'note_id = ?', whereArgs: [id]);
      }
      for (final path in images) {
        await txn.insert('note_images', {'note_id': id, 'path': path});
      }
      return id;
    });
  }

  Future<void> deleteNote(int id) async {
    final paths = await getImages(id);
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    await ImageStorage.deleteFiles(paths);
  }
}