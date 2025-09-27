import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiversal/comic_book.dart';

void main() {
  group('ComicBook', () {
    test('should identify supported file formats', () {
      expect(ComicBook.isSupportedFile('test.cbz'), isTrue);
      expect(ComicBook.isSupportedFile('test.cbr'), isTrue);
      expect(ComicBook.isSupportedFile('TEST.CBZ'), isTrue);
      expect(ComicBook.isSupportedFile('TEST.CBR'), isTrue);
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
    test('should create image with lazy loading', () async {
      bool loadCalled = false;
      final image = ComicBookImage('test.jpg', () async {
        loadCalled = true;
        return Uint8List.fromList([1, 2, 3, 4, 5]);
      });

      expect(image.name, equals('test.jpg'));
      expect(loadCalled, isFalse);

      final data = await image.data;
      expect(loadCalled, isTrue);
      expect(data, equals([1, 2, 3, 4, 5]));

      loadCalled = false;
      final data2 = await image.data;
      expect(loadCalled, isFalse);
      expect(data2, equals([1, 2, 3, 4, 5]));
    });

    test('should clear cache', () async {
      int loadCallCount = 0;
      final image = ComicBookImage('test.jpg', () async {
        loadCallCount++;
        return Uint8List.fromList([1, 2, 3, 4, 5]);
      });

      await image.data;
      expect(loadCallCount, equals(1));

      await image.data;
      expect(loadCallCount, equals(1));

      image.clearCache();
      await image.data;
      expect(loadCallCount, equals(2));
    });
  });
}