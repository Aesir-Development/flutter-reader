// screens/manhwa_screen.dart
import 'package:flutter/material.dart';
import '../Data/manhwa_data.dart';
import '../models/manwha.dart';
import '../models/chapter.dart';
import '../screens/reader_screen.dart';

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
  int _lastReadChapter = 0;
  bool _isLoading = true;
  String _sortType = 'Latest First';

  @override
  void initState() {
    super.initState();
    _loadManhwaData();
  }

// In _ManhwaScreenState
void _loadManhwaData() {
  setState(() => _isLoading = true);
  
  manhwa = getManhwaById(widget.manhwaId);
  
  if (manhwa != null) {
    _loadReadingProgress();
  }
  
  setState(() => _isLoading = false);
}

  void _loadReadingProgress() {
    if (manhwa == null) return;
    
    _lastReadChapter = (manhwa!.chapters.length * 0.3).round();
    
    final updatedChapters = <Chapter>[];
    for (int i = 0; i < manhwa!.chapters.length; i++) {
      final chapter = manhwa!.chapters[i];
      updatedChapters.add(chapter.copyWith(
        isRead: i < _lastReadChapter,
        isDownloaded: i < (_lastReadChapter * 0.7).round(),
      ));
    }
    
    manhwa = manhwa!.copyWith(chapters: updatedChapters);
  }

  String _getManhwaDescription() => manhwa?.description ?? 'No description available.';
  double _getManhwaRating() => manhwa?.rating ?? 4.5;
  String _getManhwaStatus() => manhwa?.status ?? 'Unknown';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1a1a1a),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF6c5ce7)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: CustomScrollView(
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
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Share functionality coming soon!'),
                backgroundColor: Color(0xFF2a2a2a),
              ),
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
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
          if (_lastReadChapter > 0 && _lastReadChapter < manhwa!.chapters.length) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToReader(_lastReadChapter + 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6c5ce7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: Text(
                  'Continue Reading - Chapter ${_lastReadChapter + 1}',
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
                  onPressed: () => _navigateToReader(1),
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
              if (manhwa!.chapters.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToReader(manhwa!.chapters.length),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    if (manhwa == null) return const SizedBox.shrink();
    
    final readChapters = manhwa!.chapters.where((c) => c.isRead).length;
    final downloadedChapters = manhwa!.chapters.where((c) => c.isDownloaded).length;
    final readingProgress = manhwa!.chapters.isNotEmpty ? (readChapters / manhwa!.chapters.length) : 0.0;

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
              _buildStatItem('Read', '$readChapters/${manhwa!.chapters.length}', Icons.check_circle),
              _buildStatItem('Downloaded', '$downloadedChapters', Icons.download_done),
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
                icon: const Icon(Icons.download, color: Color(0xFF6c5ce7)),
                onPressed: _showDownloadOptions,
              ),
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
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: chapter.isRead 
              ? const Color(0xFF6c5ce7).withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        onTap: () => _navigateToReader(chapter.number),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: chapter.isRead 
                ? const Color(0xFF6c5ce7) 
                : const Color(0xFF3a3a3a),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${chapter.number}',
              style: TextStyle(
                color: chapter.isRead ? Colors.white : Colors.grey[400],
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
                  color: chapter.isRead ? Colors.white : Colors.grey[300],
                  fontWeight: chapter.isRead ? FontWeight.w500 : FontWeight.normal,
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
            if (chapter.isDownloaded) ...[
              const SizedBox(width: 8),
              Icon(Icons.offline_pin, color: Colors.green[400], size: 12),
              const SizedBox(width: 2),
              Text(
                'Downloaded',
                style: TextStyle(
                  color: Colors.green[400],
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chapter.isDownloaded)
              Icon(Icons.download_done, color: Colors.green[400], size: 20),
            if (chapter.isRead)
              const Icon(Icons.check_circle, color: Color(0xFF6c5ce7), size: 20),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _navigateToReader(int chapterNumber) {
    if (manhwa == null) return;
    
    final selectedChapter = manhwa!.chapters.firstWhere(
      (c) => c.number == chapterNumber,
      orElse: () => manhwa!.chapters.first,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          chapter: selectedChapter,
          allChapters: manhwa!.chapters,
        ),
      ),
    ).then((_) {
      setState(() {
        if (chapterNumber > _lastReadChapter) {
          _lastReadChapter = chapterNumber;
          final updatedChapters = <Chapter>[];
          for (int i = 0; i < manhwa!.chapters.length; i++) {
            final chapter = manhwa!.chapters[i];
            updatedChapters.add(chapter.copyWith(
              isRead: i < chapterNumber,
            ));
          }
          manhwa = manhwa!.copyWith(chapters: updatedChapters);
        }
      });
      _saveReadingProgress();
    });
  }

  void _saveReadingProgress() {
    print('Saving reading progress: Chapter $_lastReadChapter');
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
              _buildSortOption('Read First', Icons.visibility, _sortType == 'Read First'),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showDownloadOptions() {
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
                'Download Options',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildDownloadOption('Download Next 5 Chapters', Icons.download),
              _buildDownloadOption('Download All Unread', Icons.download_for_offline),
              _buildDownloadOption('Download All Chapters', Icons.cloud_download),
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
          if (manhwa != null) {
            final chapters = List<Chapter>.from(manhwa!.chapters);
            if (title == 'Oldest First') {
              chapters.sort((a, b) => a.number.compareTo(b.number));
            } else if (title == 'Latest First') {
              chapters.sort((a, b) => b.number.compareTo(a.number));
            } else if (title == 'Unread First') {
              chapters.sort((a, b) => a.isRead ? 1 : -1);
            } else if (title == 'Read First') {
              chapters.sort((a, b) => a.isRead ? -1 : 1);
            }
            manhwa = manhwa!.copyWith(chapters: chapters);
          }
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

  Widget _buildDownloadOption(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6c5ce7)),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title - Coming soon!'),
            backgroundColor: const Color(0xFF2a2a2a),
          ),
        );
      },
    );
  }
}