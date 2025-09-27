import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:io';

class ReadStatusService {
  static const String _readStatusKey = 'comic_read_status';
  static ReadStatusService? _instance;
  static SharedPreferences? _prefs;

  ReadStatusService._();

  static Future<ReadStatusService> getInstance() async {
    _instance ??= ReadStatusService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  /// Generate a unique hash for a comic file based on path and file size
  Future<String> _generateFileHash(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();
      final sizeString = stat.size.toString();
      final pathString = filePath;

      // Create hash from path + size for unique identification
      final bytes = utf8.encode('$pathString:$sizeString');
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      // Fallback to just path-based hash if file stat fails
      final bytes = utf8.encode(filePath);
      final digest = sha256.convert(bytes);
      return digest.toString();
    }
  }

  /// Mark a comic file as read
  Future<void> markAsRead(String filePath) async {
    try {
      final hash = await _generateFileHash(filePath);
      final readFiles = await _getReadFiles();

      if (!readFiles.contains(hash)) {
        readFiles.add(hash);
        await _saveReadFiles(readFiles);
      }
    } catch (e) {
      print('Error marking file as read: $e');
    }
  }

  /// Mark a comic file as unread
  Future<void> markAsUnread(String filePath) async {
    try {
      final hash = await _generateFileHash(filePath);
      final readFiles = await _getReadFiles();

      readFiles.remove(hash);
      await _saveReadFiles(readFiles);
    } catch (e) {
      print('Error marking file as unread: $e');
    }
  }

  /// Check if a comic file has been read
  Future<bool> isRead(String filePath) async {
    try {
      final hash = await _generateFileHash(filePath);
      final readFiles = await _getReadFiles();
      return readFiles.contains(hash);
    } catch (e) {
      print('Error checking read status: $e');
      return false;
    }
  }

  /// Get list of all read file hashes
  Future<Set<String>> _getReadFiles() async {
    try {
      final readFilesJson = _prefs!.getString(_readStatusKey);
      if (readFilesJson == null) return <String>{};

      final List<dynamic> readFilesList = jsonDecode(readFilesJson);
      return readFilesList.cast<String>().toSet();
    } catch (e) {
      print('Error getting read files: $e');
      return <String>{};
    }
  }

  /// Save list of read file hashes
  Future<void> _saveReadFiles(Set<String> readFiles) async {
    try {
      final readFilesJson = jsonEncode(readFiles.toList());
      await _prefs!.setString(_readStatusKey, readFilesJson);
    } catch (e) {
      print('Error saving read files: $e');
    }
  }

  /// Get read status for multiple files efficiently
  Future<Map<String, bool>> getReadStatusBatch(List<String> filePaths) async {
    try {
      final readFiles = await _getReadFiles();
      final result = <String, bool>{};

      for (final filePath in filePaths) {
        final hash = await _generateFileHash(filePath);
        result[filePath] = readFiles.contains(hash);
      }

      return result;
    } catch (e) {
      print('Error getting batch read status: $e');
      return {};
    }
  }

  /// Clear all read status data
  Future<void> clearAllReadStatus() async {
    try {
      await _prefs!.remove(_readStatusKey);
    } catch (e) {
      print('Error clearing read status: $e');
    }
  }

  /// Get total number of read comics
  Future<int> getReadCount() async {
    try {
      final readFiles = await _getReadFiles();
      return readFiles.length;
    } catch (e) {
      print('Error getting read count: $e');
      return 0;
    }
  }
}