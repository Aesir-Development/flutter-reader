import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '/models/chapter.dart';

class ReaderScreen extends StatefulWidget {
  final Chapter chapter;
  final List<Chapter> allChapters;

  const ReaderScreen({
    Key? key,
    required this.chapter,
    required this.allChapters,
  }) : super(key: key);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with TickerProviderStateMixin {
  late int startingChapterIndex;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _appBarAnimationController;
  
  bool _isAppBarVisible = true;
  bool _showScrollToTop = false;
  double _scrollProgress = 0.0;
  
  // Manage loaded chapters and their content
  List<_LoadedChapter> _loadedChapters = [];
  bool _isLoadingNext = false;
  bool _isLoadingPrevious = false;
  int _currentVisibleChapterIndex = 0;
  
  // Image preloading management
  final Map<String, ImageProvider> _preloadedImages = {};
  final Set<String> _priorityLoadingImages = {};
  
  // Debouncing and timing control
  DateTime? _lastLoadAttempt;
  static const Duration _loadCooldown = Duration(seconds: 10);
  
  bool _hasInitializedImages = false;
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupInitialChapter();
    _addListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Now it's safe to call precacheImage because MediaQuery is available
    if (!_hasInitializedImages) {
      _hasInitializedImages = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Start prioritized preloading for the initial chapter
          final initialChapter = _loadedChapters.first;
          _startPrioritizedImageLoading(initialChapter);
          _preloadAdjacentChapters();
        }
      });
    }
  }

  void _initializeControllers() {
    _appBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _appBarAnimationController.forward();
  }

  void _setupInitialChapter() {
    startingChapterIndex = widget.allChapters.indexWhere(
      (c) => c.number == widget.chapter.number,
    );
    if (startingChapterIndex == -1) startingChapterIndex = 0;
    
    // Load the initial chapter with REAL images from the Chapter object
    final initialChapter = _LoadedChapter(
      chapterIndex: startingChapterIndex,
      chapter: widget.allChapters[startingChapterIndex],
      images: widget.allChapters[startingChapterIndex].images,
      isLoading: false,
      imageLoadingStates: {},
    );
    
    _loadedChapters.add(initialChapter);
    _currentVisibleChapterIndex = startingChapterIndex;
  }

  void _addListeners() {
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    final scrollOffset = _scrollController.offset;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    
    // Update scroll progress across all loaded chapters
    if (maxScrollExtent > 0) {
      setState(() {
        _scrollProgress = (scrollOffset / maxScrollExtent).clamp(0.0, 1.0);
        _showScrollToTop = scrollOffset > 1000;
      });
    }
    
    // Auto-hide/show app bar based on scroll direction
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_isAppBarVisible) {
        setState(() => _isAppBarVisible = false);
        _appBarAnimationController.reverse();
      }
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_isAppBarVisible) {
        setState(() => _isAppBarVisible = true);
        _appBarAnimationController.forward();
      }
    }
    
    // Detect current visible chapter
    _updateCurrentVisibleChapter();
    
    // Load next chapter when approaching end (with debouncing)
    if (scrollOffset >= maxScrollExtent - 1000 && _shouldLoadNextChapter()) {
      _loadNextChapter();
    }
    
    // Only cleanup chapters occasionally, not on every scroll event
    // This prevents aggressive cleanup during fast scrolling
    if (_scrollController.position.userScrollDirection == ScrollDirection.idle) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _scrollController.position.userScrollDirection == ScrollDirection.idle) {
          _cleanupOldChapters();
        }
      });
    }
  }

  void _updateCurrentVisibleChapter() {
    // Find which chapter is currently most visible
    final viewportHeight = _scrollController.position.viewportDimension;
    final scrollOffset = _scrollController.offset;
    final viewportCenter = scrollOffset + (viewportHeight / 2);
    
    double runningOffset = 0;
    for (int i = 0; i < _loadedChapters.length; i++) {
      final loadedChapter = _loadedChapters[i];
      final chapterHeight = _calculateChapterHeight(loadedChapter);
      
      if (viewportCenter >= runningOffset && viewportCenter < runningOffset + chapterHeight) {
        if (_currentVisibleChapterIndex != loadedChapter.chapterIndex) {
          setState(() {
            _currentVisibleChapterIndex = loadedChapter.chapterIndex;
          });
        }
        break;
      }
      runningOffset += chapterHeight;
    }
  }

  double _calculateChapterHeight(_LoadedChapter chapter) {
    // Estimate height: images + divider + padding
    return (chapter.images.length * 800.0) + 100.0; // 800px per image + divider
  }

  bool _shouldLoadNextChapter() {
    // Don't load if already loading
    if (_isLoadingNext || _isLoadingPrevious) return false;
    
    // Don't load if we recently attempted to load
    if (_lastLoadAttempt != null) {
      final timeSinceLastLoad = DateTime.now().difference(_lastLoadAttempt!);
      if (timeSinceLastLoad < _loadCooldown) return false;
    }
    
    // Check if next chapter already exists
    final lastLoadedChapter = _loadedChapters.last;
    final nextChapterIndex = lastLoadedChapter.chapterIndex + 1;
    return nextChapterIndex < widget.allChapters.length;
  }

  void _preloadAdjacentChapters() async {
    // Load previous chapter if available (with delay)
    if (startingChapterIndex > 0) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && !_isLoadingPrevious) {
        _loadPreviousChapter();
      }
    }
    
    // Load next chapter if available (with longer delay)
    if (startingChapterIndex < widget.allChapters.length - 1) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted && !_isLoadingNext) {
        _loadNextChapter();
      }
    }
  }

  // Prioritized image loading - loads first 3 images immediately, then the rest
  void _startPrioritizedImageLoading(_LoadedChapter chapter) async {
    if (chapter.images.isEmpty) return;
    
    print('🚀 Starting prioritized loading for chapter ${chapter.chapterIndex + 1}');
    print('📝 Total images to load: ${chapter.images.length}');
    
    // Initialize loading states
    final imageLoadingStates = <String, ImageLoadingState>{};
    for (final imageUrl in chapter.images) {
      imageLoadingStates[imageUrl] = ImageLoadingState.waiting;
    }
    
    // Update chapter with loading states
    final chapterIndex = _loadedChapters.indexWhere((c) => c.chapterIndex == chapter.chapterIndex);
    if (chapterIndex != -1) {
      setState(() {
        _loadedChapters[chapterIndex] = _loadedChapters[chapterIndex].copyWith(
          imageLoadingStates: imageLoadingStates,
        );
      });
    }
    
    // Priority load first 3 images
    const priorityCount = 3;
    final priorityImages = chapter.images.take(priorityCount).toList();
    final remainingImages = chapter.images.skip(priorityCount).toList();
    
    print('⚡ Starting priority images: ${priorityImages.map((url) => url.split('/').last).toList()}');
    
    // Load priority images ONE BY ONE instead of in parallel to avoid blocking
    for (int i = 0; i < priorityImages.length; i++) {
      final imageUrl = priorityImages[i];
      print('🔄 Loading priority image ${i + 1}/${priorityImages.length}: ${imageUrl.split('/').last}');
      
      try {
        await _preloadSingleImage(imageUrl, isPriority: true);
        print('✅ Priority image ${i + 1} completed: ${imageUrl.split('/').last}');
      } catch (e) {
        print('❌ Priority image ${i + 1} failed: ${imageUrl.split('/').last} - $e');
        // Continue with next image even if this one fails
      }
      
      // Small delay between priority images
      if (i < priorityImages.length - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    print('⚡ All priority images processed, starting remaining images...');
    
    // Small delay before loading remaining images
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Load remaining images in batches of 2
    for (int i = 0; i < remainingImages.length; i += 2) {
      final batch = remainingImages.skip(i).take(2).toList();
      print('🔄 Loading batch ${(i ~/ 2) + 1}: ${batch.map((url) => url.split('/').last).toList()}');
      
      // Load batch images one by one as well for better error handling
      for (final url in batch) {
        try {
          await _preloadSingleImage(url, isPriority: false);
          print('✅ Batch image loaded: ${url.split('/').last}');
        } catch (e) {
          print('❌ Batch image failed: ${url.split('/').last} - $e');
        }
      }
      
      // Small delay between batches to avoid overwhelming
      if (i + 2 < remainingImages.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    print('✅ Finished loading all images for chapter ${chapter.chapterIndex + 1}');
  }

  Future<void> _preloadSingleImage(String imageUrl, {required bool isPriority}) async {
    print('🔍 _preloadSingleImage called for: ${imageUrl.split('/').last}, isPriority: $isPriority');
    
    if (_preloadedImages.containsKey(imageUrl)) {
      print('💾 Image already cached: ${imageUrl.split('/').last}');
      _updateImageLoadingState(imageUrl, ImageLoadingState.loaded);
      return;
    }
    
    try {
      print('🔄 Starting load for: ${imageUrl.split('/').last}');
      _updateImageLoadingState(imageUrl, ImageLoadingState.loading);
      
      if (isPriority) {
        print('⚡ Adding to priority loading set: ${imageUrl.split('/').last}');
        _priorityLoadingImages.add(imageUrl);
        print('📊 Priority loading set size: ${_priorityLoadingImages.length}');
      }
      
      // Create image provider with CORS headers
      print('🌐 Creating image provider for: ${imageUrl.split('/').last}');
      final imageProvider = NetworkImage(
        imageUrl,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );
      
      // Check if context is still mounted before preloading
      if (!mounted) {
        print('❌ Context not mounted, aborting load for: ${imageUrl.split('/').last}');
        return;
      }
      
      print('🔄 Calling precacheImage for: ${imageUrl.split('/').last}');
      
      // ADD TIMEOUT to prevent hanging
      await Future.any([
        precacheImage(imageProvider, context),
        Future.delayed(const Duration(seconds: 30)), // 30 second timeout
      ]);
      
      print('✅ precacheImage completed for: ${imageUrl.split('/').last}');
      
      // Store the provider for immediate use
      _preloadedImages[imageUrl] = imageProvider;
      _updateImageLoadingState(imageUrl, ImageLoadingState.loaded);
      
      if (isPriority) {
        print('⚡ Priority image preloaded successfully: ${imageUrl.split('/').last}');
      } else {
        print('📸 Regular image preloaded successfully: ${imageUrl.split('/').last}');
      }
      
    } catch (e, stackTrace) {
      print('❌ Failed to preload image: ${imageUrl.split('/').last}');
      print('❌ Error: $e');
      _updateImageLoadingState(imageUrl, ImageLoadingState.error);
    } finally {
      if (isPriority) {
        print('🧹 Removing from priority loading set: ${imageUrl.split('/').last}');
        _priorityLoadingImages.remove(imageUrl);
        print('📊 Priority loading set size after removal: ${_priorityLoadingImages.length}');
      }
    }
  }

  void _updateImageLoadingState(String imageUrl, ImageLoadingState state) {
    if (!mounted) {
      print('❌ _updateImageLoadingState: Context not mounted for ${imageUrl.split('/').last}');
      return;
    }
    
    print('🔄 Updating image state to $state for: ${imageUrl.split('/').last}');
    
    bool foundAndUpdated = false;
    for (int i = 0; i < _loadedChapters.length; i++) {
      final chapter = _loadedChapters[i];
      if (chapter.images.contains(imageUrl)) {
        final newStates = Map<String, ImageLoadingState>.from(chapter.imageLoadingStates);
        newStates[imageUrl] = state;
        
        setState(() {
          _loadedChapters[i] = chapter.copyWith(imageLoadingStates: newStates);
        });
        
        print('✅ Updated state for ${imageUrl.split('/').last} in chapter ${chapter.chapterIndex + 1}');
        foundAndUpdated = true;
        break;
      }
    }
    
    if (!foundAndUpdated) {
      print('❌ Could not find image ${imageUrl.split('/').last} in any loaded chapter');
      print('📊 Current loaded chapters: ${_loadedChapters.map((c) => c.chapterIndex + 1).toList()}');
    }
  }

  Future<void> _loadNextChapter() async {
    if (!_shouldLoadNextChapter()) return;
    
    final lastLoadedChapter = _loadedChapters.last;
    final nextChapterIndex = lastLoadedChapter.chapterIndex + 1;
    
    if (nextChapterIndex >= widget.allChapters.length) return;
    
    setState(() {
      _isLoadingNext = true;
      _lastLoadAttempt = DateTime.now();
    });
    
    print('🔄 Started loading chapter ${nextChapterIndex + 1}');
    
    // Add the chapter immediately and start loading images
    final nextChapter = _LoadedChapter(
      chapterIndex: nextChapterIndex,
      chapter: widget.allChapters[nextChapterIndex],
      images: widget.allChapters[nextChapterIndex].images,
      isLoading: false, // Set to false since we're loading images separately
      imageLoadingStates: {},
    );
    
    setState(() {
      _loadedChapters.add(nextChapter);
      _isLoadingNext = false;
    });
    
    // Start prioritized image loading
    _startPrioritizedImageLoading(nextChapter);
    
    print('✅ Added chapter ${nextChapterIndex + 1} to list');
  }

  Future<void> _loadPreviousChapter() async {
    if (_isLoadingPrevious || _isLoadingNext) return;
    
    final firstLoadedChapter = _loadedChapters.first;
    final prevChapterIndex = firstLoadedChapter.chapterIndex - 1;
    
    if (prevChapterIndex < 0) return;
    
    setState(() => _isLoadingPrevious = true);
    
    print('🔄 Started loading previous chapter ${prevChapterIndex + 1}');
    
    final prevChapter = _LoadedChapter(
      chapterIndex: prevChapterIndex,
      chapter: widget.allChapters[prevChapterIndex],
      images: widget.allChapters[prevChapterIndex].images,
      isLoading: false,
      imageLoadingStates: {},
    );
    
    setState(() {
      _loadedChapters.insert(0, prevChapter);
      _isLoadingPrevious = false;
    });
    
    // Start prioritized image loading
    _startPrioritizedImageLoading(prevChapter);
    
    print('✅ Added previous chapter ${prevChapterIndex + 1} to list');
  }

  void _cleanupOldChapters() {
    if (_isLoadingNext || _isLoadingPrevious) return;
    if (_loadedChapters.length <= 2) return; // Keep at least current + next
    
    // Find current chapter in loaded chapters
    int currentLoadedIndex = _loadedChapters.indexWhere(
      (ch) => ch.chapterIndex == _currentVisibleChapterIndex
    );
    
    if (currentLoadedIndex == -1) return;
    
    // Only remove chapters that are BEFORE the current chapter
    // This means if you're reading chapter 2, we can remove chapter 1
    final toRemove = <_LoadedChapter>[];
    
    for (int i = 0; i < currentLoadedIndex; i++) {
      final chapter = _loadedChapters[i];
      // Only remove if it's more than 1 chapter behind current
      if (_currentVisibleChapterIndex - chapter.chapterIndex > 1) {
        toRemove.add(chapter);
      }
    }
    
    // Safety check - never remove current or next chapter
    toRemove.removeWhere((ch) => 
      ch.chapterIndex >= _currentVisibleChapterIndex
    );
    
    if (toRemove.isNotEmpty) {
      print('🗑️ Cleaning up ${toRemove.length} completed chapters');
      for (final chapter in toRemove) {
        print('🗑️ Removing completed chapter ${chapter.chapterIndex + 1} from memory');
      }
      
      // Clean up preloaded images for removed chapters
      for (final chapter in toRemove) {
        for (final imageUrl in chapter.images) {
          _preloadedImages.remove(imageUrl);
        }
      }
      
      setState(() {
        _loadedChapters.removeWhere((ch) => toRemove.contains(ch));
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _showChapterSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChapterSelectorSheet(
        chapters: widget.allChapters,
        currentIndex: _currentVisibleChapterIndex,
        onChapterSelected: _jumpToChapter,
      ),
    );
  }

  void _jumpToChapter(int targetChapterIndex) {
    Navigator.pop(context);
    
    int loadedIndex = _loadedChapters.indexWhere(
      (ch) => ch.chapterIndex == targetChapterIndex
    );
    
    if (loadedIndex != -1) {
      _scrollToLoadedChapter(loadedIndex);
    } else {
      _resetToChapter(targetChapterIndex);
    }
  }

  void _scrollToLoadedChapter(int loadedIndex) {
    double offset = 0;
    for (int i = 0; i < loadedIndex; i++) {
      offset += _calculateChapterHeight(_loadedChapters[i]);
    }
    
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  void _resetToChapter(int chapterIndex) {
    // Clean up existing preloaded images
    _preloadedImages.clear();
    _priorityLoadingImages.clear();
    
    final newChapter = _LoadedChapter(
      chapterIndex: chapterIndex,
      chapter: widget.allChapters[chapterIndex],
      images: widget.allChapters[chapterIndex].images,
      isLoading: false,
      imageLoadingStates: {},
    );
    
    setState(() {
      _loadedChapters.clear();
      _loadedChapters.add(newChapter);
      _currentVisibleChapterIndex = chapterIndex;
    });
    
    _scrollController.jumpTo(0);
    
    // Start prioritized loading for new chapter
    _startPrioritizedImageLoading(newChapter);
    _preloadAdjacentChapters();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _appBarAnimationController.dispose();
    _preloadedImages.clear();
    _priorityLoadingImages.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentChapter = widget.allChapters[_currentVisibleChapterIndex];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(currentChapter),
      body: Stack(
        children: [
          _buildMainContent(),
          _buildScrollToTopButton(),
          _buildProgressIndicator(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Chapter currentChapter) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: AnimatedBuilder(
        animation: _appBarAnimationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -60 * (1 - _appBarAnimationController.value)),
            child: AppBar(
              title: GestureDetector(
                onTap: _showChapterSelector,
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
              backgroundColor: Colors.black.withOpacity(0.7),
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bookmarked!')),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        itemCount: _getTotalItemCount(),
        itemBuilder: (context, index) => _buildItem(index),
      ),
    );
  }

  int _getTotalItemCount() {
    int count = 0;
    for (final chapter in _loadedChapters) {
      count += chapter.images.length; // Images
      count += 1; // Chapter divider
    }
    return count;
  }

  Widget _buildItem(int index) {
    int currentIndex = 0;
    
    for (int chapterIdx = 0; chapterIdx < _loadedChapters.length; chapterIdx++) {
      final chapter = _loadedChapters[chapterIdx];
      
      if (index >= currentIndex && index < currentIndex + chapter.images.length) {
        final imageIndex = index - currentIndex;
        return _buildImageItem(chapter, imageIndex);
      }
      currentIndex += chapter.images.length;
      
      if (index == currentIndex) {
        currentIndex += 1;
        return _buildChapterDivider(chapter);
      }
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildImageItem(_LoadedChapter loadedChapter, int imageIndex) {
    final imageUrl = loadedChapter.images[imageIndex];
    final loadingState = loadedChapter.imageLoadingStates[imageUrl] ?? ImageLoadingState.waiting;
    final isPriority = _priorityLoadingImages.contains(imageUrl);
    
    return Hero(
      tag: 'image_${loadedChapter.chapterIndex}_$imageIndex',
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        child: _buildImageWithState(imageUrl, loadingState, imageIndex, isPriority),
      ),
    );
  }

  Widget _buildImageWithState(String imageUrl, ImageLoadingState loadingState, int imageIndex, bool isPriority) {
    // If image is preloaded and ready, show it immediately regardless of loading state
    if (_preloadedImages.containsKey(imageUrl) && loadingState == ImageLoadingState.loaded) {
      return Image(
        image: _preloadedImages[imageUrl]!,
        fit: BoxFit.fitWidth,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Preloaded image display error: $error');
          print('🔗 Failed URL: $imageUrl');
          return _buildErrorWidget('Preloaded image error: $error', imageIndex);
        },
      );
    }
    
    switch (loadingState) {
      case ImageLoadingState.waiting:
        return Container(
          height: 800,
          color: Colors.grey[900],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                isPriority ? 'Queued (Priority)' : 'Queued',
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              Text(
                'Image ${imageIndex + 1}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        );
      
      case ImageLoadingState.loading:
        return Container(
          height: 800,
          color: Colors.grey[900],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: isPriority ? Colors.green : Colors.blue,
              ),
              const SizedBox(height: 16),
              Text(
                isPriority ? 'Loading (Priority)' : 'Loading',
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              Text(
                'Image ${imageIndex + 1}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        );
      
      case ImageLoadingState.loaded:
        // This should now be handled by the preloaded image check above
        // But fallback to network image if preloading failed
        return Image.network(
          imageUrl,
          fit: BoxFit.fitWidth,
          width: double.infinity,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 800,
              color: Colors.grey[900],
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('❌ Network image display error: $error');
            print('🔗 Failed URL: $imageUrl');
            return _buildErrorWidget('Network error: $error', imageIndex);
          },
        );
      
      case ImageLoadingState.error:
        return _buildErrorWidget('Failed to preload', imageIndex);
    }
  }

  Widget _buildErrorWidget(String error, int imageIndex) {
    return Container(
      height: 800,
      color: Colors.grey[800],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Failed to load image',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Image ${imageIndex + 1}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            'Error: $error',
            style: TextStyle(color: Colors.grey[600], fontSize: 10),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterDivider(_LoadedChapter loadedChapter) {
    final isLastChapter = loadedChapter.chapterIndex >= widget.allChapters.length - 1;
    final loadedImagesCount = loadedChapter.imageLoadingStates.values
        .where((state) => state == ImageLoadingState.loaded)
        .length;
    final totalImages = loadedChapter.images.length;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: Column(
              children: [
                Icon(
                  isLastChapter ? Icons.check_circle : Icons.arrow_downward,
                  color: isLastChapter ? Colors.green : Colors.blue,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  isLastChapter 
                    ? 'End of Story' 
                    : 'End of Chapter ${loadedChapter.chapter.number}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Loaded: $loadedImagesCount/$totalImages images',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
                if (!isLastChapter) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Continue to Chapter ${loadedChapter.chapterIndex + 2}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.swipe_down,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
          if (isLastChapter) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home),
              label: const Text('Back to Library'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      right: 16,
      bottom: _showScrollToTop ? 30 : -60,
      child: FloatingActionButton(
        mini: true,
        onPressed: _scrollToTop,
        backgroundColor: Colors.black.withOpacity(0.7),
        child: const Icon(Icons.keyboard_arrow_up),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Positioned(
      top: kToolbarHeight + MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: LinearProgressIndicator(
        value: _scrollProgress,
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
        minHeight: 2,
      ),
    );
  }
}

enum ImageLoadingState {
  waiting,
  loading,
  loaded,
  error,
}

class _LoadedChapter {
  final int chapterIndex;
  final Chapter chapter;
  final List<String> images;
  final bool isLoading;
  final Map<String, ImageLoadingState> imageLoadingStates;

  _LoadedChapter({
    required this.chapterIndex,
    required this.chapter,
    required this.images,
    required this.isLoading,
    required this.imageLoadingStates,
  });

  _LoadedChapter copyWith({
    int? chapterIndex,
    Chapter? chapter,
    List<String>? images,
    bool? isLoading,
    Map<String, ImageLoadingState>? imageLoadingStates,
  }) {
    return _LoadedChapter(
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapter: chapter ?? this.chapter,
      images: images ?? this.images,
      isLoading: isLoading ?? this.isLoading,
      imageLoadingStates: imageLoadingStates ?? this.imageLoadingStates,
    );
  }
}

class _ChapterSelectorSheet extends StatelessWidget {
  final List<Chapter> chapters;
  final int currentIndex;
  final Function(int) onChapterSelected;

  const _ChapterSelectorSheet({
    required this.chapters,
    required this.currentIndex,
    required this.onChapterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Jump to Chapter',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                final isSelected = index == currentIndex;
                
                return ListTile(
                  title: Text(
                    'Chapter ${chapter.number}: ${chapter.title}',
                    style: TextStyle(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  leading: Icon(
                    isSelected ? Icons.play_circle_filled : Icons.play_circle_outline,
                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                  ),
                  onTap: () => onChapterSelected(index),
                  selected: isSelected,
                  selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}