import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/models.dart';
import '../utils/note_colors.dart';
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
  final _searchCtrl = TextEditingController();
  List<Note> _notes = [];
  bool _loading = true;
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final notes = await _db.getNotes(widget.group.id!);
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  /// Filtro en memoria: toLowerCase() sí respeta ñ y tildes en mayúsculas.
  List<Note> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _notes;
    return _notes
        .where((n) =>
            n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q))
        .toList();
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

  Future<void> _togglePin(Note n) async {
    await _db.setNotePinned(n.id!, !n.pinned);
    _load();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchCtrl.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notes = _visible;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar en este grupo',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : Text(widget.group.name),
        actions: [
          IconButton(
            tooltip: _searching ? 'Cerrar búsqueda' : 'Buscar en el grupo',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _query.isNotEmpty
                          ? 'Sin resultados'
                          : 'Este grupo no tiene anotaciones.\nToca "Nueva nota" para crear una.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: notes.length,
                  itemBuilder: (_, i) {
                    final n = notes[i];
                    return Dismissible(
                      key: ValueKey('note_${n.id}'),
                      direction: DismissDirection.horizontal,
                      // Deslizar a la derecha: fijar / desfijar
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 24),
                        color: scheme.primaryContainer,
                        child: Icon(
                          n.pinned ? Icons.push_pin_outlined : Icons.push_pin,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      // Deslizar a la izquierda: eliminar
                      secondaryBackground: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: scheme.errorContainer,
                        child: Icon(Icons.delete,
                            color: scheme.onErrorContainer),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          await _togglePin(n);
                          return false; // la tarjeta se queda, solo cambia el orden
                        }
                        return confirmDialog(
                          context,
                          title: 'Eliminar anotación',
                          message: '¿Eliminar "${n.displayTitle}"?',
                        );
                      },
                      onDismissed: (_) async {
                        await _db.deleteNote(n.id!);
                        _load();
                      },
                      child: Card(
                        color: n.color == 0
                            ? null
                            : noteSurface(
                                context,
                                n.color,
                                base: scheme.surfaceContainerLow,
                              ),
                        child: ListTile(
                          title: Row(
                            children: [
                              if (n.pinned) ...[
                                const Icon(Icons.push_pin, size: 16),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(n.displayTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
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
                          onLongPress: () => _togglePin(n),
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