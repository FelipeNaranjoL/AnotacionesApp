import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/models.dart';
import '../widgets/dialogs.dart';
import 'notes_screen.dart';
import 'search_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _db = DatabaseHelper.instance;
  List<NoteGroup> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = await _db.getGroups();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final name = await showNameDialog(context, title: 'Nuevo grupo');
    if (name == null) return;
    await _db.insertGroup(name);
    _load();
  }

  Future<void> _rename(NoteGroup g) async {
    final name =
        await showNameDialog(context, title: 'Renombrar grupo', initial: g.name);
    if (name == null) return;
    await _db.renameGroup(g.id!, name);
    _load();
  }

  Future<void> _delete(NoteGroup g) async {
    final ok = await confirmDialog(
      context,
      title: 'Eliminar grupo',
      message:
          'Se eliminará "${g.name}" con sus ${g.noteCount} anotaciones e imágenes. Esta acción no se puede deshacer.',
    );
    if (!ok) return;
    await _db.deleteGroup(g.id!);
    _load();
  }

  Future<void> _open(NoteGroup g) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => NotesScreen(group: g)));
    _load();
  }

  Future<void> _openSearch() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SearchScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis grupos'),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Aún no tienes grupos.\nToca "Nuevo grupo" para empezar.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: _groups.length,
                  itemBuilder: (_, i) {
                    final g = _groups[i];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.folder)),
                      title: Text(g.name),
                      subtitle: Text(g.noteCount == 1
                          ? '1 anotación'
                          : '${g.noteCount} anotaciones'),
                      onTap: () => _open(g),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) =>
                            v == 'rename' ? _rename(g) : _delete(g),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.create_new_folder),
        label: const Text('Nuevo grupo'),
      ),
    );
  }
}