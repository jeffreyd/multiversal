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

      final entities = await directory.list().toList();

      final items = <FileSystemItem>[];

      for (final entity in entities) {
        try {
          final stat = await entity.stat();
          final name = path.basename(entity.path);

          FileSystemItemType type;
          if (entity is Directory) {
            type = FileSystemItemType.folder;
          } else if (entity is File && ComicBook.isSupportedFile(entity.path)) {
            type = FileSystemItemType.comicBook;
          } else if (entity is File) {
            type = FileSystemItemType.otherFile;
          } else {
            continue;
          }

          items.add(FileSystemItem(
            name: name,
            fullPath: entity.path,
            type: type,
            size: entity is File ? stat.size : null,
            lastModified: stat.modified,
          ));
        } catch (e) {
          continue;
        }
      }

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