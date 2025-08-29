import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '/models/chapter.dart';
import 'dart:io' show Platform;
import '../services/progress_service.dart';
import '../services/api_service.dart';
import 'dart:async';

enum ImageLoadingState { waiting, loading, loaded, error }

class _LoadedChapter {
  final int chapterIndex;
  final Chapter chapter;
  final List<String> images;
  final Map<String, ImageLoadingState> imageLoadingStates;
  final Map<String, double> imageHeights; 
  final bool isFullyLoaded;
  final double chapterHeight;

  _LoadedChapter({
    required this.chapterIndex,
    required this.chapter,
    required this.images,
    required this.imageLoadingStates,
    this.imageHeights = const {},
    this.isFullyLoaded = false,
    this.chapterHeight = 0.0,
  });

  _LoadedChapter copyWith({
    Map<String, ImageLoadingState>? imageLoadingStates,
    Map<String, double>? imageHeights,
    bool? isFullyLoaded,
    double? chapterHeight,
  }) {
    return _LoadedChapter(
      chapterIndex: chapterIndex,
      chapter: chapter,
      images: images,
      imageLoadingStates: imageLoadingStates ?? this.imageLoadingStates,
      imageHeights: imageHeights ?? this.imageHeights,
      isFullyLoaded: isFullyLoaded ?? this.isFullyLoaded,
      chapterHeight: chapterHeight ?? this.chapterHeight,
    );
  }
}

class ReaderScreen extends StatefulWidget {
  final Chapter chapter;
  final List<Chapter> allChapters;
  final int initialPageIndex;       
  final double initialScrollPosition; 
  final String manhwaId;
  
