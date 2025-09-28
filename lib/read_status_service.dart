import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:io';

class ReadingProgress {
  final String fileHash;
  final int currentPage;
  final int totalPages;
  final DateTime lastRead;
  final bool isCompleted;

  ReadingProgress({
    required this.fileHash,
    required this.currentPage,
    required this.totalPages,
    required this.lastRead,
    this.isCompleted = false,
  });

  double get progressPercentage => totalPages > 0 ? currentPage / totalPages : 0.0;

  Map<String, dynamic> toJson() => {
    'fileHash': fileHash,
    'currentPage': currentPage,
    'totalPages': totalPages,
    'lastRead': lastRead.toIso8601String(),
    'isCompleted': isCompleted,
  };

  factory ReadingProgress.fromJson(Map<String, dynamic> json) => ReadingProgress(
    fileHash: json['fileHash'],
    currentPage: json['currentPage'],
    totalPages: json['totalPages'],
    lastRead: DateTime.parse(json['lastRead']),
    isCompleted: json['isCompleted'] ?? false,
  );
}

class ReadStatusService {
  static const String _readStatusKey = 'comic_read_status';
  static const String _readingProgressKey = 'comic_reading_progress';
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
  Future<void> markAsRead(String filePath, {int? totalPages}) async {
    try {
      final hash = await _generateFileHash(filePath);
      final readFiles = await _getReadFiles();

      if (!readFiles.contains(hash)) {
        readFiles.add(hash);
        await _saveReadFiles(readFiles);
      }

      // Also update reading progress to mark as completed
      if (totalPages != null) {
        await saveReadingProgress(filePath, totalPages - 1, totalPages, isCompleted: true);
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

      // Also remove reading progress
      await removeReadingProgress(filePath);
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

  /// Save reading progress for a comic file
  Future<void> saveReadingProgress(String filePath, int currentPage, int totalPages, {bool isCompleted = false}) async {
    try {
      final hash = await _generateFileHash(filePath);
      final progressMap = await _getReadingProgressMap();

      final progress = ReadingProgress(
        fileHash: hash,
        currentPage: currentPage,
        totalPages: totalPages,
        lastRead: DateTime.now(),
        isCompleted: isCompleted,
      );

      progressMap[hash] = progress;
      await _saveReadingProgressMap(progressMap);
    } catch (e) {
      print('Error saving reading progress: $e');
    }
  }

  /// Get reading progress for a comic file
  Future<ReadingProgress?> getReadingProgress(String filePath) async {
    try {
      final hash = await _generateFileHash(filePath);
      final progressMap = await _getReadingProgressMap();
      return progressMap[hash];
    } catch (e) {
      print('Error getting reading progress: $e');
      return null;
    }
  }

  /// Get reading progress for multiple files efficiently
  Future<Map<String, ReadingProgress?>> getReadingProgressBatch(List<String> filePaths) async {
    try {
      final progressMap = await _getReadingProgressMap();
      final result = <String, ReadingProgress?>{};

      for (final filePath in filePaths) {
        final hash = await _generateFileHash(filePath);
        result[filePath] = progressMap[hash];
      }

      return result;
    } catch (e) {
      print('Error getting batch reading progress: $e');
      return {};
    }
  }

  /// Get map of all reading progress data
  Future<Map<String, ReadingProgress>> _getReadingProgressMap() async {
    try {
      final progressJson = _prefs!.getString(_readingProgressKey);
      if (progressJson == null) return <String, ReadingProgress>{};

      final Map<String, dynamic> progressData = jsonDecode(progressJson);
      final result = <String, ReadingProgress>{};

      progressData.forEach((hash, data) {
        try {
          result[hash] = ReadingProgress.fromJson(data);
        } catch (e) {
          print('Error parsing progress data for hash $hash: $e');
        }
      });

      return result;
    } catch (e) {
      print('Error getting reading progress map: $e');
      return <String, ReadingProgress>{};
    }
  }

  /// Save map of reading progress data
  Future<void> _saveReadingProgressMap(Map<String, ReadingProgress> progressMap) async {
    try {
      final progressData = <String, dynamic>{};
      progressMap.forEach((hash, progress) {
        progressData[hash] = progress.toJson();
      });

      final progressJson = jsonEncode(progressData);
      await _prefs!.setString(_readingProgressKey, progressJson);
    } catch (e) {
      print('Error saving reading progress map: $e');
    }
  }

  /// Clear all reading progress data
  Future<void> clearAllReadingProgress() async {
    try {
      await _prefs!.remove(_readingProgressKey);
    } catch (e) {
      print('Error clearing reading progress: $e');
    }
  }

  /// Remove reading progress for a specific file
  Future<void> removeReadingProgress(String filePath) async {
    try {
      final hash = await _generateFileHash(filePath);
      final progressMap = await _getReadingProgressMap();

      if (progressMap.containsKey(hash)) {
        progressMap.remove(hash);
        await _saveReadingProgressMap(progressMap);
      }
    } catch (e) {
      print('Error removing reading progress: $e');
    }
  }
}