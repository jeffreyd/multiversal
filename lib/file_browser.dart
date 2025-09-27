import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'file_system_service.dart';
import 'comic_book.dart';
import 'thumbnail_preloader.dart';

class FileBrowser extends StatefulWidget {
  final String rootPath;
  final Function(String)? onComicBookSelected;

  const FileBrowser({
    super.key,
    required this.rootPath,
    this.onComicBookSelected,
  });

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  String _currentPath = '';
  List<FileSystemItem> _items = [];
  bool _isLoading = false;
  String? _error;
  late ThumbnailPreloader _thumbnailPreloader;

  @override
  void initState() {
    super.initState();
    _thumbnailPreloader = ThumbnailPreloader();
    _currentPath = widget.rootPath;
    _loadDirectory();
  }

  @override
  void didUpdateWidget(FileBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootPath != widget.rootPath) {
      _currentPath = widget.rootPath;
      _loadDirectory();
    }
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await FileSystemService.listDirectory(_currentPath);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
          _error = null;
        });

        // Start preloading thumbnails for comic books
        _thumbnailPreloader.preloadThumbnails(items);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load directory: ${e.toString()}';
          _isLoading = false;
          _items = [];
        });
      }
    }
  }

  void _navigateToFolder(String folderPath) {
    setState(() {
      _currentPath = folderPath;
    });
    _loadDirectory();
  }

  void _navigateUp() {
    if (!FileSystemService.isRootDirectory(_currentPath)) {
      final parentPath = FileSystemService.getParentDirectory(_currentPath);
      // Don't go above the root path
      if (parentPath.startsWith(widget.rootPath)) {
        _navigateToFolder(parentPath);
      }
    }
  }

  Widget _buildPathBar() {
    final relativePath = _currentPath.replaceFirst(widget.rootPath, '');
    final displayPath = relativePath.isEmpty ? '/' : relativePath;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          if (_currentPath != widget.rootPath)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _navigateUp,
              tooltip: 'Go up',
            ),
          Expanded(
            child: Text(
              displayPath,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDirectory,
            tooltip: 'Refresh',
          ),
          // Show thumbnail progress
          ListenableBuilder(
            listenable: _thumbnailPreloader,
            builder: (context, child) {
              if (_thumbnailPreloader.isPreloading) {
                return SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: _thumbnailPreloader.progress,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildFileItem(FileSystemItem item) {
    IconData icon;
    Color? iconColor;

    switch (item.type) {
      case FileSystemItemType.folder:
        icon = Icons.folder;
        iconColor = Colors.blue;
        break;
      case FileSystemItemType.comicBook:
        icon = Icons.menu_book;
        iconColor = Colors.orange;
        break;
      case FileSystemItemType.otherFile:
        icon = Icons.description;
        iconColor = Colors.grey;
        break;
    }

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        item.name,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: item.isFolder
          ? null
          : Text(
              '${item.displaySize}${item.lastModified != null ? ' • ${_formatDate(item.lastModified!)}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
      onTap: () {
        if (item.isFolder) {
          _navigateToFolder(item.fullPath);
        } else if (item.isComicBook) {
          widget.onComicBookSelected?.call(item.fullPath);
        }
      },
      trailing: item.isComicBook
          ? FutureBuilder<ComicBookThumbnail?>(
              future: _loadThumbnail(item.fullPath),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Container(
                    width: 40,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      image: DecorationImage(
                        image: MemoryImage(snapshot.data!.data),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                }
                return const SizedBox(width: 40, height: 60);
              },
            )
          : null,
    );
  }

  Future<ComicBookThumbnail?> _loadThumbnail(String filePath) async {
    try {
      final comic = ComicBook(filePath);
      final thumbnailData = await comic.thumbnail;
      comic.dispose();

      if (thumbnailData != null) {
        return ComicBookThumbnail(data: thumbnailData);
      }
    } catch (e) {
      // Ignore thumbnail loading errors
    }
    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isExternalStoragePath() {
    return _currentPath.startsWith('/storage/') &&
           _currentPath.contains('-') &&
           !_currentPath.startsWith('/storage/emulated/0');
  }

  @override
  void dispose() {
    _thumbnailPreloader.dispose();
    super.dispose();
  }

  Widget _buildThumbnailProgress() {
    return ListenableBuilder(
      listenable: _thumbnailPreloader,
      builder: (context, child) {
        if (!_thumbnailPreloader.isPreloading) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: _thumbnailPreloader.progress,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Generating thumbnails... ${_thumbnailPreloader.processedFiles}/${_thumbnailPreloader.totalFiles}',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_thumbnailPreloader.currentFile.isNotEmpty)
                Expanded(
                  child: Text(
                    _thumbnailPreloader.currentFile,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPathBar(),
        _buildThumbnailProgress(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading directory',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadDirectory,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.folder_off_outlined,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No files or folders found',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (_isExternalStoragePath()) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Column(
                                    children: [
                                      Text(
                                        'External Storage Limitation',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: Colors.orange,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'This SD card folder appears empty due to Android scoped storage restrictions. Try:',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '• Copy files to internal storage\n• Use a different folder\n• Grant "All files access" in Android settings',
                                        style: Theme.of(context).textTheme.bodySmall,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            return _buildFileItem(_items[index]);
                          },
                        ),
        ),
      ],
    );
  }
}

class ComicBookThumbnail {
  final Uint8List data;

  ComicBookThumbnail({required this.data});
}