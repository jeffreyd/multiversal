# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multiversal is a Flutter-based comic book reader application for Android that supports both CBZ (ZIP) and CBR (RAR) comic book formats. The app provides a native, high-performance reading experience with features like thumbnail caching, folder browsing, and immersive full-screen viewing.

## Key Features

### Comic Book Support
- **CBZ files**: ZIP-based comic books with optimized streaming and caching
- **CBR files**: RAR-based comic books with intelligent preloading (2-3 pages ahead)
- **Thumbnail generation**: Automatic thumbnails with persistent caching
- **Format detection**: Supports jpg, jpeg, png, gif, bmp, webp image formats

### Reading Experience
- **Full-screen viewer**: Immersive reading with tap zones and gesture controls
- **Navigation**: Tap left/right sides, swipe gestures, or progress slider
- **Zoom and pan**: Pinch-to-zoom (0.5x to 4x) with pan support
- **Page information**: Shows filename and page position (e.g., "page001.jpg (5 of 23)")
- **Smart controls**: Tap center to show/hide control bars with smooth animations

### Performance Optimizations
- **Parallel file operations**: Directory listing uses parallel stat() calls (40-60% faster)
- **Isolate thumbnail processing**: Large images (>5MB) processed in background threads
- **CBR preloading**: Intelligent caching of current + next 2 + previous 1 pages
- **Memory management**: Efficient cache trimming and resource disposal
- **Natural sorting**: Proper numeric ordering of comic pages

### Storage & Permissions
- **All Files Access**: Automatic permission requests for external storage
- **Scoped storage**: Handles Android storage restrictions gracefully
- **Persistent settings**: Remembers selected directories between sessions
- **Cache management**: SHA256-based thumbnail cache with size monitoring

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
- `python tools/cbr_to_cbz.py <input>` - Convert CBR files to CBZ format
  - Supports single files, directories, and recursive conversion
  - Use `--recursive` for subdirectories
  - Use `--delete-original` to remove CBR files after conversion

## Project Structure

```
lib/
  main.dart                 # App entry point with folder selection
  comic_viewer.dart         # Full-screen comic book reader
  comic_book.dart          # Comic book archive handling (CBZ/CBR)
  file_browser.dart        # Directory and file browsing UI
  file_system_service.dart # Optimized file system operations
  thumbnail_cache.dart     # Persistent thumbnail caching
  thumbnail_preloader.dart # Background thumbnail generation
  cbr_preloader.dart      # CBR-specific preloading system
  rar_extractor.dart      # System unrar integration
  rar_extractor_plugin.dart # unrar_file plugin wrapper
  permission_service.dart  # Android storage permissions
  settings_dialog.dart     # Settings popup with bulk operations
  debug_helper.dart        # Development and debugging tools
test/
  comic_book_test.dart     # Unit tests for comic book functionality
  widget_test.dart         # Widget tests
android/                   # Android-specific configuration
packages/
  unrar_file/             # Vendored RAR extraction library (namespace fixed)
tools/
  cbr_to_cbz.py          # Python script for format conversion
```

## Dependencies

### Core Dependencies
- `file_picker: ^8.0.0+1` - Directory selection
- `shared_preferences: ^2.2.2` - Persistent settings storage
- `path_provider: ^2.1.1` - App directory access
- `archive: ^3.6.1` - ZIP archive handling
- `image: ^4.2.0` - Image processing and thumbnail generation
- `path: ^1.9.1` - File path utilities
- `permission_handler: ^11.3.1` - Android permissions
- `crypto: ^3.0.3` - SHA256 hashing for cache keys
- `unrar_file: (vendored)` - RAR extraction (locally modified)

### Development Dependencies
- `flutter_lints: ^5.0.0` - Dart/Flutter linting rules
- `flutter_test: sdk: flutter` - Testing framework

## Code Architecture

### Core Classes

#### `ComicBook`
- Handles both CBZ and CBR archive formats
- Implements lazy loading with optimized caching
- Supports isolate-based thumbnail generation for large images
- Provides preloading interface for CBR files

#### `FileBrowser`
- Directory navigation with thumbnail previews
- Integrates with thumbnail preloader for smooth browsing
- Handles Android storage limitations with user guidance
- Real-time thumbnail generation progress tracking

#### `ComicViewer`
- Full-screen reading experience with gesture controls
- Tap zones: left (previous), center (controls), right (next)
- Pinch-to-zoom with transformation controller
- Progress slider with page information display

#### `FileSystemService`
- Optimized directory listing with parallel operations
- Smart file type detection and filtering
- Lightweight comic file discovery for bulk operations

#### `ThumbnailCache`
- SHA256-based cache keys with file modification time
- Automatic cache size management and cleanup
- PNG format thumbnails (200x300px with aspect ratio)

### Performance Features

#### CBR Preloading
- Preloads current + next 2 + previous 1 pages
- Batch extraction for consecutive pages
- Memory-efficient cache with automatic trimming
- Fallback to system unrar if plugin fails

#### Thumbnail Generation
- Background processing for large images (>5MB)
- Isolate-based processing to prevent UI blocking
- Graceful fallback to main thread if isolates fail
- Persistent caching to avoid regeneration

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
- Isolate-based processing for CPU-intensive operations
- Memory-efficient caching with automatic cleanup
- Parallel file operations where possible
- Smart preloading to minimize user wait times

### Error Handling
- Graceful degradation for unsupported files
- Clear user feedback for permission and access issues
- Comprehensive error recovery throughout the application
- Debug tools for troubleshooting storage issues

## Common Development Tasks

### Adding New Image Formats
1. Update the supported extensions set in `ComicBook._getImageFiles()`
2. Ensure the format is supported by the `image` package
3. Test with sample files of the new format

### Modifying Cache Behavior
1. Adjust cache size limits in `ThumbnailCache._trimCache()`
2. Modify cache cleanup intervals in `ThumbnailCache.cleanOldCache()`
3. Update cache key generation in `ThumbnailCache._getCacheKey()`

### Optimizing Performance
1. Profile with Flutter DevTools to identify bottlenecks
2. Consider isolate processing for new CPU-intensive operations
3. Implement batching for repetitive async operations
4. Monitor memory usage and implement cleanup where needed