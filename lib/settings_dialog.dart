import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'permission_service.dart';
import 'file_system_service.dart';

class SettingsDialog extends StatefulWidget {
  final String? currentDirectory;
  final Function(String?) onDirectoryChanged;

  const SettingsDialog({
    super.key,
    required this.currentDirectory,
    required this.onDirectoryChanged,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool _isChangingDirectory = false;

  String get _displayPath {
    if (widget.currentDirectory == null) return 'No directory selected';
    final path = widget.currentDirectory!;
    if (path.length > 50) {
      return '...${path.substring(path.length - 47)}';
    }
    return path;
  }


  Future<void> _changeDirectory() async {
    setState(() {
      _isChangingDirectory = true;
    });

    try {
      final hasPermission = await PermissionService.hasAllFilesAccess();
      if (!hasPermission) {
        if (!mounted) return;
        final granted = await PermissionService.requestAllFilesAccess(context);
        if (!granted) {
          setState(() {
            _isChangingDirectory = false;
          });
          return;
        }
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        final hasAccess = await FileSystemService.canAccessDirectory(selectedDirectory);

        if (hasAccess) {
          // Save the new directory
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('selected_folder_path', selectedDirectory);

          // Notify parent
          widget.onDirectoryChanged(selectedDirectory);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Directory changed to: ${_getDisplayPath(selectedDirectory)}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot access selected directory'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting directory: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isChangingDirectory = false;
      });
    }
  }

  String _getDisplayPath(String path) {
    if (path.length > 50) {
      return '...${path.substring(path.length - 47)}';
    }
    return path;
  }



  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings),
          SizedBox(width: 8),
          Text('Settings'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Directory Section
            Text(
              'Current Directory',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.folder,
                          color: widget.currentDirectory != null
                              ? Colors.blue
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _displayPath,
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isChangingDirectory ? null : _changeDirectory,
                        icon: _isChangingDirectory
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.folder_open),
                        label: Text(widget.currentDirectory == null
                            ? 'Select Directory'
                            : 'Change Directory'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Thumbnail Generation Section
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}