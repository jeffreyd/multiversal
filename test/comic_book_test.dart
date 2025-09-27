import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiversal/comic_book.dart';
import 'package:archive/archive.dart';

void main() {
  group('ComicBook', () {
    test('should identify supported file formats', () {
      expect(ComicBook.isSupportedFile('test.cbz'), isTrue);
      expect(ComicBook.isSupportedFile('TEST.CBZ'), isTrue);
      expect(ComicBook.isSupportedFile('test.cbr'), isFalse);
      expect(ComicBook.isSupportedFile('TEST.CBR'), isFalse);
      expect(ComicBook.isSupportedFile('test.pdf'), isFalse);
      expect(ComicBook.isSupportedFile('test.txt'), isFalse);
    });

    test('should create ComicBook instance', () {
      final comic = ComicBook('/path/to/test.cbz');
      expect(comic.filePath, equals('/path/to/test.cbz'));
      expect(comic.isSupported, isTrue);
    });

    test('should handle unsupported file format', () {
      final comic = ComicBook('/path/to/test.pdf');
      expect(comic.isSupported, isFalse);
    });
  });

  group('ComicBookImage', () {
    test('should create image with archive file', () async {
      final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final archiveFile = ArchiveFile('test.jpg', testData.length, testData);
      final image = ComicBookImage('test.jpg', archiveFile);

      expect(image.name, equals('test.jpg'));
      expect(image.compressedSize, equals(testData.length));

      final data = await image.data;
      expect(data, equals([1, 2, 3, 4, 5]));

      // Test caching
      final data2 = await image.data;
      expect(data2, equals([1, 2, 3, 4, 5]));
    });

    test('should clear cache', () async {
      final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final archiveFile = ArchiveFile('test.jpg', testData.length, testData);
      final image = ComicBookImage('test.jpg', archiveFile);

      await image.data;

      image.clearCache();
      // Test that cache is cleared by loading again and checking data is still accessible
      final dataAfterClear = await image.data;
      expect(dataAfterClear, equals([1, 2, 3, 4, 5]));
    });
  });
}