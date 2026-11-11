import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/database_helper.dart';
import '../data/image_storage.dart';
import '../models/models.dart';
import '../widgets/dialogs.dart';
import 'image_viewer_screen.dart';

class NoteEditorScreen extends StatefulWidget {
  final int groupId;
  final Note? note;
  const NoteEditorScreen({super.key, required this.groupId, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _db = DatabaseHelper.instance;
  final _picker = ImagePicker();
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final Future<void> _imagesFuture;

  final List<String> _images = [];
  final Set<String> _newPaths = {}; // copiadas en esta sesión
  final Set<String> _removed = {}; // existentes que el usuario quitó
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _content = TextEditingController(text: widget.note?.content ?? '');
    _imagesFuture = widget.note?.id == null ? Future.value() : _loadImages();
  }

  Future<void> _loadImages() async {
    final imgs = await _db.getImages(widget.note!.id!);
    if (!mounted) return;
    setState(() => _images.addAll(imgs));
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _saveAndClose() async {
    if (_saving) return;
    _saving = true;
    await _imagesFuture; // evita perder imágenes si se sale muy rápido

    final title = _title.text.trim();
    final content = _content.text.trim();
    final isNew = widget.note == null;

    if (isNew && title.isEmpty && content.isEmpty && _images.isEmpty) {
      await ImageStorage.deleteFiles(_newPaths);
    } else {
      await _db.saveNote(
        Note(
          id: widget.note?.id,
          groupId: widget.groupId,
          title: title,
          content: content,
          createdAt: 0,
          updatedAt: 0,
        ),
        _images,
      );
      await ImageStorage.deleteFiles(_removed);
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Eliminar anotación',
      message: '¿Eliminar esta anotación y sus imágenes?',
    );
    if (!ok) return;
    _saving = true;
    await _imagesFuture;
    await ImageStorage.deleteFiles(_newPaths);
    await _db.deleteNote(widget.note!.id!);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _addImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Galería'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Cámara'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
        ]),
      ),
    );
    if (source == null) return;

    try {
      final List<XFile> files;
      if (source == ImageSource.gallery) {
        files = await _picker.pickMultiImage(imageQuality: 85);
      } else {
        final f = await _picker.pickImage(source: source, imageQuality: 85);
        files = f == null ? [] : [f];
      }
      for (final f in files) {
        final saved = await ImageStorage.save(f);
        _newPaths.add(saved);
        if (!mounted) return;
        setState(() => _images.add(saved));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo agregar la imagen: $e')));
    }
  }

  void _removeImage(String path) {
    setState(() => _images.remove(path));
    if (_newPaths.remove(path)) {
      ImageStorage.deleteFiles([path]); // nunca llegó a la BD
    } else {
      _removed.add(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'Nueva nota' : 'Editar nota'),
          actions: [
            if (widget.note != null)
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(context).textTheme.headlineSmall,
              decoration: const InputDecoration(
                hintText: 'Título',
                border: InputBorder.none,
              ),
            ),
            TextField(
              controller: _content,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              minLines: 8,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Escribe tu anotación...',
                border: InputBorder.none,
              ),
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _images.map(_thumbnail).toList(),
              ),
            ],
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addImage,
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Imagen'),
        ),
      ),
    );
  }

  Widget _thumbnail(String path) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ImageViewerScreen(path: path)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(path),
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (_, __, ___) => Container(
                width: 100,
                height: 100,
                color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            onTap: () => _removeImage(path),
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}