import 'dart:typed_data';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'rar_extractor_plugin.dart';
import 'rar_extractor.dart';

class CbrPreloader {
  final String filePath;
  final List<String> imageFiles;
  final Map<String, Uint8List> _cache = {};
  final Queue<int> _preloadQueue = Queue<int>();
  bool _isPreloading = false;
  bool _unrarAvailable = false;

  CbrPreloader({
    required this.filePath,
    required this.imageFiles,
  });

  Future<void> _checkUnrarAvailability() async {
    try {
      // Try system unrar first as fallback
      final process = await Process.run('unrar', ['-?']);
      _unrarAvailable = process.exitCode != 127;
    } catch (e) {
      _unrarAvailable = false;
    }
  }

  Future<Uint8List?> getImage(int index) async {
    if (index < 0 || index >= imageFiles.length) return null;

    final filename = imageFiles[index];

    // Return from cache if available
    if (_cache.containsKey(filename)) {
      return _cache[filename];
    }

    // Extract the image
    final imageData = await _extractSingleImage(filename);
    if (imageData != null) {
      _cache[filename] = imageData;
      _trimCache(); // Keep cache size reasonable
    }

    return imageData;
  }

  Future<void> preloadAround(int currentIndex) async {
    if (_isPreloading) return;

    _isPreloading = true;

    try {
      // Preload current + next 2 + previous 1
      final indicesToPreload = <int>{};

      // Current page (highest priority)
      indicesToPreload.add(currentIndex);

      // Next pages
      for (int i = 1; i <= 2; i++) {
        if (currentIndex + i < imageFiles.length) {
          indicesToPreload.add(currentIndex + i);
        }
      }

      // Previous page
      if (currentIndex - 1 >= 0) {
        indicesToPreload.add(currentIndex - 1);
      }

      // Extract in batches for efficiency
      await _batchExtract(indicesToPreload.toList());

    } finally {
      _isPreloading = false;
    }
  }

  Future<Uint8List?> _extractSingleImage(String filename) async {
    try {
      return await RarExtractorPlugin.extractFile(filePath, filename);
    } catch (e) {
      if (_unrarAvailable) {
        try {
          return await RarExtractor.extractFile(filePath, filename);
        } catch (e2) {
          debugPrint('Failed to extract $filename: $e2');
          return null;
        }
      }
      debugPrint('Failed to extract $filename: $e');
      return null;
    }
  }

  Future<void> _batchExtract(List<int> indices) async {
    // Group consecutive indices for more efficient extraction
    final batches = _groupConsecutive(indices);

    for (final batch in batches) {
      await _extractBatch(batch);
    }
  }

  List<List<int>> _groupConsecutive(List<int> indices) {
    if (indices.isEmpty) return [];

    indices.sort();
    final batches = <List<int>>[];
    var currentBatch = <int>[indices.first];

    for (int i = 1; i < indices.length; i++) {
      if (indices[i] == indices[i - 1] + 1 && currentBatch.length < 3) {
        // Add to current batch if consecutive and batch size < 3
        currentBatch.add(indices[i]);
      } else {
        // Start new batch
        batches.add(currentBatch);
        currentBatch = [indices[i]];
      }
    }
    batches.add(currentBatch);

    return batches;
  }

  Future<void> _extractBatch(List<int> indices) async {
    for (final index in indices) {
      if (index < 0 || index >= imageFiles.length) continue;

      final filename = imageFiles[index];

      // Skip if already cached
      if (_cache.containsKey(filename)) continue;

      final imageData = await _extractSingleImage(filename);
      if (imageData != null) {
        _cache[filename] = imageData;
      }

      // Small delay to keep UI responsive
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  void _trimCache() {
    // Keep cache size reasonable (max 10 images)
    const maxCacheSize = 10;

    if (_cache.length > maxCacheSize) {
      // Remove oldest entries (simple FIFO)
      final keys = _cache.keys.toList();
      final keysToRemove = keys.take(_cache.length - maxCacheSize);

      for (final key in keysToRemove) {
        _cache.remove(key);
      }
    }
  }

  bool isImageCached(int index) {
    if (index < 0 || index >= imageFiles.length) return false;
    return _cache.containsKey(imageFiles[index]);
  }

  void clearCache() {
    _cache.clear();
  }

  void dispose() {
    _cache.clear();
    _preloadQueue.clear();
  }

  // Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedImages': _cache.length,
      'totalImages': imageFiles.length,
      'cacheHitRatio': imageFiles.isEmpty ? 0.0 : _cache.length / imageFiles.length,
      'isPreloading': _isPreloading,
    };
  }
}