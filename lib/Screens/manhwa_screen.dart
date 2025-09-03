import 'package:flutter/material.dart';
import '../services/manhwa_service.dart';
import '../models/manwha.dart';
import '../models/chapter.dart';
import '../screens/reader_screen.dart';
import '../services/progress_service.dart';

class ManhwaScreen extends StatefulWidget {
  final dynamic manhwaId;
  final String name;
  final String genre;

  const ManhwaScreen({
    Key? key,
    required this.manhwaId,
    required this.name,
    required this.genre,
  }) : super(key: key);

  @override
  State<ManhwaScreen> createState() => _ManhwaScreenState();
}

class _ManhwaScreenState extends State<ManhwaScreen> {
  bool _isFavorite = false;
  bool _isDescriptionExpanded = false;
  Manhwa? manhwa;
  bool _isLoading = true;
  String _sortType = 'Latest First';
  
  // Progress tracking
  Set<double> _completedChapters = {};
  double? _continueChapter;

  @override
  void initState() {
    super.initState();
    _loadManhwaData();
  }

  Future<void> _loadManhwaData() async {
    setState(() => _isLoading = true);
    
    try {
      // Use ManhwaService instead of legacy data
      manhwa = await ManhwaService.getManhwaById(widget.manhwaId.toString());
      
      if (manhwa != null) {
        await _loadProgress();
      }
    } catch (e) {
      print('Error loading manhwa data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load manhwa: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadProgress() async {
    if (manhwa == null) return;
    
    final manhwaIdStr = manhwa!.id.toString();
    _completedChapters = await ProgressService.getCompletedChapters(manhwaIdStr);
    _continueChapter = await ProgressService.getContinueChapter(
      manhwaIdStr, 
      manhwa!.chapters.map((c) => c.number).toList()
    );
  }

  String _getManhwaDescription() => manhwa?.description ?? 'No description available.';
  double _getManhwaRating() => manhwa?.rating ?? 4.5;
  String _getManhwaStatus() => manhwa?.status ?? 'Unknown';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1a1a1a),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6c5ce7)),
        ),
      );
    }

    if (manhwa == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1a1a1a),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2a2a2a),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.name,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                'Manhwa not found',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Could not load "${widget.name}"',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadManhwaData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6c5ce7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: RefreshIndicator(
        onRefresh: _loadManhwaData,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildManhwaInfo(),
                  _buildActionButtons(),
                  _buildStatsRow(),
                  _buildChapterHeader(),
                ],
              ),
            ),
            SliverToBoxAdapter(child: _buildChapterList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: const Color(0xFF2a2a2a),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.red : Colors.white,
          ),
          onPressed: () {
            setState(() => _isFavorite = !_isFavorite);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isFavorite ? 'Added to favorites' : 'Removed from favorites'),
                backgroundColor: const Color(0xFF2a2a2a),
              ),
            );
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: const Color(0xFF2a2a2a),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'reset_progress',
              child: Row(
                children: [
                  Icon(Icons.refresh, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text('Reset Progress', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: manhwa?.coverImageUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    manhwa!.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF6c5ce7),
                            const Color(0xFF6c5ce7).withOpacity(0.8),
                            const Color(0xFF2a2a2a),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.menu_book, size: 100, color: Colors.white),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF6c5ce7),
                      const Color(0xFF6c5ce7).withOpacity(0.8),
                      const Color(0xFF2a2a2a),
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.menu_book, size: 100, color: Colors.white),
                ),
              ),
      ),
    );
  }

  Widget _buildManhwaInfo() {
    final description = _getManhwaDescription();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.genre.split(', ').map((genre) {
              return Chip(
                label: Text(
                  genre.trim(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: const Color(0xFF6c5ce7).withOpacity(0.3),
                side: const BorderSide(color: Color(0xFF6c5ce7)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip(Icons.book, '${manhwa?.chapters.length ?? 0} Chapters'),
              const SizedBox(width: 12),
              _buildInfoChip(Icons.star, _getManhwaRating().toString()),
              const SizedBox(width: 12),
              _buildInfoChip(Icons.check_circle, _getManhwaStatus()),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                    height: 1.5,
                  ),
                  maxLines: _isDescriptionExpanded ? null : 3,
                  overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _isDescriptionExpanded ? 'Show less' : 'Show more',
                      style: const TextStyle(
                        color: Color(0xFF6c5ce7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      _isDescriptionExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF6c5ce7),
                      size: 18,
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

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF6c5ce7), size: 16),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (manhwa == null || manhwa!.chapters.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2a2a2a),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[400], size: 48),
              const SizedBox(height: 12),
              Text(
                'No chapters available for ${widget.name}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (_continueChapter != null) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToReader(_continueChapter!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6c5ce7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: Text(
                  'Continue Chapter $_continueChapter',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _navigateToReader(manhwa!.chapters.first.number),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6c5ce7)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.restart_alt, color: Color(0xFF6c5ce7)),
                  label: const Text(
                    'Start from Beginning',
                    style: TextStyle(color: Color(0xFF6c5ce7), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _navigateToReader(manhwa!.chapters.last.number),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[600]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(Icons.skip_next, color: Colors.grey[400]),
                  label: Text(
                    'Latest Chapter',
                    style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    if (manhwa == null) return const SizedBox.shrink();
    
    final readingProgress = manhwa!.chapters.isNotEmpty ? (_completedChapters.length / manhwa!.chapters.length) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Completed', '${_completedChapters.length}/${manhwa!.chapters.length}', Icons.check_circle),
              _buildStatItem('Remaining', '${manhwa!.chapters.length - _completedChapters.length}', Icons.schedule),
              _buildStatItem('Progress', '${(readingProgress * 100).round()}%', Icons.trending_up),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: readingProgress,
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6c5ce7)),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF6c5ce7), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildChapterHeader() {
    if (manhwa == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Chapters (${manhwa!.chapters.length})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2a2a2a),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF6c5ce7).withOpacity(0.3)),
                ),
                child: Text(
                  _sortType,
                  style: const TextStyle(
                    color: Color(0xFF6c5ce7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.sort, color: Color(0xFF6c5ce7)),
                onPressed: _showSortOptions,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChapterList() {
    if (manhwa == null || manhwa!.chapters.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.book_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No chapters available yet',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: manhwa!.chapters.length,
      itemBuilder: (context, index) {
        final chapter = manhwa!.chapters[index];
        return _buildChapterTile(chapter, index);
      },
    );
  }

  Widget _buildChapterTile(Chapter chapter, int index) {
    final isNew = DateTime.now().difference(chapter.releaseDate).inDays < 7;
    final isCompleted = _completedChapters.contains(chapter.number);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted 
              ? const Color(0xFF6c5ce7).withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        onTap: () => _navigateToReader(chapter.number),
        onLongPress: () => _showChapterOptions(chapter, isCompleted),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted 
                ? const Color(0xFF6c5ce7) 
                : const Color(0xFF3a3a3a),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${chapter.number}',
              style: TextStyle(
                color: isCompleted ? Colors.white : Colors.grey[400],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Chapter ${chapter.number}: ${chapter.title}',
                style: TextStyle(
                  color: isCompleted ? Colors.white : Colors.grey[300],
                  fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            if (isNew)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              '${chapter.releaseDate.day}/${chapter.releaseDate.month}/${chapter.releaseDate.year}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
            if (isCompleted) ...[
              const SizedBox(width: 8),
              Text(
                '• Read',
                style: TextStyle(
                  color: const Color(0xFF6c5ce7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick toggle button
            GestureDetector(
              onTap: () => _toggleChapterReadStatus(chapter, isCompleted),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isCompleted ? const Color(0xFF6c5ce7) : Colors.grey[400],
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showChapterOptions(Chapter chapter, bool isCompleted) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2a2a2a),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chapter ${chapter.number}: ${chapter.title}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.play_arrow, color: Color(0xFF6c5ce7)),
                title: const Text('Read Chapter', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToReader(chapter.number);
                },
              ),
              ListTile(
                leading: Icon(
                  isCompleted ? Icons.remove_circle : Icons.check_circle,
                  color: isCompleted ? Colors.orange : Colors.green,
                ),
                title: Text(
                  isCompleted ? 'Mark as Unread' : 'Mark as Read',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleChapterReadStatus(chapter, isCompleted);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleChapterReadStatus(Chapter chapter, bool isCurrentlyCompleted) async {
    if (manhwa == null) return;
    
    try {
      if (isCurrentlyCompleted) {
        // Unmark as completed and sync immediately
        await ProgressService.unmarkCompleted(
          manhwa!.id.toString(),
          chapter.number,
          syncImmediately: true, // Trigger immediate API sync
        );
        setState(() {
          _completedChapters.remove(chapter.number);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chapter ${chapter.number} marked as unread'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Mark as completed and sync immediately
        await ProgressService.markCompleted(
          manhwa!.id.toString(),
          chapter.number,
          syncImmediately: true, // Trigger immediate API sync
        );
        setState(() {
          _completedChapters.add(chapter.number);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chapter ${chapter.number} marked as read'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Update continue chapter after status change
      _continueChapter = await ProgressService.getContinueChapter(
        manhwa!.id.toString(), 
        manhwa!.chapters.map((c) => c.number).toList()
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update chapter status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _navigateToReader(double chapterNumber) async {
    if (manhwa == null) return;
    
    final selectedChapter = manhwa!.chapters.firstWhere(
      (c) => c.number == chapterNumber,
      orElse: () => manhwa!.chapters.first,
    );

    // Get saved progress for this chapter
    final progress = await ProgressService.getProgress(manhwa!.id.toString(), chapterNumber);
    print('=== RESUME DEBUG ===');
    print('Manhwa ID: ${manhwa!.id}');
    print('Chapter number: $chapterNumber');
    print('Progress data: $progress');
    print('Passing pageIndex: ${progress?['pageIndex'] ?? 0}');
    print('==================');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          chapter: selectedChapter,
          allChapters: manhwa!.chapters,
          manhwaId: manhwa!.id.toString(), // Use the manhwa ID directly
          initialPageIndex: progress?['pageIndex'] ?? 0,
          initialScrollPosition: progress?['scrollPosition'] ?? 0.0,
        ),
      ),
    );

    // Refresh progress when returning
    if (result == true) {
      await _loadProgress();
      setState(() {});
    }
  }

  Future<void> _handleMenuAction(String action) async {
    if (action == 'reset_progress') {
      final confirmed = await _showConfirmDialog(
        'Reset Progress',
        'This will reset all reading progress for ${widget.name}. Continue?',
      );
      
      if (confirmed && manhwa != null) {
        await ProgressService.clearProgress(manhwa!.id.toString());
        await _loadProgress();
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress reset successfully')),
        );
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2a2a2a),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort Chapters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildSortOption('Latest First', Icons.arrow_downward, _sortType == 'Latest First'),
              _buildSortOption('Oldest First', Icons.arrow_upward, _sortType == 'Oldest First'),
              _buildSortOption('Unread First', Icons.visibility_off, _sortType == 'Unread First'),
              _buildSortOption('Completed First', Icons.check_circle, _sortType == 'Completed First'),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String title, IconData icon, bool isSelected) {
    return ListTile(
      leading: Icon(
        icon, 
        color: isSelected ? const Color(0xFF6c5ce7) : Colors.grey[400],
      ),
      title: Text(
        title, 
        style: TextStyle(
          color: isSelected ? const Color(0xFF6c5ce7) : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF6c5ce7)) : null,
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _sortType = title;
          // Note: Sorting would need to be implemented if desired
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sorted by $title'),
            backgroundColor: const Color(0xFF2a2a2a),
          ),
        );
      },
    );
  }
}