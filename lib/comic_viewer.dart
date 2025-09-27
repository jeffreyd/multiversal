import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'comic_book.dart';

class ComicViewer extends StatefulWidget {
  final String filePath;

  const ComicViewer({
    super.key,
    required this.filePath,
  });

  @override
  State<ComicViewer> createState() => _ComicViewerState();
}

class _ComicViewerState extends State<ComicViewer>
    with TickerProviderStateMixin {
  late ComicBook _comicBook;
  List<ComicBookImage> _images = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _showControls = false;
  String? _error;

  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;

  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _comicBook = ComicBook(widget.filePath);

    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _controlsAnimation = CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    );

    _loadComicBook();

    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _comicBook.dispose();
    _controlsAnimationController.dispose();
    _transformationController.dispose();

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadComicBook() async {
    try {
      final images = await _comicBook.images;
      if (mounted) {
        setState(() {
          _images = images;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load comic book: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _controlsAnimationController.forward();
    } else {
      _controlsAnimationController.reverse();
    }
  }

  void _nextPage() {
    if (_currentIndex < _images.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _transformationController.value = Matrix4.identity();
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _transformationController.value = Matrix4.identity();
    }
  }

  void _goToPage(int index) {
    if (index >= 0 && index < _images.length) {
      setState(() {
        _currentIndex = index;
      });
      _transformationController.value = Matrix4.identity();
    }
  }

  Widget _buildImageViewer() {
    if (_images.isEmpty) return const SizedBox.shrink();

    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.5,
      maxScale: 4.0,
      child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: FutureBuilder<Uint8List>(
            future: _images[_currentIndex].data,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Image.memory(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.white70,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    );
                  },
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              } else {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white70,
                  ),
                );
              }
            },
          ),
        ),
    );
  }

  Widget _buildTopControls() {
    return AnimatedBuilder(
      animation: _controlsAnimation,
      builder: (context, child) {
        return Positioned(
          top: -60 + (60 * _controlsAnimation.value),
          left: 0,
          right: 0,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      _comicBook.filePath.split('/').last,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${_currentIndex + 1} / ${_images.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return AnimatedBuilder(
      animation: _controlsAnimation,
      builder: (context, child) {
        return Positioned(
          bottom: -80 + (80 * _controlsAnimation.value),
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.skip_previous,
                      color: _currentIndex > 0 ? Colors.white : Colors.white38,
                      size: 32,
                    ),
                    onPressed: _currentIndex > 0 ? _previousPage : null,
                  ),
                  Expanded(
                    child: Slider(
                      value: _currentIndex.toDouble(),
                      min: 0,
                      max: (_images.length - 1).toDouble(),
                      divisions: _images.length > 1 ? _images.length - 1 : 1,
                      activeColor: Colors.white,
                      inactiveColor: Colors.white38,
                      thumbColor: Colors.white,
                      onChanged: (value) {
                        _goToPage(value.round());
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.skip_next,
                      color: _currentIndex < _images.length - 1
                          ? Colors.white
                          : Colors.white38,
                      size: 32,
                    ),
                    onPressed:
                        _currentIndex < _images.length - 1 ? _nextPage : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTapZones() {
    return Positioned.fill(
      child: Row(
        children: [
          // Left tap zone - previous page
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () {
                if (_currentIndex > 0) {
                  _previousPage();
                } else {
                  // At first page, just toggle controls
                  _toggleControls();
                }
              },
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null) {
                  if (details.primaryVelocity! > 100) {
                    // Swipe right - previous page
                    _previousPage();
                  }
                }
              },
              child: Container(
                color: Colors.transparent,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // Center tap zone - toggle controls
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: _toggleControls,
              onDoubleTap: () {
                // Reset zoom on double tap
                _transformationController.value = Matrix4.identity();
              },
              child: Container(
                color: Colors.transparent,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // Right tap zone - next page
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () {
                if (_currentIndex < _images.length - 1) {
                  _nextPage();
                } else {
                  // At last page, just toggle controls
                  _toggleControls();
                }
              },
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null) {
                  if (details.primaryVelocity! < -100) {
                    // Swipe left - next page
                    _nextPage();
                  }
                }
              },
              child: Container(
                color: Colors.transparent,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    _buildImageViewer(),
                    _buildTapZones(),
                    _buildTopControls(),
                    _buildBottomControls(),
                  ],
                ),
    );
  }
}