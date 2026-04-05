import 'dart:typed_data';
import 'package:archive/archive_io.dart';

class ComicBookImage {
  final String name;
  final ArchiveFile _archiveFile;
  Uint8List? _cachedData;

  ComicBookImage(this.name, this._archiveFile);

  Future<Uint8List> get data async {
    if (_cachedData != null) return _cachedData!;

    try {
      final content = _archiveFile.content;
      if (content.isEmpty) {
        throw Exception('Image file is empty');
      }

      _cachedData = content;
      return _cachedData!;
    } catch (e) {
      throw Exception('Failed to extract image "$name": $e');
    }
  }

  // Get data size without loading content
  int get compressedSize => _archiveFile.size;

  void clearCache() {
    _cachedData = null;
  }
}

class ComicBook {
  final String filePath;
  final String _fileExtension;
  Archive? _archive;
  InputFileStream? _fileStream;
  List<ArchiveFile>? _imageFiles;

  ComicBook(this.filePath) : _fileExtension = filePath.toLowerCase().split('.').last;

  bool get isSupported => _fileExtension == 'cbz';

  // OPTIMIZATION 1: Optimized CBZ archive loading with streaming
  Future<Archive?> _loadArchive() async {
    if (_archive != null) return _archive;

    if (_fileExtension != 'cbz') {
      throw UnsupportedError('Only CBZ format is supported');
    }

    try {
      _fileStream = InputFileStream(filePath);
      _archive = ZipDecoder().decodeStream(_fileStream!);
      return _archive;
    } catch (e) {
      _fileStream?.closeSync();
      _fileStream = null;
      throw Exception('Failed to load CBZ archive: $e');
    }
  }


  // OPTIMIZATION 2: Lazy loading with better filtering
  Future<List<ArchiveFile>> _getImageFiles() async {
    if (_imageFiles != null) return _imageFiles!;

    final archive = await _loadArchive();
    if (archive == null) return [];

    // OPTIMIZATION 3: Use Set for faster extension lookup
    const supportedExtensions = {
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff', 'tga'
    };

    _imageFiles = archive.files.where((file) {
      if (!file.isFile) return false;

      final fileName = file.name.toLowerCase();

      // Skip files without extensions or with specific non-image extensions
      if (!fileName.contains('.')) return false;

      final parts = fileName.split('.');
      if (parts.length < 2) return false;

      final ext = parts.last;

      // Explicitly exclude common non-image files found in CBZ
      const excludedExtensions = {'xml', 'txt', 'nfo', 'db', 'ini'};
      if (excludedExtensions.contains(ext)) return false;

      return supportedExtensions.contains(ext);
    }).toList();

    // OPTIMIZATION 4: Natural sort implementation for better page ordering
    _imageFiles!.sort((a, b) => _naturalCompare(a.name, b.name));


    return _imageFiles!;
  }

  // OPTIMIZATION 5: Better natural sorting algorithm
  int _naturalCompare(String a, String b) {
    final regex = RegExp(r'(\d+)');
    final aMatches = regex.allMatches(a.toLowerCase()).toList();
    final bMatches = regex.allMatches(b.toLowerCase()).toList();

    for (int i = 0; i < aMatches.length && i < bMatches.length; i++) {
      final aNum = int.parse(aMatches[i].group(0)!);
      final bNum = int.parse(bMatches[i].group(0)!);

      if (aNum != bNum) {
        return aNum.compareTo(bNum);
      }
    }

    return a.toLowerCase().compareTo(b.toLowerCase());
  }


  // Lazy-loaded images with better memory management
  Future<List<ComicBookImage>> get images async {
    try {
      final imageFiles = await _getImageFiles();
      return imageFiles.map((archiveFile) {
        return ComicBookImage(archiveFile.name, archiveFile);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Get specific image by index without loading all
  Future<ComicBookImage?> getImageAt(int index) async {
    try {
      final imageFiles = await _getImageFiles();
      if (index < 0 || index >= imageFiles.length) return null;

      return ComicBookImage(imageFiles[index].name, imageFiles[index]);
    } catch (e) {
      return null;
    }
  }

  // Preload next few images for smooth reading
  Future<void> preloadImages(int startIndex, int count) async {
    try {
      final imageFiles = await _getImageFiles();
      final endIndex = (startIndex + count).clamp(0, imageFiles.length);

      for (int i = startIndex; i < endIndex; i++) {
        // Trigger content loading in background
        final _ = imageFiles[i].content;
      }
    } catch (e) {
      // Ignore preload errors
    }
  }

  Future<int> get imageCount async {
    final imageFiles = await _getImageFiles();
    return imageFiles.length;
  }

  Future<void> preloadAroundPage(int pageIndex) async {
    // CBZ files are loaded into memory, so no preloading needed
  }

  bool isPageCached(int pageIndex) {
    // CBZ files are always "cached" since they're loaded in memory
    return true;
  }

  Map<String, dynamic>? getCacheStats() {
    // No cache stats for CBZ files as they're fully loaded
    return null;
  }

  void dispose() {
    _fileStream?.closeSync();
    _fileStream = null;
    _archive = null;
    _imageFiles = null;
  }

  static bool isSupportedFile(String filePath) {
    final ext = filePath.toLowerCase().split('.').last;
    return ext == 'cbz';
  }
}