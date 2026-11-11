import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/models.dart';
import 'note_editor_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _db = DatabaseHelper.instance;
  final _ctrl = TextEditingController();
  List<Note> _results = [];
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    _query = q;
    final res = await _db.searchNotes(q);
    if (!mounted || q != _query) return; // descarta respuestas viejas
    setState(() => _results = res);
  }

  Future<void> _open(Note n) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(groupId: n.groupId, note: n),
      ),
    );
    _search(_ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _ctrl.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar en título, contenido o grupo',
            border: InputBorder.none,
          ),
          onChanged: _search,
        ),
        actions: [
          if (hasQuery)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _ctrl.clear();
                _search('');
                setState(() {});
              },
            ),
        ],
      ),
      body: !hasQuery
          ? const Center(child: Text('Escribe para buscar'))
          : _results.isEmpty
              ? const Center(child: Text('Sin resultados'))
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final n = _results[i];
                    return ListTile(
                      title: Text(n.displayTitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${n.groupName ?? ''}'
                        '${n.content.isEmpty ? '' : '  •  ${n.content}'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing:
                          n.imageCount > 0 ? const Icon(Icons.image, size: 18) : null,
                      onTap: () => _open(n),
                    );
                  },
                ),
    );
  }
}