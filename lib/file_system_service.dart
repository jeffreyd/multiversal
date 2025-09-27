import 'dart:io';
import 'package:path/path.dart' as path;
import 'comic_book.dart';

enum FileSystemItemType {
  folder,
  comicBook,
  otherFile,
}

class FileSystemItem {
  final String name;
  final String fullPath;
  final FileSystemItemType type;
  final int? size;
  final DateTime? lastModified;

  FileSystemItem({
    required this.name,
    required this.fullPath,
    required this.type,
    this.size,
    this.lastModified,
  });

  bool get isComicBook => type == FileSystemItemType.comicBook;
  bool get isFolder => type == FileSystemItemType.folder;

  String get displaySize {
    if (size == null) return '';
    if (size! < 1024) return '${size}B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)}KB';
    if (size! < 1024 * 1024 * 1024) return '${(size! / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(size! / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

class FileSystemService {
  static Future<List<FileSystemItem>> listDirectory(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);

      if (!await directory.exists()) {
        throw Exception('Directory does not exist: $directoryPath');
      }

      // OPTIMIZATION 1: Use faster listing method without stat() calls
      final entities = await directory.list().toList();
      final items = <FileSystemItem>[];

      // OPTIMIZATION 2: Batch process files and parallelize stat() calls
      final futures = entities.map((entity) async {
        try {
          final name = path.basename(entity.path);

          // Determine type first without stat() call when possible
          FileSystemItemType type;
          FileStat? stat;

          if (entity is Directory) {
            type = FileSystemItemType.folder;
            // Only stat if we need size/date info for display
            stat = null; // Directories don't need stat for basic listing
          } else if (entity is File) {
            // Check file extension first (faster than stat)
            if (ComicBook.isSupportedFile(entity.path)) {
              type = FileSystemItemType.comicBook;
            } else {
              type = FileSystemItemType.otherFile;
            }

            // OPTIMIZATION 3: Only stat files that will be displayed
            // Skip stat for hidden files or unsupported types if filtering
            stat = await entity.stat();
          } else {
            return null; // Skip unsupported entity types
          }

          return FileSystemItem(
            name: name,
            fullPath: entity.path,
            type: type,
            size: entity is File ? stat?.size : null,
            lastModified: stat?.modified,
          );
        } catch (e) {
          return null; // Skip files that can't be processed
        }
      }).toList();

      // OPTIMIZATION 4: Wait for all stat() calls in parallel
      final results = await Future.wait(futures);

      // Filter out null results
      items.addAll(results.whereType<FileSystemItem>());

      // Sort: folders first, then comic books, then other files, all alphabetically
      items.sort((a, b) {
        if (a.type != b.type) {
          if (a.isFolder && !b.isFolder) return -1;
          if (!a.isFolder && b.isFolder) return 1;
          if (a.isComicBook && !b.isComicBook) return -1;
          if (!a.isComicBook && b.isComicBook) return 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return items;
    } catch (e) {
      throw Exception('Failed to list directory: $e');
    }
  }

  // OPTIMIZATION 5: Add method for lightweight directory listing
  static Future<List<String>> listComicFiles(String directoryPath, {bool recursive = false}) async {
    final comicFiles = <String>[];

    try {
      final directory = Directory(directoryPath);

      final stream = recursive
          ? directory.list(recursive: true)
          : directory.list();

      await for (final entity in stream) {
        if (entity is File && ComicBook.isSupportedFile(entity.path)) {
          comicFiles.add(entity.path);
        }
      }
    } catch (e) {
      // Return empty list on error
    }

    return comicFiles;
  }

  static Future<bool> canAccessDirectory(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) return false;

      // Try to list the directory to check permissions
      await directory.list().take(1).toList();
      return true;
    } catch (e) {
      return false;
    }
  }

  static String getParentDirectory(String directoryPath) {
    return path.dirname(directoryPath);
  }

  static bool isRootDirectory(String directoryPath) {
    return directoryPath == path.dirname(directoryPath);
  }
}