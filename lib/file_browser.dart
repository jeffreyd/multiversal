import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'file_system_service.dart';
import 'comic_viewer.dart';
import 'read_status_service.dart';

class FileBrowser extends StatefulWidget {
  final String rootPath;
  final Function(String)? onComicBookSelected;

  const FileBrowser({
    super.key,
    required this.rootPath,
    this.onComicBookSelected,
  });

  @override
  State<FileBrowser> createState() => FileBrowserState();
}

class FileBrowserState extends State<FileBrowser> {
  String _currentPath = '';
  List<FileSystemItem> _items = [];
  bool _isLoading = false;
  String? _error;
  ReadStatusService? _readStatusService;
  Map<String, bool> _readStatusCache = {};
  bool _hideHiddenFiles = true;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.rootPath;
    _initReadStatusService();
    _loadSettings();
    _loadDirectory();
  }

  Future<void> _initReadStatusService() async {
    _readStatusService = await ReadStatusService.getInstance();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hideHiddenFiles = prefs.getBool('hide_hidden_files') ?? true;
    });
  }

  @override
  void didUpdateWidget(FileBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootPath != widget.rootPath) {
      _currentPath = widget.rootPath;
      _loadDirectory();
    }
  }

  // Public method to refresh the file browser
  void refresh() {
    _loadSettings().then((_) {
      if (mounted) {
        _loadDirectory();
      }
    });
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await FileSystemService.listDirectory(_currentPath, hideHiddenFiles: _hideHiddenFiles);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
          _error = null;
        });

        // Load read status for comic books
        _loadReadStatus();
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

  Future<void> _loadReadStatus() async {
    if (_readStatusService == null) return;

    final comicPaths = _items
        .where((item) => item.isComicBook)
        .map((item) => item.fullPath)
        .toList();

    if (comicPaths.isNotEmpty) {
      final readStatusMap = await _readStatusService!.getReadStatusBatch(comicPaths);
      if (mounted) {
        setState(() {
          _readStatusCache = readStatusMap;
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
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ComicViewer(filePath: item.fullPath),
            ),
          ).then((_) {
            // Refresh read status when returning from comic viewer
            _loadReadStatus();
          });
          widget.onComicBookSelected?.call(item.fullPath);
        }
      },
      trailing: item.isComicBook
          ? _buildReadBadge(item)
          : null,
    );
  }

  Widget _buildReadBadge(FileSystemItem item) {
    final isRead = _readStatusCache[item.fullPath] ?? false;

    if (isRead) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check,
              size: 16,
              color: Colors.white,
            ),
            SizedBox(width: 4),
            Text(
              'Read',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
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
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPathBar(),
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

