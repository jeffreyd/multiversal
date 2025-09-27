# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter project called "multiversal" - a new Flutter application using Dart SDK ^3.9.2. The project is currently in its initial state with the standard Flutter counter demo app.

## Development Commands

### Build and Run
- `flutter run` - Run the app in debug mode
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app (requires macOS)

### Testing
- `flutter test` - Run all tests
- `flutter test test/widget_test.dart` - Run specific test file

### Code Quality
- `flutter analyze` - Run static analysis (uses analysis_options.yaml)
- `dart format .` - Format all Dart code
- `flutter pub deps` - Show dependency tree
- `flutter pub outdated` - Check for outdated dependencies

### Dependencies
- `flutter pub get` - Install dependencies
- `flutter pub upgrade` - Upgrade dependencies

## Project Structure

```
lib/
  main.dart           # Entry point and main app widget
test/
  widget_test.dart    # Widget tests
android/              # Android-specific configuration
```

## Code Architecture

Currently a basic Flutter app with:
- `MyApp` - Root MaterialApp widget with purple theme
- `MyHomePage` - Stateful widget with counter functionality
- Standard Flutter Material Design patterns

## Development Notes

- Uses Material Design with `ColorScheme.fromSeed(seedColor: Colors.deepPurple)`
- Lint rules configured via `flutter_lints` package
- Widget tests use standard Flutter testing patterns with `WidgetTester`
- Package publication disabled (`publish_to: 'none'`)