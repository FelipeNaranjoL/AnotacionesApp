import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/database_helper.dart';
import '../data/image_storage.dart';
import '../models/models.dart';
import '../utils/note_colors.dart';
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

  // Deshacer / rehacer: un historial por campo.
  // Los botones actúan sobre el último campo que tuvo el foco.
  final _titleUndo = UndoHistoryController();
  final _contentUndo = UndoHistoryController();
  final _titleFocus = FocusNode();
  final _contentFocus = FocusNode();
  bool _titleActive = false;

  late bool _pinned;
  late int _color;

  final List<String> _images = [];
  final Set<String> _newPaths = {}; // copiadas en esta sesión
  final Set<String> _removed = {}; // existentes que el usuario quitó
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _content = TextEditingController(text: widget.note?.content ?? '');
    _pinned = widget.note?.pinned ?? false;
    _color = widget.note?.color ?? 0;
    _imagesFuture = widget.note?.id == null ? Future.value() : _loadImages();

    _titleFocus.addListener(() {
      if (_titleFocus.hasFocus && !_titleActive) {
        setState(() => _titleActive = true);
      }
    });
    _contentFocus.addListener(() {
      if (_contentFocus.hasFocus && _titleActive) {
        setState(() => _titleActive = false);
      }
    });
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
    _titleUndo.dispose();
    _contentUndo.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
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
          pinned: _pinned,
          color: _color,
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

  Future<void> _pickColor() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: List.generate(noteSeeds.length, (i) {
              final selected = i == _color;
              final seed = noteSeed(i);
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, i),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: seed ?? Theme.of(ctx).colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? Theme.of(ctx).colorScheme.primary
                          : Theme.of(ctx).colorScheme.outlineVariant,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: i == 0
                      ? const Icon(Icons.format_color_reset, size: 20)
                      : selected
                          ? const Icon(Icons.check, color: Colors.black87)
                          : null,
                ),
              );
            }),
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _color = picked);
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo agregar la imagen: $e')));
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

  Widget _undoRedoButtons() {
    return ListenableBuilder(
      listenable: Listenable.merge([_titleUndo, _contentUndo]),
      builder: (context, _) {
        final c = _titleActive ? _titleUndo : _contentUndo;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Deshacer',
              icon: const Icon(Icons.undo),
              onPressed: c.value.canUndo ? c.undo : null,
            ),
            IconButton(
              tooltip: 'Rehacer',
              icon: const Icon(Icons.redo),
              onPressed: c.value.canRedo ? c.redo : null,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = noteSurface(context, _color);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndClose();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          scrolledUnderElevation: 0,
          title: Text(widget.note == null ? 'Nueva nota' : 'Editar nota'),
          actions: [
            _undoRedoButtons(),
            IconButton(
              tooltip: _pinned ? 'Quitar de fijadas' : 'Fijar nota',
              icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () => setState(() => _pinned = !_pinned),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'color' ? _pickColor() : _delete(),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'color', child: Text('Color')),
                if (widget.note != null)
                  const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextField(
              controller: _title,
              focusNode: _titleFocus,
              undoController: _titleUndo,
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(context).textTheme.headlineSmall,
              decoration: const InputDecoration(
                hintText: 'Título',
                border: InputBorder.none,
              ),
            ),
            if (widget.note != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Editado ${formatDate(widget.note!.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            TextField(
              controller: _content,
              focusNode: _contentFocus,
              undoController: _contentUndo,
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