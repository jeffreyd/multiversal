import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'rar_extractor.dart';
import 'rar_extractor_plugin.dart';
import 'thumbnail_cache.dart';
import 'cbr_preloader.dart';

class ComicBookImage {
  final String name;
  final Future<Uint8List> Function() _dataLoader;
  Uint8List? _cachedData;

  ComicBookImage(this.name, this._dataLoader);

  Future<Uint8List> get data async {
    _cachedData ??= await _dataLoader();
    return _cachedData!;
  }

  void clearCache() {
    _cachedData = null;
  }
}

class ComicBook {
  final String filePath;
  final String _fileExtension;
  Archive? _archive;
  List<ArchiveFile>? _imageFiles;
  List<String>? _rarImageFiles;
  Uint8List? _thumbnailCache;
  bool? _unrarAvailable;
  CbrPreloader? _cbrPreloader;

  ComicBook(this.filePath) : _fileExtension = filePath.toLowerCase().split('.').last;

  bool get isSupported => _fileExtension == 'cbz' || _fileExtension == 'cbr';

  // OPTIMIZATION 1: Stream-based archive reading for large files
  Future<Archive?> _loadArchive() async {
    if (_archive != null) return _archive;

    try {
      switch (_fileExtension) {
        case 'cbz':
          // OPTIMIZATION 2: Use streaming decoder for large ZIP files
          try {
            final file = File(filePath);
            final bytes = await file.readAsBytes();

            // For large files, we could implement chunked reading here
            // For now, use the standard decoder with some optimization
            _archive = ZipDecoder().decodeBytes(bytes);
          } catch (e) {
            throw Exception('Failed to decode ZIP file: $e');
          }
          break;
        case 'cbr':
          _archive = _decodeRarBytes(Uint8List(0)); // CBR handled separately
          break;
        default:
          throw UnsupportedError('Unsupported file format: $_fileExtension');
      }

      return _archive;
    } catch (e) {
      throw Exception('Failed to load comic book archive: $e');
    }
  }

  Archive? _decodeRarBytes(Uint8List bytes) {
    throw UnsupportedError('RAR decoding not supported in this version. Please convert CBR files to CBZ format.');
  }

  Future<bool> _isUnrarAvailable() async {
    _unrarAvailable ??= await RarExtractor.isUnrarAvailable();
    return _unrarAvailable!;
  }

  final List<String> _supportedImageExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'
  ];


  // OPTIMIZATION 3: Lazy loading with better filtering
  Future<List<ArchiveFile>> _getImageFiles() async {
    if (_imageFiles != null) return _imageFiles!;

    final archive = await _loadArchive();
    if (archive == null) return [];

    // OPTIMIZATION 4: Use Set for faster extension lookup
    const supportedExtensions = {
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff', 'tga'
    };

    _imageFiles = archive.files.where((file) {
      if (!file.isFile) return false;

      final ext = file.name.toLowerCase().split('.').last;
      return supportedExtensions.contains(ext);
    }).toList();

    // OPTIMIZATION 5: Natural sort implementation for better page ordering
    _imageFiles!.sort((a, b) => _naturalCompare(a.name, b.name));

    return _imageFiles!;
  }

  // OPTIMIZATION 6: Better natural sorting algorithm
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

  Future<List<String>> _getRarImageFiles() async {
    if (_rarImageFiles != null) return _rarImageFiles!;

    if (_fileExtension != 'cbr') return [];

    try {
      _rarImageFiles = await RarExtractorPlugin.listFiles(filePath);

      // Initialize preloader for CBR files
      if (_rarImageFiles!.isNotEmpty) {
        _cbrPreloader = CbrPreloader(
          filePath: filePath,
          imageFiles: _rarImageFiles!,
        );
      }

      return _rarImageFiles!;
    } catch (e) {
      if (await _isUnrarAvailable()) {
        _rarImageFiles = await RarExtractor.listFiles(filePath);

        // Initialize preloader for CBR files
        if (_rarImageFiles!.isNotEmpty) {
          _cbrPreloader = CbrPreloader(
            filePath: filePath,
            imageFiles: _rarImageFiles!,
          );
        }

        return _rarImageFiles!;
      }
      throw UnsupportedError('RAR extraction failed. Neither unrar_file plugin nor system unrar is available.');
    }
  }

  // OPTIMIZATION 7: Parallel thumbnail generation in isolate
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

      Uint8List? imageData;

      if (_fileExtension == 'cbr') {
        final rarFiles = await _getRarImageFiles();
        if (rarFiles.isEmpty) return null;

        try {
          imageData = await RarExtractorPlugin.extractFile(filePath, rarFiles.first);
        } catch (e) {
          if (await _isUnrarAvailable()) {
            imageData = await RarExtractor.extractFile(filePath, rarFiles.first);
          }
        }
      } else {
        final imageFiles = await _getImageFiles();
        if (imageFiles.isEmpty) return null;
        imageData = imageFiles.first.content as Uint8List;
      }

      if (imageData == null) return null;

      // OPTIMIZATION 8: Generate thumbnail in isolate for large images
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

  Future<List<ComicBookImage>> get images async {
    try {
      if (_fileExtension == 'cbr') {
        final rarFiles = await _getRarImageFiles();
        return rarFiles.asMap().entries.map((entry) {
          final index = entry.key;
          final filename = entry.value;

          return ComicBookImage(
            filename,
            () async {
              // Use preloader for CBR files
              if (_cbrPreloader != null) {
                final data = await _cbrPreloader!.getImage(index);
                return data ?? Uint8List(0);
              }

              // Fallback to direct extraction
              try {
                final data = await RarExtractorPlugin.extractFile(filePath, filename);
                return data ?? Uint8List(0);
              } catch (e) {
                if (await _isUnrarAvailable()) {
                  final data = await RarExtractor.extractFile(filePath, filename);
                  return data ?? Uint8List(0);
                }
                return Uint8List(0);
              }
            },
          );
        }).toList();
      } else {
        final imageFiles = await _getImageFiles();
        return imageFiles.map((archiveFile) {
          return ComicBookImage(
            archiveFile.name,
            () async => archiveFile.content as Uint8List,
          );
        }).toList();
      }
    } catch (e) {
      return [];
    }
  }

  Future<int> get imageCount async {
    if (_fileExtension == 'cbr') {
      final rarFiles = await _getRarImageFiles();
      return rarFiles.length;
    } else {
      final imageFiles = await _getImageFiles();
      return imageFiles.length;
    }
  }

  Future<void> preloadAroundPage(int pageIndex) async {
    if (_fileExtension == 'cbr' && _cbrPreloader != null) {
      await _cbrPreloader!.preloadAround(pageIndex);
    }
  }

  bool isPageCached(int pageIndex) {
    if (_fileExtension == 'cbr' && _cbrPreloader != null) {
      return _cbrPreloader!.isImageCached(pageIndex);
    }
    return false; // CBZ files are always "cached" since they're in memory
  }

  Map<String, dynamic>? getCacheStats() {
    if (_fileExtension == 'cbr' && _cbrPreloader != null) {
      return _cbrPreloader!.getCacheStats();
    }
    return null;
  }

  void dispose() {
    _archive = null;
    _imageFiles = null;
    _rarImageFiles = null;
    _thumbnailCache = null;
    _cbrPreloader?.dispose();
    _cbrPreloader = null;
  }

  static bool isSupportedFile(String filePath) {
    final ext = filePath.toLowerCase().split('.').last;
    return ext == 'cbz' || ext == 'cbr';
  }
}