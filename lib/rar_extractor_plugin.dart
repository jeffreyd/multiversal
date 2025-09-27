import 'dart:io';
import 'dart:typed_data';
import 'package:unrar_file/unrar_file.dart';
import 'package:path/path.dart' as path;

class RarExtractorPlugin {
  static Future<List<String>> listFiles(String rarPath) async {
    final tempDir = Directory.systemTemp.createTempSync('multiversal_rar_list_');

    try {
      await UnrarFile.extract_rar(rarPath, tempDir.path);

      final files = <String>[];
      await for (final entity in tempDir.list(recursive: true)) {
        if (entity is File) {
          final filename = path.relative(entity.path, from: tempDir.path);
          if (_isImageFile(filename)) {
            files.add(filename);
          }
        }
      }

      files.sort();
      return files;
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  static Future<Uint8List?> extractFile(String rarPath, String filename) async {
    final tempDir = Directory.systemTemp.createTempSync('multiversal_rar_extract_');

    try {
      await UnrarFile.extract_rar(rarPath, tempDir.path);

      final extractedFile = File(path.join(tempDir.path, filename));
      if (!await extractedFile.exists()) {
        return null;
      }

      return await extractedFile.readAsBytes();
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  static bool _isImageFile(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }
}