# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multiversal is a Flutter-based comic book reader application for Android that supports CBZ (ZIP) comic book format. The app provides a native, high-performance reading experience with features like folder browsing and immersive full-screen viewing.

## Key Features

### Comic Book Support
- **CBZ files**: ZIP-based comic books with optimized streaming and caching
- **Format detection**: Supports jpg, jpeg, png, gif, bmp, webp image formats

### Reading Experience
- **Full-screen viewer**: Immersive reading with tap zones and gesture controls
- **Navigation**: Tap left/right sides, swipe gestures, or progress slider
- **Zoom and pan**: Pinch-to-zoom (0.5x to 4x) with pan support
- **Wide image support**: Two-page spreads display in scrollable view for tablet reading
- **Smart layout detection**: Automatically detects wide images (aspect ratio > 1.4)
- **Page information**: Shows filename and page position (e.g., "page001.jpg (5 of 23)")
- **Smart controls**: Tap center to show/hide control bars with smooth animations
- **Read status tracking**: Automatically marks comics as read when reaching the last page
- **Read badges**: Visual indicators show which comics have been completed

### Performance Optimizations
- **Parallel file operations**: Directory listing uses parallel stat() calls (40-60% faster)
- **Streaming CBZ loading**: Large archives use streaming decoders for better memory efficiency
- **Memory management**: Efficient resource disposal
- **Natural sorting**: Proper numeric ordering of comic pages

### Storage & Permissions
- **All Files Access**: Automatic permission requests for external storage
- **Scoped storage**: Handles Android storage restrictions gracefully
- **Persistent settings**: Remembers selected directories between sessions
- **Read status tracking**: SHA256-based file identification for tracking completion

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

### Tools
- `python tools/cbr_to_cbz.py <input>` - Convert CBR files to CBZ or CB7 format
  - Supports single files, directories, and recursive conversion
  - Use `--format cbz` or `--format cb7` to specify output format
  - Use `--recursive` for subdirectories
  - Use `--delete-original` to remove CBR files after conversion

## Project Structure

```
lib/
  main.dart                 # App entry point with folder selection
  comic_viewer.dart         # Full-screen comic book reader
  comic_book.dart          # Comic book archive handling (CBZ only)
  file_browser.dart        # Directory and file browsing UI
  file_system_service.dart # Optimized file system operations
  read_status_service.dart # Comic book read status tracking
  permission_service.dart  # Android storage permissions
  settings_dialog.dart     # Settings popup with bulk operations
  debug_helper.dart        # Development and debugging tools
test/
  comic_book_test.dart     # Unit tests for comic book functionality
  widget_test.dart         # Widget tests
android/                   # Android-specific configuration
tools/
  cbr_to_cbz.py          # Python script for CBR to CBZ/CB7 conversion
```

## Dependencies

### Core Dependencies
- `file_picker: ^8.0.0+1` - Directory selection
- `shared_preferences: ^2.2.2` - Persistent settings storage
- `path_provider: ^2.1.1` - App directory access
- `archive: ^3.6.1` - ZIP archive handling for CBZ files
- `path: ^1.9.1` - File path utilities
- `permission_handler: ^11.3.1` - Android permissions
- `crypto: ^3.0.3` - SHA256 hashing for cache keys

### Development Dependencies
- `flutter_lints: ^5.0.0` - Dart/Flutter linting rules
- `flutter_test: sdk: flutter` - Testing framework

## Code Architecture

### Core Classes

#### `ComicBook`
- Handles CBZ (ZIP) archive format with optimized streaming
- Implements lazy loading with efficient memory management
- Provides intelligent preloading for smooth page navigation

#### `FileBrowser`
- Directory navigation with read status indicators
- Handles Android storage limitations with user guidance
- Clean, fast file listing without thumbnails

#### `ComicViewer`
- Full-screen reading experience with gesture controls
- Tap zones: left (previous), center (controls), right (next)
- Pinch-to-zoom with transformation controller
- Progress slider with page information display

#### `FileSystemService`
- Optimized directory listing with parallel operations
- Smart file type detection and filtering
- Lightweight comic file discovery for bulk operations


### Performance Features

#### CBZ Optimization
- Streaming archive reading for large files (>100MB)
- Lazy image loading with intelligent preloading
- Memory-efficient caching with automatic cleanup
- Native ZIP handling with minimal overhead

#### File Operations
- Parallel stat() calls for directory listing
- Set-based extension lookup for faster filtering
- Natural sorting for proper page ordering
- Streaming-based operations where possible

## Android Configuration

### Permissions (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
```

### Storage Handling
- Requests "All Files Access" permission on startup
- Handles scoped storage restrictions gracefully
- Provides fallback options for inaccessible directories
- Supports both internal and external storage

## Development Notes

### Code Style
- Uses Material Design 3 with purple theme
- Follows Flutter/Dart best practices and linting rules
- Implements proper error handling and resource disposal
- Uses modern async/await patterns throughout

### Testing
- Unit tests for core comic book functionality
- Widget tests for UI components
- Async testing patterns for file operations

### Performance Considerations
- Memory-efficient resource management
- Parallel file operations where possible
- Smart preloading to minimize user wait times
- Eliminated thumbnail generation for maximum speed

### Error Handling
- Graceful degradation for unsupported files
- Clear user feedback for permission and access issues
- Comprehensive error recovery throughout the application
- Debug tools for troubleshooting storage issues

## Common Development Tasks

### Adding New Image Formats
1. Update the supported extensions set in `ComicBook._getImageFiles()`
2. Test with sample files of the new format

### Optimizing CBZ Performance
1. Profile with Flutter DevTools to identify bottlenecks
2. Adjust streaming threshold in `ComicBook._loadArchive()` for different file sizes
3. Implement additional preloading strategies in `ComicBook.preloadImages()`
4. Monitor memory usage and implement cleanup where needed