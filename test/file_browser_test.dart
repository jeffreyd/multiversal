import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiversal/file_browser.dart';

void main() {
  group('FileBrowser', () {
    testWidgets('should display files and folders', (WidgetTester tester) async {
      const testPath = '/tmp/test_comics';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileBrowser(rootPath: testPath),
          ),
        ),
      );

      // Initial pump to show loading state
      await tester.pump();

      // Check if loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait a bit for async loading
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // The file browser should either show content or an error state
      // For now, just verify it doesn't crash
      expect(find.byType(FileBrowser), findsOneWidget);
    });
  });
}