import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'file_browser.dart';
import 'file_system_service.dart';
import 'debug_helper.dart';
import 'permission_service.dart';
import 'settings_dialog.dart';

void main() {
  runApp(const MultiversalApp());
}

class MultiversalApp extends StatelessWidget {
  const MultiversalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multiversal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const FolderSelectionPage(),
    );
  }
}

class FolderSelectionPage extends StatefulWidget {
  const FolderSelectionPage({super.key});

  @override
  State<FolderSelectionPage> createState() => _FolderSelectionPageState();
}

class _FolderSelectionPageState extends State<FolderSelectionPage> {
  String? _selectedFolderPath;
  bool _isLoading = false;
  bool _hasValidAccess = false;
  final GlobalKey<FileBrowserState> _fileBrowserKey = GlobalKey<FileBrowserState>();

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadFolder();
  }

  Future<void> _checkPermissionsAndLoadFolder() async {
    final hasPermission = await PermissionService.checkAndRequestStoragePermissions(context);
    if (hasPermission) {
      await _loadSavedFolder();
    }
  }

  void _onDirectoryChanged(String? newDirectory) {
    setState(() {
      _selectedFolderPath = newDirectory;
      _hasValidAccess = newDirectory != null;
    });
  }

  Future<void> _showSettings() async {
    await showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        currentDirectory: _selectedFolderPath,
        onDirectoryChanged: _onDirectoryChanged,
      ),
    );
    // Refresh the file browser in case settings changed
    _fileBrowserKey.currentState?.refresh();
  }

  Future<void> _loadSavedFolder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('selected_folder_path');
    if (savedPath != null) {
      final hasAccess = await FileSystemService.canAccessDirectory(savedPath);
      setState(() {
        _selectedFolderPath = savedPath;
        _hasValidAccess = hasAccess;
      });
    }
  }

  Future<void> _saveFolderPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_folder_path', path);
  }

  Future<void> _selectFolder() async {
    final hasPermission = await PermissionService.hasAllFilesAccess();
    if (!hasPermission) {
      if (!mounted) return;
      final granted = await PermissionService.requestAllFilesAccess(context);
      if (!granted) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        final hasAccess = await FileSystemService.canAccessDirectory(selectedDirectory);
        setState(() {
          _selectedFolderPath = selectedDirectory;
          _hasValidAccess = hasAccess;
        });
        await _saveFolderPath(selectedDirectory);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(hasAccess
                ? 'Folder selected: ${_getDisplayPath(selectedDirectory)}'
                : 'Folder selected but access denied: ${_getDisplayPath(selectedDirectory)}'),
              backgroundColor: hasAccess ? Colors.green : Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting folder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getDisplayPath(String path) {
    if (path.length > 50) {
      return '...${path.substring(path.length - 47)}';
    }
    return path;
  }

  Widget _buildFolderSelection() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'Select a Folder',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Choose a folder to grant Multiversal access to your files.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (_selectedFolderPath != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Selected Folder:',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        if (!_hasValidAccess)
                          Icon(
                            Icons.warning,
                            color: Colors.orange,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getDisplayPath(_selectedFolderPath!),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (!_hasValidAccess) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Access denied to this folder',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _selectFolder,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open),
            label: Text(_selectedFolderPath == null ? 'Select Folder' : 'Change Folder'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _testKnownDirectory(),
            icon: const Icon(Icons.folder_special),
            label: const Text('Test /sdcard/Download'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testKnownDirectory() async {
    const testPath = '/storage/emulated/0/Download';

    try {
      final hasAccess = await FileSystemService.canAccessDirectory(testPath);

      if (hasAccess) {
        setState(() {
          _selectedFolderPath = testPath;
          _hasValidAccess = true;
        });
        await _saveFolderPath(testPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Set to Downloads folder for testing'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot access Downloads folder'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error testing directory: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiversal'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: 'Settings',
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () => DebugHelper.testCommonDirectories(context),
              tooltip: 'Test directories',
            ),
        ],
      ),
      body: _selectedFolderPath != null && _hasValidAccess
          ? FileBrowser(
              key: _fileBrowserKey,
              rootPath: _selectedFolderPath!,
              onComicBookSelected: (filePath) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Selected: ${_getDisplayPath(filePath)}'),
                  ),
                );
              },
            )
          : _buildFolderSelection(),
    );
  }
}
