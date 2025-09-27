import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:multiversal/main.dart';

void main() {
  testWidgets('Folder selection page loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MultiversalApp());

    expect(find.text('Multiversal'), findsOneWidget);
    expect(find.text('Select a Folder'), findsOneWidget);
    expect(find.text('Choose a folder to grant Multiversal access to your files.'), findsOneWidget);
    expect(find.text('Select Folder'), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
  });
}
