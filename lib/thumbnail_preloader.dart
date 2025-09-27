import 'dart:async';
import 'package:flutter/foundation.dart';
import 'file_system_service.dart';
import 'comic_book.dart';

class ThumbnailPreloader extends ChangeNotifier {
  bool _isPreloading = false;
  int _totalFiles = 0;
  int _processedFiles = 0;
  String _currentFile = '';
  StreamSubscription? _preloadSubscription;

  bool get isPreloading => _isPreloading;
  int get totalFiles => _totalFiles;
  int get processedFiles => _processedFiles;
  String get currentFile => _currentFile;
  double get progress => _totalFiles > 0 ? _processedFiles / _totalFiles : 0.0;

  Future<void> preloadThumbnails(List<FileSystemItem> items) async {
    if (_isPreloading) return;

    final comicFiles = items.where((item) => item.isComicBook).toList();

    if (comicFiles.isEmpty) return;

    _isPreloading = true;
    _totalFiles = comicFiles.length;
    _processedFiles = 0;
    _currentFile = '';
    notifyListeners();

    final controller = StreamController<FileSystemItem>();
    _preloadSubscription = controller.stream.listen(_processFile);

    // Add files to stream
    for (final file in comicFiles) {
      controller.add(file);
    }

    controller.close();
  }

  Future<void> _processFile(FileSystemItem item) async {
    try {
      _currentFile = item.name;
      notifyListeners();

      // Check if thumbnail already exists in cache
      final comic = ComicBook(item.fullPath);

      // This will generate and cache the thumbnail if it doesn't exist
      await comic.thumbnail;
      comic.dispose();

      _processedFiles++;
      notifyListeners();

      // Small delay to prevent blocking the UI
      await Future.delayed(const Duration(milliseconds: 50));

    } catch (e) {
      // Skip files that can't be processed
      _processedFiles++;
      notifyListeners();
    }

    // Check if we're done
    if (_processedFiles >= _totalFiles) {
      _isPreloading = false;
      _currentFile = '';
      notifyListeners();
    }
  }

  void cancel() {
    _preloadSubscription?.cancel();
    _preloadSubscription = null;
    _isPreloading = false;
    _currentFile = '';
    notifyListeners();
  }

  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}