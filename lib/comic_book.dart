import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:image/image.dart' as img;
import 'thumbnail_cache.dart';

class ComicBookImage {
  final String name;
  final ArchiveFile _archiveFile;
  Uint8List? _cachedData;

  ComicBookImage(this.name, this._archiveFile);

  Future<Uint8List> get data async {
    _cachedData ??= _archiveFile.content as Uint8List;
    return _cachedData!;
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
  List<ArchiveFile>? _imageFiles;
  Uint8List? _thumbnailCache;

  ComicBook(this.filePath) : _fileExtension = filePath.toLowerCase().split('.').last;

  bool get isSupported => _fileExtension == 'cbz';

  // OPTIMIZATION 1: Optimized CBZ archive loading with streaming
  Future<Archive?> _loadArchive() async {
    if (_archive != null) return _archive;

    if (_fileExtension != 'cbz') {
      throw UnsupportedError('Only CBZ format is supported');
    }

    try {
      final file = File(filePath);
      final fileSize = await file.length();

      // For large files, consider using streaming approach
      if (fileSize > 100 * 1024 * 1024) { // 100MB threshold
        // Use streaming decoder for very large files
        final inputStream = InputFileStream(filePath);
        _archive = ZipDecoder().decodeBuffer(inputStream);
        inputStream.close();
      } else {
        // Standard approach for smaller files
        final bytes = await file.readAsBytes();
        _archive = ZipDecoder().decodeBytes(bytes);
      }

      return _archive;
    } catch (e) {
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

      final ext = file.name.toLowerCase().split('.').last;
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


  // OPTIMIZATION 6: Parallel thumbnail generation in isolate
  Future<Uint8List?> get thumbnail async {
    if (_thumbnailCache != null) return _thumbnailCache;

    try {
      final file = File(filePath);
      final stat = await file.stat();
      final lastModified = stat.modified;

      // Check cache first
      final cachedThumbnail = await ThumbnailCache.getThumbnail(filePath, lastModified);
      if (cachedThumbnail != null) {
        _thumbnailCache = cachedThumbnail;
        return _thumbnailCache;
      }

      final imageFiles = await _getImageFiles();
      if (imageFiles.isEmpty) return null;

      final imageData = imageFiles.first.content as Uint8List;

      // OPTIMIZATION 7: Generate thumbnail in isolate for large images
      if (imageData.length > 5 * 1024 * 1024) { // 5MB threshold
        _thumbnailCache = await _generateThumbnailInIsolate(imageData);
      } else {
        _thumbnailCache = await _generateThumbnailInMainThread(imageData);
      }

      if (_thumbnailCache != null) {
        await ThumbnailCache.saveThumbnail(filePath, lastModified, _thumbnailCache!);
      }

      return _thumbnailCache;
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List?> _generateThumbnailInMainThread(Uint8List imageData) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) return null;

      final thumbnail = img.copyResize(
        image,
        width: 200,
        height: 300,
        maintainAspect: true,
      );

      return Uint8List.fromList(img.encodePng(thumbnail));
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List?> _generateThumbnailInIsolate(Uint8List imageData) async {
    try {
      final receivePort = ReceivePort();

      await Isolate.spawn(_thumbnailIsolate, {
        'sendPort': receivePort.sendPort,
        'imageData': imageData,
      });

      final result = await receivePort.first as Uint8List?;
      return result;
    } catch (e) {
      // Fallback to main thread if isolate fails
      return await _generateThumbnailInMainThread(imageData);
    }
  }

  static void _thumbnailIsolate(Map<String, dynamic> params) {
    final sendPort = params['sendPort'] as SendPort;
    final imageData = params['imageData'] as Uint8List;

    try {
      final image = img.decodeImage(imageData);
      if (image == null) {
        sendPort.send(null);
        return;
      }

      final thumbnail = img.copyResize(
        image,
        width: 200,
        height: 300,
        maintainAspect: true,
      );

      final thumbnailData = Uint8List.fromList(img.encodePng(thumbnail));
      sendPort.send(thumbnailData);
    } catch (e) {
      sendPort.send(null);
    }
  }

  // OPTIMIZATION 8: Lazy-loaded images with better memory management
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

  // OPTIMIZATION 9: Get specific image by index without loading all
  Future<ComicBookImage?> getImageAt(int index) async {
    try {
      final imageFiles = await _getImageFiles();
      if (index < 0 || index >= imageFiles.length) return null;

      return ComicBookImage(imageFiles[index].name, imageFiles[index]);
    } catch (e) {
      return null;
    }
  }

  // OPTIMIZATION 10: Preload next few images for smooth reading
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
    _archive = null;
    _imageFiles = null;
    _thumbnailCache = null;
  }

  static bool isSupportedFile(String filePath) {
    final ext = filePath.toLowerCase().split('.').last;
    return ext == 'cbz';
  }
}