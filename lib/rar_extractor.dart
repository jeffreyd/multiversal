import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;

class RarExtractor {
  static Future<bool> isUnrarAvailable() async {
    try {
      final result = await Process.run('unrar', []);
      return result.exitCode != 127; // 127 = command not found
    } catch (e) {
      return false;
    }
  }

  static Future<List<String>> listFiles(String rarPath) async {
    try {
      final result = await Process.run('unrar', ['l', '-c-', rarPath]);

      if (result.exitCode != 0) {
        throw Exception('Failed to list RAR contents: ${result.stderr}');
      }

      final lines = result.stdout.toString().split('\n');
      final files = <String>[];

      bool inFileList = false;
      for (final line in lines) {
        if (line.contains('Name')) {
          inFileList = true;
          continue;
        }
        if (inFileList && line.trim().isNotEmpty && !line.contains('-')) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.isNotEmpty) {
            final filename = parts.last;
            if (_isImageFile(filename)) {
              files.add(filename);
            }
          }
        }
      }

      files.sort();
      return files;
    } catch (e) {
      throw Exception('Failed to list RAR files: $e');
    }
  }

  static Future<Uint8List?> extractFile(String rarPath, String filename) async {
    try {
      final tempDir = Directory.systemTemp.createTempSync('multiversal_rar_');
      final outputPath = path.join(tempDir.path, filename);

      final result = await Process.run('unrar', [
        'e',
        '-o+', // overwrite files
        '-c-', // disable comments
        rarPath,
        filename,
        tempDir.path
      ]);

      if (result.exitCode != 0) {
        tempDir.deleteSync(recursive: true);
        throw Exception('Failed to extract file: ${result.stderr}');
      }

      final extractedFile = File(outputPath);
      if (!await extractedFile.exists()) {
        tempDir.deleteSync(recursive: true);
        return null;
      }

      final bytes = await extractedFile.readAsBytes();
      tempDir.deleteSync(recursive: true);

      return bytes;
    } catch (e) {
      throw Exception('Failed to extract RAR file: $e');
    }
  }

  static bool _isImageFile(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }
}