  const ReaderScreen({
    Key? key,
    required this.chapter,
    required this.allChapters,
    required this.manhwaId,
    this.initialPageIndex = 0,        
    this.initialScrollPosition = 0.0, 
  }) : super(key: key);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with TickerProviderStateMixin {
  late int startingChapterIndex;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _appBarAnimationController;
  bool _isAppBarVisible = true;
  bool _showScrollToTop = false;
  bool _isFullscreen = false;
  
  double _scrollProgress = 0.0;
  double _brightness = 1.0;
  double _imageScale = 1.0;
  bool _vibrationFeedback = true;
  
  List<_LoadedChapter> _loadedChapters = [];
  bool _isLoadingNext = false;
  bool _isLoadingPrevious = false;
  int _currentVisibleChapterIndex = 0;
  final Map<String, ImageProvider> _preloadedImages = {};
  bool _hasInitializedImages = false;
  
  int _currentPageIndex = 0;
  String? _manhwaId;
  Timer? _progressSaveTimer;
  bool _hasScrolledToInitialPosition = false;
  bool _isResumingToInitialPosition = false;
  final Map<int, bool> _completedChapters = {};
  
  final Map<int, GlobalKey> _chapterDividerKeys = {};
  final Map<int, double> _chapterStartOffsets = {};

  @override
  void initState() {
    super.initState();
    _initializeReader();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitializedImages) {
      _hasInitializedImages = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadFullChapter(_loadedChapters.first);
          if (!_hasScrolledToInitialPosition) _scrollToInitialPosition();
        }
      });
    }
  }

  Future<void> _syncOnExit() async {
    await _saveCurrentProgress();
    ProgressService.syncNow();
  }

  @override
  void dispose() {
    _progressSaveTimer?.cancel();
    _saveCurrentProgress();
    _syncOnExit();
    _scrollController.dispose();
    _appBarAnimationController.dispose();
    _preloadedImages.clear();
    super.dispose();
  }

  void _initializeReader() {
    print('=== INIT STATE START ===');
    
    _appBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();
    
    startingChapterIndex = widget.allChapters.indexWhere((c) => c.number == widget.chapter.number);
    if (startingChapterIndex == -1) startingChapterIndex = 0;
    
    _loadedChapters.add(_LoadedChapter(
      chapterIndex: startingChapterIndex,
      chapter: widget.allChapters[startingChapterIndex],
      images: widget.allChapters[startingChapterIndex].images,
      imageLoadingStates: {},
    ));
    
    _currentVisibleChapterIndex = startingChapterIndex;
    _scrollController.addListener(_scrollListener);
    _currentPageIndex = widget.initialPageIndex;
    
    for (int i = 0; i < widget.allChapters.length; i++) {
      _chapterDividerKeys[i] = GlobalKey();
    }
    
    _manhwaId = widget.manhwaId;
    _loadProgress();
    print('=== INIT STATE END ===');
  }

  void _scrollToInitialPosition() {
    print('=== SCROLL TO POSITION ===');
    print('Initial page index: ${widget.initialPageIndex}');
    print('Initial scroll position: ${widget.initialScrollPosition}');

    if (widget.initialPageIndex > 0 || widget.initialScrollPosition > 0) {
      _isResumingToInitialPosition = true;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final currentChapterData = _loadedChapters.firstWhere(
          (c) => c.chapterIndex == startingChapterIndex,
          orElse: () => _loadedChapters.first,
        );

        if (!currentChapterData.isFullyLoaded || currentChapterData.imageHeights.length < currentChapterData.images.length) {
          print('Waiting for chapter ${currentChapterData.chapter.number} to load all image heights...');
          await Future.doWhile(() async {
            await Future.delayed(const Duration(milliseconds: 200));
            final updatedChapter = _loadedChapters.firstWhere(
              (c) => c.chapterIndex == startingChapterIndex,
              orElse: () => _loadedChapters.first,
            );
            print('Checking chapter ${updatedChapter.chapter.number}: isFullyLoaded=${updatedChapter.isFullyLoaded}, imageHeights=${updatedChapter.imageHeights.length}/${updatedChapter.images.length}');
            return !updatedChapter.isFullyLoaded || updatedChapter.imageHeights.length < updatedChapter.images.length;
          });
        }

        if (!mounted || !_scrollController.hasClients) {
          print('Aborting scroll: widget not mounted or no scroll controller');
          return;
        }

        final updatedChapterData = _loadedChapters.firstWhere(
          (c) => c.chapterIndex == startingChapterIndex,
          orElse: () => _loadedChapters.first,
        );

        print('Image heights for chapter ${updatedChapterData.chapter.number}: ${updatedChapterData.imageHeights}');
        print('Total chapter height: ${updatedChapterData.chapterHeight}');

        _calculateChapterOffsets();
        final chapterStartOffset = _chapterStartOffsets[startingChapterIndex] ?? 0;
        double targetOffset = 0;

        if (widget.initialScrollPosition > 0) {
          targetOffset = widget.initialScrollPosition;
          if (targetOffset > updatedChapterData.chapterHeight) {
            print('Warning: initialScrollPosition ($targetOffset) exceeds chapter height (${updatedChapterData.chapterHeight}), adjusting to max');
            targetOffset = updatedChapterData.chapterHeight;
          }
          print('Using saved scroll position: $targetOffset');
        } else if (widget.initialPageIndex > 0) {
          final images = updatedChapterData.images;
          final targetPage = widget.initialPageIndex.clamp(0, images.length - 1);
          double cumulativeHeight = 0;
          for (int i = 0; i < targetPage; i++) {
            final imageUrl = images[i];
            final imageHeight = updatedChapterData.imageHeights[imageUrl] ?? 800.0;
            if (imageHeight == 800.0) {
              print('Warning: Using default height 800.0 for image $imageUrl');
            }
            cumulativeHeight += imageHeight;
            print('Page ${i + 1} height: $imageHeight, Cumulative: $cumulativeHeight');
          }
          targetOffset = chapterStartOffset + cumulativeHeight;
          print('Calculated offset from page index $targetPage: $targetOffset');
        }

        final maxScrollExtent = _scrollController.position.maxScrollExtent;
        final finalOffset = targetOffset.clamp(0.0, maxScrollExtent);
        print('Final scroll position: $finalOffset (max: $maxScrollExtent)');

        _scrollController.animateTo(
          finalOffset,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        ).then((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _isResumingToInitialPosition = false;
              print('Resume position complete - completion tracking enabled');
            }
          });
        });

        if (targetOffset > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Resumed from page ${widget.initialPageIndex + 1}'),
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFF6c5ce7),
            ),
          );
        }

        _hasScrolledToInitialPosition = true;
      });
    }
    print('========================');
  }

  Future<void> _loadProgress() async {
    if (_manhwaId == null) return;
    
    final completedChapters = await ProgressService.getCompletedChapters(_manhwaId!);
    setState(() {
      for (double chapterNum in completedChapters) {
        final chapterIndex = widget.allChapters.indexWhere((c) => c.number == chapterNum);
        if (chapterIndex != -1) {
          _completedChapters[chapterIndex] = true;
        }
      }
    });
  }

  Future<void> _saveCurrentProgress() async {
    if (_manhwaId == null) {
      print('Skipping progress save: manhwaId is null');
      return;
    }

    if (!mounted || !_scrollController.hasClients) {
      print('Skipping progress save: widget not mounted or no scroll controller');
      return;
    }

    final currentChapter = widget.allChapters[_currentVisibleChapterIndex];
    final offset = _scrollController.offset;

    if (offset <= 0) {
      print('Warning: Attempted to save progress with offset=0.0 for manhwaId=$_manhwaId, chapter=${currentChapter.number}, page=$_currentPageIndex');
      return;
    }

    print('Saving progress: manhwaId=$_manhwaId, chapter=${currentChapter.number}, page=$_currentPageIndex, offset=$offset');

    await ProgressService.saveProgress(
      _manhwaId!,
      currentChapter.number,
      _currentPageIndex,
      offset,
    );
  }

  Future<void> _markChapterComplete(double chapterNumber) async {
    if (_manhwaId == null) return;
    
    await ProgressService.markCompleted(_manhwaId!, chapterNumber);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Chapter $chapterNumber completed!'),
              const Spacer(),
              if (ApiService.isLoggedIn) ...[
                const Icon(Icons.cloud_upload, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                const Text('Syncing...', style: TextStyle(fontSize: 12)),
              ],
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _scheduleProgressSave() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer(const Duration(seconds: 2), () async {
      if (_scrollController.hasClients && mounted) {
        final offset = _scrollController.offset;
        final maxExtent = _scrollController.position.maxScrollExtent;
        if (offset > 0 && maxExtent > 0) {
          print('Scheduling progress save: page=$_currentPageIndex, offset=$offset, maxExtent=$maxExtent');
          await _saveCurrentProgress();
        } else {
          print('Skipping progress save: invalid offset ($offset) or maxExtent ($maxExtent)');
        }
      } else {
        print('Skipping progress save: no scroll controller or widget not mounted');
      }
    });
  }

  void _scrollListener() {
    final offset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;

    double newScrollProgress;
    if (maxExtent > 0) {
      newScrollProgress = (offset / maxExtent).clamp(0.0, 1.0);
      _showScrollToTop = offset > 1000;
    } else {
      newScrollProgress = 0.0;
      _showScrollToTop = false;
    }

    if ((_scrollProgress - newScrollProgress).abs() > 0.001) {
      setState(() {
        _scrollProgress = newScrollProgress;
      });
    }

    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse && _isAppBarVisible) {
      _isAppBarVisible = false;
      _appBarAnimationController.reverse();
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward && !_isAppBarVisible) {
      _isAppBarVisible = true;
      _appBarAnimationController.forward();
    }

    if (!_isLoadingNext && !_isLoadingPrevious) {
      _updateCurrentVisibleChapter();
    }

    if (offset >= maxExtent - 2000 && _shouldLoadNextChapter()) {
      _loadNextChapter();
    }

    _updateCurrentPage(offset);

    final actualVisiblePage = _getVisiblePageIndex();
    if (actualVisiblePage != _currentPageIndex) {
      setState(() => _currentPageIndex = actualVisiblePage);
      if (offset > 0) {
        print('Triggering progress save from scroll: page=$actualVisiblePage, offset=$offset');
        _scheduleProgressSave();
      }
    }
  }

  int _getVisiblePageIndex() {
    if (!_scrollController.hasClients) return _currentPageIndex;

    final currentChapterData = _loadedChapters.firstWhere(
      (c) => c.chapterIndex == _currentVisibleChapterIndex,
      orElse: () => _loadedChapters.first,
    );

    final chapterStartOffset = _chapterStartOffsets[_currentVisibleChapterIndex] ?? 0;
    final viewportCenter = _scrollController.offset + (_scrollController.position.viewportDimension / 2);
    final offsetInChapter = viewportCenter - chapterStartOffset;

    double cumulativeHeight = 0;
    for (int i = 0; i < currentChapterData.images.length; i++) {
      final imageHeight = currentChapterData.imageHeights[currentChapterData.images[i]] ?? 800.0;
      if (offsetInChapter >= cumulativeHeight && offsetInChapter < cumulativeHeight + imageHeight) {
        return i;
      }
      cumulativeHeight += imageHeight;
    }

    if (offsetInChapter >= cumulativeHeight) {
      return currentChapterData.images.length - 1;
    }

    return _currentPageIndex;
  }

  Widget _buildEnhancedProgressBar() {
    final currentChapter = widget.allChapters[_currentVisibleChapterIndex];
    final currentChapterData = _loadedChapters.firstWhere(
      (c) => c.chapterIndex == _currentVisibleChapterIndex,
      orElse: () => _loadedChapters.first,
    );
    
    final totalPagesInChapter = currentChapterData.images.length;
    final currentPageInChapter = (_currentPageIndex + 1).clamp(1, totalPagesInChapter);
    
    final chapterProgress = totalPagesInChapter > 0 
        ? (currentPageInChapter / totalPagesInChapter).clamp(0.0, 1.0)
        : 0.0;
    
    return AnimatedBuilder(
      animation: _appBarAnimationController,
      builder: (context, _) => Transform.translate(
        offset: Offset(0, -60 * (1 - _appBarAnimationController.value)),
        child: Positioned(
          top: kToolbarHeight + MediaQuery.of(context).padding.top,
          left: 0,
          right: 0,
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              children: [
                Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: chapterProgress,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6c5ce7)),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Page $currentPageInChapter of $totalPagesInChapter',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                  color: Colors.black87,
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6c5ce7).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${(chapterProgress * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleProgressBar() {
    return AnimatedBuilder(
      animation: _appBarAnimationController,
      builder: (context, _) => Transform.translate(
        offset: Offset(0, -60 * (1 - _appBarAnimationController.value)),
        child: Positioned(
          top: kToolbarHeight + MediaQuery.of(context).padding.top,
          left: 0,
          right: 0,
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _scrollProgress,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6c5ce7)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateCurrentPage(double offset) {
    int currentChapter = startingChapterIndex;
    double currentChapterStartOffset = 0;

    if (_loadedChapters.length > 1 || _chapterStartOffsets.isEmpty) {
      _calculateChapterOffsets();
    }

    final sortedOffsets = _chapterStartOffsets.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    for (int i = 0; i < sortedOffsets.length; i++) {
      final entry = sortedOffsets[i];
      final nextEntry = i < sortedOffsets.length - 1 ? sortedOffsets[i + 1] : null;

      if (offset >= entry.value && (nextEntry == null || offset < nextEntry.value)) {
        currentChapter = entry.key;
        currentChapterStartOffset = entry.value;
        break;
      }
    }

    final currentChapterData = _loadedChapters.firstWhere(
      (c) => c.chapterIndex == currentChapter,
      orElse: () => _loadedChapters.first,
    );

    if (currentChapterData.images.isNotEmpty) {
      final viewportHeight = _scrollController.position.viewportDimension;
      final viewportCenter = offset + (viewportHeight / 2);
      final offsetInChapter = viewportCenter - currentChapterStartOffset;

      double cumulativeHeight = 0;
      int rawPageIndex = 0;
      for (int i = 0; i < currentChapterData.images.length; i++) {
        final imageHeight = currentChapterData.imageHeights[currentChapterData.images[i]] ?? 800.0;
        if (offsetInChapter >= cumulativeHeight && offsetInChapter < cumulativeHeight + imageHeight) {
          rawPageIndex = i;
          break;
        }
        cumulativeHeight += imageHeight;
      }

      final clampedPageIndex = rawPageIndex.clamp(0, currentChapterData.images.length - 1);

      if (clampedPageIndex != _currentPageIndex || currentChapter != _currentVisibleChapterIndex) {
        setState(() {
          _currentPageIndex = clampedPageIndex;
          if (currentChapter != _currentVisibleChapterIndex) {
            _currentVisibleChapterIndex = currentChapter;
          }
        });
        _scheduleProgressSave();
        _checkChapterCompletion(offset, currentChapter, currentChapterStartOffset);
      }
    }
  }

  void _updateCurrentVisibleChapter() {
    final viewportHeight = _scrollController.position.viewportDimension;
    final viewportCenter = _scrollController.offset + (viewportHeight / 2);

    for (final chapter in _loadedChapters) {
      final startOffset = _chapterStartOffsets[chapter.chapterIndex] ?? 0;
      final chapterHeight = chapter.isFullyLoaded ? chapter.chapterHeight : (chapter.images.length * 800.0 + 100.0);

      if (viewportCenter >= startOffset && viewportCenter < startOffset + chapterHeight) {
        if (_currentVisibleChapterIndex != chapter.chapterIndex) {
          setState(() => _currentVisibleChapterIndex = chapter.chapterIndex);
          if (_vibrationFeedback) HapticFeedback.selectionClick();
        }
        return;
      }
    }
  }

  void _checkChapterCompletion(double currentOffset, int chapterIndex, double chapterStartOffset) {
    if (_isResumingToInitialPosition) {
      return;
    }
    
    final chapter = _loadedChapters.firstWhere(
      (c) => c.chapterIndex == chapterIndex,
      orElse: () => _loadedChapters.first,
    );
    
    if (!chapter.isFullyLoaded || _completedChapters[chapterIndex] == true) {
      return;
    }
    
    final offsetInChapter = currentOffset - chapterStartOffset;
    final totalChapterHeight = chapter.chapterHeight > 0 ? chapter.chapterHeight : (chapter.images.length * 800.0 + 100.0);
    
    final chapterProgress = totalChapterHeight > 0 ? (offsetInChapter / totalChapterHeight).clamp(0.0, 1.0) : 0.0;
    final imageProgress = chapter.images.length > 0 ? (_currentPageIndex / (chapter.images.length - 1)).clamp(0.0, 1.0) : 0.0;
    
    if (chapterProgress >= 0.95 && imageProgress >= 0.90) {
      _completedChapters[chapterIndex] = true;
      _markChapterComplete(chapter.chapter.number);
      print('Chapter ${chapter.chapter.number} completed');
    }
  }

  void _calculateChapterOffsets() {
    double cumulativeOffset = 0;
    _chapterStartOffsets.clear();
    for (final chapter in _loadedChapters) {
      _chapterStartOffsets[chapter.chapterIndex] = cumulativeOffset;
      cumulativeOffset += chapter.chapterHeight;
      print('Chapter ${chapter.chapter.number} start offset: ${_chapterStartOffsets[chapter.chapterIndex]}, height: ${chapter.chapterHeight}');
    }
  }

  void _loadFullChapter(_LoadedChapter chapter) async {
    print('Starting full load of ${chapter.images.length} images for chapter ${chapter.chapter.number}');

    final imageLoadingStates = {for (var url in chapter.images) url: ImageLoadingState.loading};
    final imageHeights = Map<String, double>.from(chapter.imageHeights);
    _updateChapterImageStates(chapter.chapterIndex, imageLoadingStates);

    final futures = chapter.images.asMap().entries.map((entry) async {
      final index = entry.key;
      final url = entry.value;

      try {
        final imageProvider = NetworkImage(url, headers: _imageHeaders());
        final imageStream = imageProvider.resolve(ImageConfiguration(
          size: Size(MediaQuery.of(context).size.width, 0),
        ));

        Completer<Size> completer = Completer();
        ImageStreamListener? listener;
        listener = ImageStreamListener(
          (ImageInfo info, bool synchronousCall) {
            final size = Size(info.image.width.toDouble(), info.image.height.toDouble());
            completer.complete(size);
            imageStream.removeListener(listener!);
          },
          onError: (exception, stackTrace) {
            completer.completeError(exception, stackTrace);
            imageStream.removeListener(listener!);
          },
        );
        imageStream.addListener(listener);

        final size = await completer.future.timeout(const Duration(seconds: 30));
        final aspectRatio = size.width / size.height;
        final constrainedWidth = MediaQuery.of(context).size.width * 0.7;
        final scaledHeight = constrainedWidth / aspectRatio;

        await precacheImage(imageProvider, context).timeout(const Duration(seconds: 30));
        _preloadedImages[url] = imageProvider;
        _updateImageLoadingState(url, ImageLoadingState.loaded);
        imageHeights[url] = scaledHeight;

        print('Image ${index + 1} loaded: URL=$url, height=$scaledHeight');

        final chapterIndex = _loadedChapters.indexWhere((c) => c.chapterIndex == chapter.chapterIndex);
        if (chapterIndex != -1 && mounted) {
          final totalHeight = imageHeights.values.fold(0.0, (sum, height) => sum + height) + 100.0;
          setState(() {
            _loadedChapters[chapterIndex] = _loadedChapters[chapterIndex].copyWith(
              imageHeights: Map.from(imageHeights),
              chapterHeight: totalHeight,
            );
          });
          print('Updated chapter ${chapter.chapter.number}: imageHeights=${imageHeights.length}/${chapter.images.length}, chapterHeight=$totalHeight');
          _calculateChapterOffsets();
        }
        return true;
      } catch (e) {
        print('Failed to load image ${index + 1} ($url): $e');
        _updateImageLoadingState(url, ImageLoadingState.error);
        imageHeights[url] = 800.0;
        final chapterIndex = _loadedChapters.indexWhere((c) => c.chapterIndex == chapter.chapterIndex);
        if (chapterIndex != -1 && mounted) {
          final totalHeight = imageHeights.values.fold(0.0, (sum, height) => sum + height) + 100.0;
          setState(() {
            _loadedChapters[chapterIndex] = _loadedChapters[chapterIndex].copyWith(
              imageHeights: Map.from(imageHeights),
              chapterHeight: totalHeight,
            );
          });
          print('Updated chapter ${chapter.chapter.number} (error case): imageHeights=${imageHeights.length}/${chapter.images.length}, chapterHeight=$totalHeight');
          _calculateChapterOffsets();
        }
        return false;
      }
    });

    final results = await Future.wait(futures);
    final successCount = results.where((success) => success).length;

    print('Chapter ${chapter.chapter.number}: FULLY LOADED $successCount/${chapter.images.length} images');

    final chapterIndex = _loadedChapters.indexWhere((c) => c.chapterIndex == chapter.chapterIndex);
    if (chapterIndex != -1 && mounted) {
      final totalHeight = imageHeights.values.fold(0.0, (sum, height) => sum + height) + 100.0;
      setState(() {
        _loadedChapters[chapterIndex] = _loadedChapters[chapterIndex].copyWith(
          isFullyLoaded: imageHeights.length == chapter.images.length && successCount == chapter.images.length,
          imageHeights: Map.from(imageHeights),
          chapterHeight: totalHeight,
        );
      });
      print('Final update for chapter ${chapter.chapter.number}: imageHeights=${imageHeights.length}/${chapter.images.length}, chapterHeight=$totalHeight, isFullyLoaded=${imageHeights.length == chapter.images.length && successCount == chapter.images.length}');
      _calculateChapterOffsets();
    }

    if (successCount > chapter.images.length * 0.8) {
      _preloadNextChapterPartially();
    }
  }

  void _preloadNextChapterPartially() async {
    if (_currentVisibleChapterIndex < widget.allChapters.length - 1 && !_isLoadingNext) {
      final nextIndex = _currentVisibleChapterIndex + 1;
      
      final nextChapterExists = _loadedChapters.any((c) => c.chapterIndex == nextIndex);
      
      if (!nextChapterExists) {
        print('Preloading first 10 images of next chapter ${nextIndex + 1}');
        
        final nextChapter = _LoadedChapter(
          chapterIndex: nextIndex,
          chapter: widget.allChapters[nextIndex],
          images: widget.allChapters[nextIndex].images,
          imageLoadingStates: {},
        );
        
        setState(() {
          _loadedChapters.add(nextChapter);
        });
        
        final imagesToPreload = nextChapter.images.take(10).toList();
        final imageLoadingStates = {for (var url in imagesToPreload) url: ImageLoadingState.loading};
        _updateChapterImageStates(nextIndex, imageLoadingStates);
        
        final futures = imagesToPreload.asMap().entries.map((entry) async {
          final url = entry.value;
          try {
            final imageProvider = NetworkImage(url, headers: _imageHeaders());
            await precacheImage(imageProvider, context).timeout(const Duration(seconds: 15));
            _preloadedImages[url] = imageProvider;
            _updateImageLoadingState(url, ImageLoadingState.loaded);
            return true;
          } catch (e) {
            _updateImageLoadingState(url, ImageLoadingState.error);
            return false;
          }
        });
        
        await Future.wait(futures);
        print('Preloaded first 10 images of chapter ${nextChapter.chapter.number}');
      }
    }
  }

  bool _shouldLoadNextChapter() {
    if (_isLoadingNext || _isLoadingPrevious) return false;
    final nextIndex = _loadedChapters.last.chapterIndex + 1;
    return nextIndex < widget.allChapters.length;
  }

  void _loadNextChapter() async {
    if (!_shouldLoadNextChapter()) return;
    setState(() => _isLoadingNext = true);
    
    final nextIndex = _loadedChapters.last.chapterIndex + 1;
    final newChapter = _LoadedChapter(
      chapterIndex: nextIndex,
      chapter: widget.allChapters[nextIndex],
      images: widget.allChapters[nextIndex].images,
      imageLoadingStates: {},
    );
    
    setState(() {
      _loadedChapters.add(newChapter);
      _isLoadingNext = false;
    });
    
    _loadFullChapter(newChapter);
  }

  void _loadPreviousChapter() async {
    if (_isLoadingPrevious || _isLoadingNext || _loadedChapters.first.chapterIndex <= 0) return;
    setState(() => _isLoadingPrevious = true);
    
    final prevIndex = _loadedChapters.first.chapterIndex - 1;
    final prevChapter = _LoadedChapter(
      chapterIndex: prevIndex,
      chapter: widget.allChapters[prevIndex],
      images: widget.allChapters[prevIndex].images,
      imageLoadingStates: {},
    );
    
    final prevHeight = prevChapter.images.length * 800.0 + 100.0;
    
    setState(() {
      _loadedChapters.insert(0, prevChapter);
      _isLoadingPrevious = false;
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollController.jumpTo(_scrollController.offset + prevHeight);
    });
    
    _loadFullChapter(prevChapter);
  }

  void _preloadAdjacentChapters() async {
    if (_currentVisibleChapterIndex < widget.allChapters.length - 1 && !_isLoadingNext) {
      final currentChapter = _loadedChapters.firstWhere(
        (c) => c.chapterIndex == _currentVisibleChapterIndex,
        orElse: () => _loadedChapters.first,
      );
      
      if (currentChapter.isFullyLoaded) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) _loadNextChapter();
      }
    }
  }

  Map<String, String> _imageHeaders() => {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'image/webp,image/apng,image/jpeg,image/png,image/*,*/*;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Cache-Control': 'public, max-age=3600',
      };

  void _updateImageLoadingState(String url, ImageLoadingState state) {
    if (!mounted) return;
    for (var i = 0; i < _loadedChapters.length; i++) {
      if (_loadedChapters[i].images.contains(url)) {
        final newStates = Map<String, ImageLoadingState>.from(_loadedChapters[i].imageLoadingStates)..[url] = state;
        setState(() => _loadedChapters[i] = _loadedChapters[i].copyWith(imageLoadingStates: newStates));
        break;
      }
    }
  }

  void _updateChapterImageStates(int chapterIndex, Map<String, ImageLoadingState> states) {
    final index = _loadedChapters.indexWhere((c) => c.chapterIndex == chapterIndex);
    if (index != -1) {
      setState(() => _loadedChapters[index] = _loadedChapters[index].copyWith(imageLoadingStates: states));
    }
  }

  void _handleTap(TapUpDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;
    if (tapX < screenWidth * 0.3) {
      setState(() {
        _isAppBarVisible = !_isAppBarVisible;
        _appBarAnimationController.animateTo(_isAppBarVisible ? 1.0 : 0.0);
      });
    } else if (tapX > screenWidth * 0.7) {
      final viewportHeight = _scrollController.position.viewportDimension;
      _scrollController.animateTo(
        _scrollController.offset + viewportHeight * 0.8,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      if (_vibrationFeedback) HapticFeedback.lightImpact();
    } else {
      _showReaderSettings();
    }
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    SystemChrome.setEnabledSystemUIMode(_isFullscreen ? SystemUiMode.immersive : SystemUiMode.edgeToEdge);
    if (_vibrationFeedback) HapticFeedback.mediumImpact();
  }

  void _scrollToTop() {
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
  }

  void _jumpToChapter(int index) {
    Navigator.pop(context);
    
    _calculateChapterOffsets();
    final targetOffset = _chapterStartOffsets[index] ?? 0;
    
    if (_loadedChapters.any((ch) => ch.chapterIndex == index)) {
      setState(() => _currentVisibleChapterIndex = index);
      _scrollController.animateTo(
        targetOffset, 
        duration: const Duration(milliseconds: 800), 
        curve: Curves.easeInOut,
      );
    } else {
      _preloadedImages.clear();
      final newChapter = _LoadedChapter(
        chapterIndex: index,
        chapter: widget.allChapters[index],
        images: widget.allChapters[index].images,
        imageLoadingStates: {},
      );
      
      setState(() {
        _loadedChapters = [newChapter];
        _currentVisibleChapterIndex = index;
      });
      
      _scrollController.jumpTo(0);
      _loadFullChapter(newChapter);
    }
  }

  Widget _buildSyncIndicator() {
    if (!ApiService.isLoggedIn) return const SizedBox.shrink();
    
    return FutureBuilder<bool>(
      future: ApiService.checkConnection(),
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;
        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOnline ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOnline ? Colors.green : Colors.orange,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: isOnline ? Colors.green : Colors.orange,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                isOnline ? 'Synced' : 'Offline',
                style: TextStyle(
                  color: isOnline ? Colors.green : Colors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReaderSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2a2a2a),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune, color: Color(0xFF6c5ce7)),
                  const SizedBox(width: 8),
                  const Text('Reader Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),
              _buildSettingSlider(
                icon: Icons.brightness_6,
                title: 'Brightness',
                value: _brightness,
                onChanged: (value) => setState(() => setModalState(() => _brightness = value)),
              ),
              const SizedBox(height: 20),
              _buildSettingSlider(
                icon: Icons.zoom_in,
                title: 'Zoom',
                value: _imageScale,
                min: 0.5,
                max: 2.0,
                onChanged: (value) => setState(() => setModalState(() => _imageScale = value)),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.vibration, color: Color(0xFF6c5ce7)),
                title: const Text('Haptic Feedback', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Vibrate on interactions', style: TextStyle(color: Colors.grey)),
                trailing: Switch(
                  value: _vibrationFeedback,
                  onChanged: (value) {
                    setState(() => setModalState(() => _vibrationFeedback = value));
                    if (value) HapticFeedback.mediumImpact();
                  },
                  activeThumbColor: const Color(0xFF6c5ce7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingSlider({
    required IconData icon,
    required String title,
    required double value,
    double min = 0.3,
    double max = 1.0,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const Spacer(),
            Text('${(value * 100).round()}%', style: const TextStyle(color: Color(0xFF6c5ce7), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF6c5ce7),
            inactiveTrackColor: Colors.grey[700],
            thumbColor: const Color(0xFF6c5ce7),
            overlayColor: const Color(0xFF6c5ce7).withOpacity(0.2),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentChapter = widget.allChapters[_currentVisibleChapterIndex];
    return WillPopScope(
      onWillPop: () async {
        await _syncOnExit();
        return true;
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: AnimatedBuilder(
            animation: _appBarAnimationController,
            builder: (context, _) => Transform.translate(
              offset: Offset(0, -60 * (1 - _appBarAnimationController.value)),
              child: AppBar(
                title: GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => _ChapterSelectorSheet(
                      chapters: widget.allChapters,
                      currentIndex: _currentVisibleChapterIndex,
                      onChapterSelected: _jumpToChapter,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Ch. ${currentChapter.number}: ${currentChapter.title}',
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, size: 20),
                    ],
                  ),
                ),
                centerTitle: true,
                backgroundColor: Colors.black.withOpacity(0.8),
                elevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                actions: [
                  _buildSyncIndicator(),
                  IconButton(icon: const Icon(Icons.tune), onPressed: _showReaderSettings),
                  IconButton(
                    icon: const Icon(Icons.bookmark_border),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bookmarked!'))),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Container(
          color: Platform.isWindows ? const Color(0xFF2a1a3a) : Colors.black.withOpacity(1.0 - _brightness),
          child: Stack(
            children: [
              GestureDetector(
                onTapUp: _handleTap,
                child: Transform.scale(
                  scale: _imageScale,
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _loadedChapters.fold(0, (sum, ch) => sum! + ch.images.length + 1),
                      itemBuilder: _buildItem,
                    ),
                  ),
                ),
              ),
              _buildEnhancedProgressBar(),
              Positioned(
                bottom: 30,
                left: 16,
                child: AnimatedBuilder(
                  animation: _appBarAnimationController,
                  builder: (context, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Move buttons to bottom left by aligning to start
                      Align(
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        if (_currentVisibleChapterIndex > 0 &&
                          !_loadedChapters.any((ch) => ch.chapterIndex == _currentVisibleChapterIndex - 1))
                          Transform.translate(
                          offset: Offset(0, 70 * (1 - _appBarAnimationController.value)),
                          child: FloatingActionButton(
                            mini: true,
                            heroTag: "load_previous",
                            onPressed: _isLoadingPrevious
                              ? null
                              : () {
                                _loadPreviousChapter();
                                ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Loading Chapter $_currentVisibleChapterIndex...'), duration: const Duration(seconds: 1)),
                                );
                              },
                            backgroundColor: _isLoadingPrevious ? Colors.grey : const Color(0xFF6c5ce7).withOpacity(0.9),
                            child: _isLoadingPrevious
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                              : const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                          ),
                          ),
                        if (_showScrollToTop) const SizedBox(height: 8),
                        if (_showScrollToTop)
                          Transform.translate(
                          offset: Offset(0, 70 * (1 - _appBarAnimationController.value)),
                          child: FloatingActionButton(
                            mini: true,
                            heroTag: "scroll_top",
                            onPressed: _scrollToTop,
                            backgroundColor: Colors.black.withOpacity(0.7),
                            child: const Icon(Icons.vertical_align_top, color: Colors.white),
                          ),
                          ),
                        if (_showScrollToTop) const SizedBox(height: 8),
                        Transform.translate(
                          offset: Offset(0, 70 * (1 - _appBarAnimationController.value)),
                          child: FloatingActionButton(
                          mini: true,
                          heroTag: "fullscreen",
                          onPressed: _toggleFullscreen,
                          backgroundColor: _isFullscreen ? const Color(0xFF6c5ce7) : Colors.black.withOpacity(0.7),
                          child: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                          ),
                        ),
                        ],
                      ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    int currentIndex = 0;
    for (final chapter in _loadedChapters) {
      if (index >= currentIndex && index < currentIndex + chapter.images.length) {
        final imageIndex = index - currentIndex;
        final url = chapter.images[imageIndex];
        final state = chapter.imageLoadingStates[url] ?? ImageLoadingState.waiting;
        return Hero(
          tag: 'image_${chapter.chapterIndex}_$imageIndex',
          child: _buildImage(url, state, imageIndex),
        );
      }
      currentIndex += chapter.images.length;
      if (index == currentIndex) {
        currentIndex++;
        return _buildChapterDivider(chapter);
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildImage(String url, ImageLoadingState state, int imageIndex) {
    Widget buildImageContent({required bool disableMouseZoom}) {
      if (_preloadedImages.containsKey(url) && state == ImageLoadingState.loaded) {
        Widget imageWidget = Image(
          image: _preloadedImages[url]!,
          fit: BoxFit.fitWidth,
          width: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget('Display error', imageIndex),
        );

        Widget interactiveViewer = InteractiveViewer(
          panEnabled: false,
          scaleEnabled: true,
          minScale: 0.5,
          maxScale: 3.0,
          child: imageWidget,
        );

        return disableMouseZoom
            ? NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is UserScrollNotification && Platform.isWindows) {
                    final delta = notification.metrics.pixels - _scrollController.offset;
                    _scrollController.jumpTo(_scrollController.offset + delta);
                    return true;
                  }
                  return false;
                },
                child: interactiveViewer,
              )
            : interactiveViewer;
      }
      switch (state) {
        case ImageLoadingState.waiting:
        case ImageLoadingState.loading:
          return Container(
            height: 600,
            color: Colors.grey[900],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Color(0xFF6c5ce7), strokeWidth: 4)),
                const SizedBox(height: 16),
                Text('Loading Page ${imageIndex + 1}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF6c5ce7).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Loading in Background', style: TextStyle(color: Color(0xFF6c5ce7), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        case ImageLoadingState.loaded:
          Widget imageWidget = Image.network(
            url,
            fit: BoxFit.fitWidth,
            width: double.infinity,
            gaplessPlayback: true,
            headers: _imageHeaders(),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 600,
                color: Colors.grey[900],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null,
                          color: const Color(0xFF6c5ce7),
                          strokeWidth: 4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Page ${imageIndex + 1}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => _buildErrorWidget('Network error', imageIndex),
          );

          Widget interactiveViewer = InteractiveViewer(
            panEnabled: false,
            scaleEnabled: true,
            minScale: 0.5,
            maxScale: 3.0,
            child: imageWidget,
          );

          return disableMouseZoom
              ? NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is UserScrollNotification && Platform.isWindows) {
                      final delta = notification.metrics.pixels - _scrollController.offset;
                      _scrollController.jumpTo(_scrollController.offset + delta);
                      return true;
                    }
                    return false;
                  },
                  child: interactiveViewer,
                )
              : interactiveViewer;
        case ImageLoadingState.error:
          return _buildErrorWidget('Loading failed', imageIndex);
      }
    }

    if (Platform.isWindows || Platform.isLinux) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxImageWidth = constraints.maxWidth * 0.7 > 800 ? 800 : constraints.maxWidth * 0.7;
          return Row(
            children: [
              Expanded(
                child: Container(
                  color: const Color(0xFF2a1a3a),
                ),
              ),
              SizedBox(
                width: maxImageWidth.toDouble(),
                child: buildImageContent(disableMouseZoom: true),
              ),
              Expanded(
                child: Container(
                  color: const Color(0xFF2a1a3a),
                ),
              ),
            ],
          );
        },
      );
    } else {
      return buildImageContent(disableMouseZoom: false);
    }
  }

  Widget _buildErrorWidget(String error, int imageIndex) {
    return Container(
      height: 800,
      color: Colors.grey[850],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.3))),
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Failed to load image', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Page ${imageIndex + 1}', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                const SizedBox(height: 8),
                Text(error, style: TextStyle(color: Colors.grey[500], fontSize: 12), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6c5ce7), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _scrollController.animateTo(_scrollController.offset + 800, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
                      icon: const Icon(Icons.skip_next, size: 16),
                      label: const Text('Skip'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[400], side: BorderSide(color: Colors.grey[600]!), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterDivider(_LoadedChapter chapter) {
    final isLastChapter = chapter.chapterIndex >= widget.allChapters.length - 1;
    final loadedImages = chapter.imageLoadingStates.values.where((state) => state == ImageLoadingState.loaded).length;
    final progress = chapter.images.isEmpty ? 0.0 : loadedImages / chapter.images.length;
    final isCompleted = _completedChapters[chapter.chapterIndex] ?? false;
    
    return Container(
      key: _chapterDividerKeys[chapter.chapterIndex],
      margin: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCompleted 
                    ? [Colors.green.withOpacity(0.3), Colors.green.withOpacity(0.1)]
                    : isLastChapter 
                        ? [Colors.orange.withOpacity(0.2), Colors.orange.withOpacity(0.1)]
                        : [const Color(0xFF6c5ce7).withOpacity(0.2), const Color(0xFF6c5ce7).withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCompleted 
                    ? Colors.green.withOpacity(0.5)
                    : isLastChapter 
                        ? Colors.orange.withOpacity(0.3)
                        : const Color(0xFF6c5ce7).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCompleted 
                            ? Colors.green
                            : isLastChapter 
                                ? Colors.orange
                                : const Color(0xFF6c5ce7), 
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCompleted 
                            ? Icons.check_circle
                            : isLastChapter 
                                ? Icons.flag
                                : Icons.bookmark, 
                        color: Colors.white, 
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCompleted 
                                ? 'Chapter ${chapter.chapter.number} Complete!'
                                : isLastChapter 
                                    ? 'Story Complete!' 
                                    : 'Chapter ${chapter.chapter.number}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isLastChapter ? 'Thank you for reading!' : chapter.chapter.title,
                            style: TextStyle(fontSize: 14, color: Colors.grey[300]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Images Loaded', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        Text('$loadedImages/${chapter.images.length}', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isCompleted 
                              ? Colors.green
                              : isLastChapter 
                                  ? Colors.orange
                                  : const Color(0xFF6c5ce7),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
                if (chapter.isFullyLoaded) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_done, color: Colors.green, size: 14),
                        SizedBox(width: 6),
                        Text('Fully Loaded', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
                if (!isLastChapter && !isCompleted) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.swipe_down, color: Colors.grey, size: 16),
                        const SizedBox(width: 8),
                        Text('Continue to Next Chapter', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isLastChapter) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.home),
                  label: const Text('Back to Library'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6c5ce7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for reading!'))),
                  icon: const Icon(Icons.star),
                  label: const Text('Rate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[400],
                    side: BorderSide(color: Colors.grey[600]!),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChapterSelectorSheet extends StatelessWidget {
  final List<Chapter> chapters;
  final int currentIndex;
  final Function(int) onChapterSelected;

  const _ChapterSelectorSheet({required this.chapters, required this.currentIndex, required this.onChapterSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(color: Color(0xFF1a1a1a), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFF2a2a2a), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(
              children: [
                const Icon(Icons.list, color: Color(0xFF6c5ce7)),
                const SizedBox(width: 12),
                const Text('Chapter Selection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF6c5ce7).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text('${chapters.length} chapters', style: const TextStyle(color: Color(0xFF6c5ce7), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                final isSelected = index == currentIndex;
                final isCompleted = index < currentIndex;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6c5ce7).withOpacity(0.1) : const Color(0xFF2a2a2a),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? const Color(0xFF6c5ce7) : Colors.transparent),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.green : isSelected ? const Color(0xFF6c5ce7) : Colors.grey[700],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : Text('${chapter.number}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    title: Text(
                      'Chapter ${chapter.number}: ${chapter.title}',
                      style: TextStyle(color: isSelected ? const Color(0xFF6c5ce7) : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${chapter.releaseDate.day}/${chapter.releaseDate.month}/${chapter.releaseDate.year}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    trailing: isSelected ? const Icon(Icons.play_circle_filled, color: Color(0xFF6c5ce7)) : const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => onChapterSelected(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}