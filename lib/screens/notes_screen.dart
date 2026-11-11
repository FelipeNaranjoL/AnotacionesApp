import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/models.dart';
import '../widgets/dialogs.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  final NoteGroup group;
  const NotesScreen({super.key, required this.group});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _db = DatabaseHelper.instance;
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await _db.getNotes(widget.group.id!);
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _openEditor([Note? note]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NoteEditorScreen(groupId: widget.group.id!, note: note),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Este grupo no tiene anotaciones.\nToca "Nueva nota" para crear una.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: _notes.length,
                  itemBuilder: (_, i) {
                    final n = _notes[i];
                    return Dismissible(
                      key: ValueKey('note_${n.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: const Icon(Icons.delete),
                      ),
                      confirmDismiss: (_) => confirmDialog(
                        context,
                        title: 'Eliminar anotación',
                        message: '¿Eliminar "${n.displayTitle}"?',
                      ),
                      onDismissed: (_) async {
                        await _db.deleteNote(n.id!);
                        _load();
                      },
                      child: Card(
                        child: ListTile(
                          title: Text(n.displayTitle,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (n.content.isNotEmpty)
                                Text(n.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(formatDate(n.updatedAt),
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                          trailing: n.imageCount > 0
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.image, size: 18),
                                    const SizedBox(width: 4),
                                    Text('${n.imageCount}'),
                                  ],
                                )
                              : null,
                          onTap: () => _openEditor(n),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.note_add),
        label: const Text('Nueva nota'),
      ),
    );
  }
}