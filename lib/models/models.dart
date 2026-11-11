class NoteGroup {
  final int? id;
  final String name;
  final int createdAt;
  final int noteCount;

  const NoteGroup({
    this.id,
    required this.name,
    required this.createdAt,
    this.noteCount = 0,
  });

  factory NoteGroup.fromMap(Map<String, Object?> m) => NoteGroup(
        id: m['id'] as int?,
        name: m['name'] as String,
        createdAt: m['created_at'] as int,
        noteCount: (m['note_count'] as int?) ?? 0,
      );
}

class Note {
  final int? id;
  final int groupId;
  final String title;
  final String content;
  final int createdAt;
  final int updatedAt;
  final String? groupName; // solo se llena en búsquedas
  final int imageCount;

  const Note({
    this.id,
    required this.groupId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.groupName,
    this.imageCount = 0,
  });

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: m['id'] as int?,
        groupId: m['group_id'] as int,
        title: m['title'] as String,
        content: m['content'] as String,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
        groupName: m['group_name'] as String?,
        imageCount: (m['image_count'] as int?) ?? 0,
      );

  String get displayTitle => title.isEmpty ? 'Sin título' : title;
}

String formatDate(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}