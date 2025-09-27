import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'comic_book.dart';
import 'read_status_service.dart';

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
  double _currentScale = 1.0;
  bool _isZoomed = false;
  ReadStatusService? _readStatusService;

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

    // Listen to transformation changes to track zoom level
    _transformationController.addListener(_onTransformationChanged);

    _initReadStatusService();
    _loadComicBook();

    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  void _onTransformationChanged() {
    final Matrix4 matrix = _transformationController.value;
    final double scale = matrix.getMaxScaleOnAxis();

    if (mounted && scale != _currentScale) {
      setState(() {
        _currentScale = scale;
        _isZoomed = scale > 1.1; // Consider zoomed if > 110%
      });
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
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

        // Start preloading for the first few pages
        _triggerPreload();
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
      _animateToScale(1.0); // Reset zoom when changing pages
      _triggerPreload();
      _checkIfLastPageReached();
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _animateToScale(1.0); // Reset zoom when changing pages
      _triggerPreload();
    }
  }

  void _goToPage(int index) {
    if (index >= 0 && index < _images.length) {
      setState(() {
        _currentIndex = index;
      });
      _animateToScale(1.0); // Reset zoom when changing pages
      _triggerPreload();
      _checkIfLastPageReached();
    }
  }

  void _animateToScale(double scale) {
    final double currentScale = _transformationController.value.getMaxScaleOnAxis();

    if ((scale - currentScale).abs() < 0.1) return; // Already at target scale

    // Create transformation matrix for the new scale
    final Matrix4 targetMatrix = Matrix4.identity();
    targetMatrix.setEntry(0, 0, scale); // Scale X
    targetMatrix.setEntry(1, 1, scale); // Scale Y

    // Animate to the new transformation
    final AnimationController scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    final Animation<Matrix4> scaleAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: scaleController,
      curve: Curves.easeInOut,
    ));

    scaleAnimation.addListener(() {
      _transformationController.value = scaleAnimation.value;
    });

    scaleController.forward().then((_) {
      scaleController.dispose();
    });
  }

  Future<void> _initReadStatusService() async {
    _readStatusService = await ReadStatusService.getInstance();
  }

  void _triggerPreload() {
    // Trigger preloading for next few pages
    _comicBook.preloadImages(_currentIndex, 3);
  }

  void _checkIfLastPageReached() {
    // Mark as read when reaching the last page
    if (_currentIndex == _images.length - 1 && _readStatusService != null) {
      _readStatusService!.markAsRead(widget.filePath);
    }
  }

  Widget _buildImageViewer() {
    if (_images.isEmpty) return const SizedBox.shrink();

    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.5,
      maxScale: 4.0,
      panEnabled: true,
      scaleEnabled: true,
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
                  filterQuality: FilterQuality.high,
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
                  Colors.black.withValues(alpha: 0.8),
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
                  // Zoom level indicator
                  if (_isZoomed) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(_currentScale * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
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
          bottom: -100 + (100 * _controlsAnimation.value),
          left: 0,
          right: 0,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Filename and page info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            '${_images.isNotEmpty ? _images[_currentIndex].name : ''} (${_currentIndex + 1} of ${_images.length})',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        // Zoom indicator in bottom controls
                        if (_isZoomed) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '${(_currentScale * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Controls row
                  Expanded(
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTapZones() {
    // When zoomed, disable tap zones to allow panning
    if (_isZoomed) {
      return const SizedBox.shrink();
    }

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
                // Smart zoom: if not zoomed, zoom to 2x, if zoomed, reset
                if (_isZoomed) {
                  _animateToScale(1.0);
                } else {
                  _animateToScale(2.0);
                }
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