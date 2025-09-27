import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ThumbnailCache {
  static Directory? _cacheDir;

  static Future<Directory> get cacheDirectory async {
    if (_cacheDir != null) return _cacheDir!;

    final appCacheDir = await getApplicationCacheDirectory();
    _cacheDir = Directory(path.join(appCacheDir.path, 'comic_thumbnails'));

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    return _cacheDir!;
  }

  static String _getCacheKey(String filePath, DateTime? lastModified) {
    final input = '$filePath:${lastModified?.millisecondsSinceEpoch ?? 0}';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<String> _getCacheFilePath(String filePath, DateTime? lastModified) async {
    final cacheDir = await cacheDirectory;
    final key = _getCacheKey(filePath, lastModified);
    return path.join(cacheDir.path, '$key.png');
  }

  static Future<Uint8List?> getThumbnail(String filePath, DateTime? lastModified) async {
    try {
      final cacheFilePath = await _getCacheFilePath(filePath, lastModified);
      final cacheFile = File(cacheFilePath);

      if (await cacheFile.exists()) {
        return await cacheFile.readAsBytes();
      }
    } catch (e) {
      // Ignore cache read errors
    }
    return null;
  }

  static Future<void> saveThumbnail(String filePath, DateTime? lastModified, Uint8List thumbnailData) async {
    try {
      final cacheFilePath = await _getCacheFilePath(filePath, lastModified);
      final cacheFile = File(cacheFilePath);

      await cacheFile.writeAsBytes(thumbnailData);
    } catch (e) {
      // Ignore cache write errors
    }
  }

  static Future<void> clearCache() async {
    try {
      final cacheDir = await cacheDirectory;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
    } catch (e) {
      // Ignore cache clear errors
    }
  }

  static Future<int> getCacheSize() async {
    try {
      final cacheDir = await cacheDirectory;
      int totalSize = 0;

      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: true)) {
          if (entity is File) {
            final stat = await entity.stat();
            totalSize += stat.size;
          }
        }
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> cleanOldCache({Duration maxAge = const Duration(days: 30)}) async {
    try {
      final cacheDir = await cacheDirectory;
      final cutoffTime = DateTime.now().subtract(maxAge);

      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list()) {
          if (entity is File) {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoffTime)) {
              await entity.delete();
            }
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }
}