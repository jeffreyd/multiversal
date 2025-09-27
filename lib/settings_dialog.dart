import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'permission_service.dart';
import 'file_system_service.dart';
import 'comic_book.dart';

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
  bool _isGeneratingThumbnails = false;
  bool _isChangingDirectory = false;
  int _totalFiles = 0;
  int _processedFiles = 0;
  String _currentFile = '';

  String get _displayPath {
    if (widget.currentDirectory == null) return 'No directory selected';
    final path = widget.currentDirectory!;
    if (path.length > 50) {
      return '...${path.substring(path.length - 47)}';
    }
    return path;
  }

  double get _progress {
    if (_totalFiles == 0) return 0.0;
    return _processedFiles / _totalFiles;
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

  Future<List<String>> _findAllComicFiles(String directoryPath) async {
    // OPTIMIZATION: Use the optimized listComicFiles method
    return await FileSystemService.listComicFiles(directoryPath, recursive: true);
  }

  Future<void> _generateAllThumbnails() async {
    if (widget.currentDirectory == null || _isGeneratingThumbnails) return;

    setState(() {
      _isGeneratingThumbnails = true;
      _totalFiles = 0;
      _processedFiles = 0;
      _currentFile = '';
    });

    try {
      // Find all comic files recursively
      final comicFiles = await _findAllComicFiles(widget.currentDirectory!);

      setState(() {
        _totalFiles = comicFiles.length;
      });

      if (comicFiles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No comic files found in the selected directory'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _isGeneratingThumbnails = false;
        });
        return;
      }

      // Generate thumbnails for all files
      for (final filePath in comicFiles) {
        if (!_isGeneratingThumbnails) break; // Allow cancellation

        setState(() {
          _currentFile = filePath.split('/').last;
        });

        try {
          final comic = ComicBook(filePath);
          await comic.thumbnail; // This will generate and cache the thumbnail
          comic.dispose();
        } catch (e) {
          // Skip files that can't be processed
        }

        setState(() {
          _processedFiles++;
        });

        // Small delay to keep UI responsive
        await Future.delayed(const Duration(milliseconds: 10));
      }

      if (mounted && _isGeneratingThumbnails) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated thumbnails for $_processedFiles comic files'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating thumbnails: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isGeneratingThumbnails = false;
        _currentFile = '';
      });
    }
  }

  void _cancelThumbnailGeneration() {
    setState(() {
      _isGeneratingThumbnails = false;
      _currentFile = '';
    });
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
            Text(
              'Thumbnail Generation',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generate thumbnails for all comic files in the selected directory (including subfolders).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),

                    if (_isGeneratingThumbnails) ...[
                      LinearProgressIndicator(
                        value: _progress,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Progress: $_processedFiles / $_totalFiles',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_currentFile.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Processing: $_currentFile',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _cancelThumbnailGeneration,
                              icon: const Icon(Icons.stop),
                              label: const Text('Cancel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.currentDirectory != null
                              ? _generateAllThumbnails
                              : null,
                          icon: const Icon(Icons.image),
                          label: const Text('Generate All Thumbnails'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
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