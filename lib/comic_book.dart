import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'rar_extractor.dart';
import 'rar_extractor_plugin.dart';
import 'thumbnail_cache.dart';

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

  ComicBook(this.filePath) : _fileExtension = filePath.toLowerCase().split('.').last;

  bool get isSupported => _fileExtension == 'cbz' || _fileExtension == 'cbr';

  Future<Archive?> _loadArchive() async {
    if (_archive != null) return _archive;

    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      switch (_fileExtension) {
        case 'cbz':
          _archive = ZipDecoder().decodeBytes(bytes);
          break;
        case 'cbr':
          _archive = _decodeRarBytes(bytes);
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

  bool _isImageFile(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    return _supportedImageExtensions.contains(ext);
  }

  Future<List<ArchiveFile>> _getImageFiles() async {
    if (_imageFiles != null) return _imageFiles!;

    final archive = await _loadArchive();
    if (archive == null) return [];

    _imageFiles = archive.files
        .where((file) => !file.isFile || _isImageFile(file.name))
        .where((file) => file.isFile)
        .toList();

    _imageFiles!.sort((a, b) => a.name.compareTo(b.name));

    return _imageFiles!;
  }

  Future<List<String>> _getRarImageFiles() async {
    if (_rarImageFiles != null) return _rarImageFiles!;

    if (_fileExtension != 'cbr') return [];

    try {
      _rarImageFiles = await RarExtractorPlugin.listFiles(filePath);
      return _rarImageFiles!;
    } catch (e) {
      if (await _isUnrarAvailable()) {
        _rarImageFiles = await RarExtractor.listFiles(filePath);
        return _rarImageFiles!;
      }
      throw UnsupportedError('RAR extraction failed. Neither unrar_file plugin nor system unrar is available.');
    }
  }

  Future<Uint8List?> get thumbnail async {
    if (_thumbnailCache != null) return _thumbnailCache;

    try {
      // Get file modification time for cache key
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

      final image = img.decodeImage(imageData);
      if (image == null) return null;

      final thumbnail = img.copyResize(
        image,
        width: 200,
        height: 300,
        maintainAspect: true,
      );

      _thumbnailCache = Uint8List.fromList(img.encodePng(thumbnail));

      // Save to cache
      await ThumbnailCache.saveThumbnail(filePath, lastModified, _thumbnailCache!);

      return _thumbnailCache;
    } catch (e) {
      return null;
    }
  }

  Future<List<ComicBookImage>> get images async {
    try {
      if (_fileExtension == 'cbr') {
        final rarFiles = await _getRarImageFiles();
        return rarFiles.map((filename) {
          return ComicBookImage(
            filename,
            () async {
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

  void dispose() {
    _archive = null;
    _imageFiles = null;
    _rarImageFiles = null;
    _thumbnailCache = null;
  }

  static bool isSupportedFile(String filePath) {
    final ext = filePath.toLowerCase().split('.').last;
    return ext == 'cbz' || ext == 'cbr';
  }
}