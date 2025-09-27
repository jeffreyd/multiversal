import 'dart:io';
import 'package:flutter/material.dart';
import 'file_system_service.dart';

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
}