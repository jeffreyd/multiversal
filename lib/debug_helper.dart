import 'dart:io';
import 'package:flutter/material.dart';
import 'file_system_service.dart';
import 'thumbnail_cache.dart';

class DebugHelper {
  static Future<void> testCommonDirectories(BuildContext context) async {
    final commonPaths = [
      '/storage/emulated/0',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
      '/storage/emulated/0/Pictures',
      '/sdcard',
      '/sdcard/Download',
      '/sdcard/Documents',
    ];

    final results = <String>[];

    for (final path in commonPaths) {
      try {
        final directory = Directory(path);
        final exists = await directory.exists();

        if (exists) {
          final canAccess = await FileSystemService.canAccessDirectory(path);
          if (canAccess) {
            final items = await FileSystemService.listDirectory(path);
            results.add('✅ $path: ${items.length} items');
          } else {
            results.add('❌ $path: exists but no access');
          }
        } else {
          results.add('❌ $path: does not exist');
        }
      } catch (e) {
        results.add('❌ $path: error - $e');
      }
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Directory Test Results'),
          content: SingleChildScrollView(
            child: Text(results.join('\n')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  static List<String> getAndroidCommonPaths() {
    return [
      '/storage/emulated/0',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/DCIM',
      '/sdcard',
      '/sdcard/Download',
      '/sdcard/Documents',
    ];
  }

  static Future<void> showCacheInfo(BuildContext context) async {
    try {
      final cacheSize = await ThumbnailCache.getCacheSize();
      final cacheSizeMB = (cacheSize / (1024 * 1024)).toStringAsFixed(2);

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Thumbnail Cache Info'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cache size: ${cacheSizeMB}MB'),
                const SizedBox(height: 16),
                const Text('Cache stores generated thumbnails to improve performance.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () async {
                  await ThumbnailCache.clearCache();
                  Navigator.of(context).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cache cleared')),
                    );
                  }
                },
                child: const Text('Clear Cache'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading cache: $e')),
        );
      }
    }
  }
}