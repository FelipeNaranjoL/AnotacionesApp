import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copia las imágenes elegidas a la carpeta privada de la app
/// para que no dependan de la galería del usuario.
class ImageStorage {
  static Future<String> save(XFile file) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final ext = p.extension(file.path);
    final dest =
        p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}$ext');
    await File(file.path).copy(dest);
    return dest;
  }

  static Future<void> deleteFiles(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}