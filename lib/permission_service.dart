import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  static Future<bool> hasAllFilesAccess() async {
    if (Platform.isAndroid) {
      return await Permission.manageExternalStorage.isGranted;
    }
    return true;
  }

  static Future<bool> requestAllFilesAccess(BuildContext context) async {
    if (!Platform.isAndroid) {
      return true;
    }

    final status = await Permission.manageExternalStorage.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied || status.isLimited) {
      final shouldRequest = await _showPermissionDialog(context);
      if (!shouldRequest) {
        return false;
      }

      final result = await Permission.manageExternalStorage.request();

      if (result.isPermanentlyDenied) {
        await _showSettingsDialog(context);
        return false;
      }

      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      await _showSettingsDialog(context);
      return false;
    }

    return false;
  }

  static Future<bool> _showPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('All Files Access Required'),
          content: const Text(
            'Multiversal needs "All files access" permission to browse and read comic books from your storage.\n\n'
            'This permission allows the app to access files on your device, including external storage like SD cards.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Grant Permission'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  static Future<void> _showSettingsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'All files access permission is permanently denied. '
            'Please go to Settings > Apps > Multiversal > Permissions and enable "All files access" manually.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  static Future<bool> checkAndRequestStoragePermissions(BuildContext context) async {
    if (!Platform.isAndroid) {
      return true;
    }

    final hasAccess = await hasAllFilesAccess();
    if (hasAccess) {
      return true;
    }

    return await requestAllFilesAccess(context);
  }
}