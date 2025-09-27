import 'package:flutter_test/flutter_test.dart';
import 'package:multiversal/file_system_service.dart';

void main() {
  group('FileSystemService', () {
    test('should list files and folders', () async {
      // Use the test directory we created
      const testPath = '/tmp/test_comics';

      final items = await FileSystemService.listDirectory(testPath);

      // Should find at least folders, comic books, and other files
      expect(items.length, greaterThan(0));

      // Check for specific items
      final folderItems = items.where((item) => item.type == FileSystemItemType.folder).toList();
      final comicItems = items.where((item) => item.type == FileSystemItemType.comicBook).toList();
      final otherItems = items.where((item) => item.type == FileSystemItemType.otherFile).toList();

      expect(folderItems.length, greaterThan(0)); // should find subfolder
      expect(comicItems.length, greaterThan(0)); // should find cbz files
      expect(otherItems.length, greaterThan(0)); // should find pdf/txt files
    });

    test('should detect comic book files correctly', () async {
      const testPath = '/tmp/test_comics';

      final items = await FileSystemService.listDirectory(testPath);
      final comicItems = items.where((item) => item.type == FileSystemItemType.comicBook).toList();

      // Should detect only CBZ files (CBR no longer supported)
      final cbzFiles = comicItems.where((item) => item.name.endsWith('.cbz')).toList();
      final cbrFiles = comicItems.where((item) => item.name.endsWith('.cbr')).toList();

      expect(cbzFiles.length, equals(1));
      expect(cbrFiles.length, equals(0)); // CBR files should not be detected as comic books
    });
  });
}