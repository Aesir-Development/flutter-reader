import 'package:flutter/material.dart';

class Chapter {
  final int number;
  final String title;
  final String releaseDate;
  final bool isRead;
  final bool isDownloaded;

  Chapter({
    required this.number,
    required this.title,
    required this.releaseDate,
    this.isRead = false,
    this.isDownloaded = false,
  });
}

class ManhwaScreen extends StatefulWidget {
  final String id;
  final String name;
  final String genre;
  final int totalChapters;

  const ManhwaScreen({
    Key? key,
    required this.id,
    required this.name,
    required this.genre,
    required this.totalChapters,
  }) : super(key: key);

  @override
  State<ManhwaScreen> createState() => _ManhwaDetailScreenState();
}

class _ManhwaDetailScreenState extends State<ManhwaScreen> {
  bool _isFavorite = false;
  bool _isDescriptionExpanded = false;
  late List<Chapter> chapters;
  int _lastReadChapter = 0;

  // Sample descriptions for different manhwas
  final Map<String, String> descriptions = {
    'Solo Leveling': 'In a world where hunters battle deadly monsters that emerge from magical gates, Sung Jin-Woo is the weakest E-rank hunter. After a dangerous encounter in a hidden dungeon, he gains the unique ability to level up, transforming from the weakest hunter into humanity\'s greatest weapon.',
    'Tower of God': 'Bam enters the mysterious Tower to chase after his dear friend Rachel, but to climb the Tower he will need to fight against all sorts of monsters and people, and each floor will present him with a new, often life-threatening challenge.',
    'The Beginning After The End': 'King Grey has unrivaled strength, wealth, and prestige in a world governed by martial ability. However, solitude lingers closely behind those with great power. Beneath the glamorous exterior of a powerful king lurks the shell of man, devoid of purpose and will.',
  };

  @override
  void initState() {
    super.initState();
    _generateChapters();
    // Simulate having read some chapters
    _lastReadChapter = (widget.totalChapters * 0.3).round();
  }

  void _generateChapters() {
    chapters = List.generate(widget.totalChapters, (index) {
      final chapterNum = index + 1;
      return Chapter(
        number: chapterNum,
        title: _generateChapterTitle(chapterNum),
        releaseDate: _generateReleaseDate(index),
        isRead: chapterNum <= _lastReadChapter,
        isDownloaded: chapterNum <= _lastReadChapter + 5,
      );
    });
  }

  String _generateChapterTitle(int chapterNum) {
    final titles = [
      'The Beginning',
      'Awakening',
      'First Battle',
      'New Powers',
      'The Challenge',
      'Breakthrough',
      'Rising Threat',
      'Confrontation',
      'Victory',
      'New Journey',
      'Hidden Truth',
      'The Test',
      'Revelation',
      'Final Stand',
      'Transformation',
    ];
    
    if (chapterNum <= 15) {
      return titles[chapterNum - 1];
    }
    
    // Generate generic titles for higher chapters
    final patterns = ['The', 'New', 'Hidden', 'Final', 'Last', 'First', 'Great'];
    final nouns = ['Battle', 'Challenge', 'Power', 'Enemy', 'Alliance', 'Secret', 'Truth'];
    
    return '${patterns[chapterNum % patterns.length]} ${nouns[chapterNum % nouns.length]}';
  }

  String _generateReleaseDate(int index) {
    final now = DateTime.now();
    final releaseDate = now.subtract(Duration(days: (widget.totalChapters - index) * 3));
    return '${releaseDate.day}/${releaseDate.month}/${releaseDate.year}';
  }

  @override
  Widget build(BuildContext context) {
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
                _buildChapterHeader(),
              ],
            ),
          ),
          _buildChapterList(),
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
            setState(() {
              _isFavorite = !_isFavorite;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isFavorite ? 'Added to favorites' : 'Removed from favorites',
                ),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Share functionality coming soon!')),
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
            child: Icon(
              Icons.menu_book,
              size: 100,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManhwaInfo() {
    final description = descriptions[widget.name] ?? 
        'An epic manhwa filled with adventure, action, and unforgettable characters. Follow the journey of our protagonist as they face incredible challenges and discover their true potential.';

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
            children: widget.genre.split(', ').map((genre) {
              return Chip(
                label: Text(
                  genre,
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
              _buildInfoChip(Icons.book, '${widget.totalChapters} Chapters'),
              const SizedBox(width: 12),
              _buildInfoChip(Icons.star, '4.8'),
              const SizedBox(width: 12),
              _buildInfoChip(Icons.check_circle, 'Ongoing'),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              setState(() {
                _isDescriptionExpanded = !_isDescriptionExpanded;
              });
            },
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
                Text(
                  _isDescriptionExpanded ? 'Show less' : 'Show more',
                  style: const TextStyle(
                    color: Color(0xFF6c5ce7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
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
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          if (_lastReadChapter > 0) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToReader(_lastReadChapter + 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6c5ce7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: Text(
                  'Continue Reading - Chapter ${_lastReadChapter + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _navigateToReader(1),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF6c5ce7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.play_arrow, color: Color(0xFF6c5ce7)),
              label: const Text(
                'Start from Beginning',
                style: TextStyle(
                  color: Color(0xFF6c5ce7),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildChapterHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Chapters (${widget.totalChapters})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.download, color: Color(0xFF6c5ce7)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Download functionality coming soon!')),
                  );
                },
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
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final chapter = chapters[index];
          return _buildChapterTile(chapter);
        },
        childCount: chapters.length,
      ),
    );
  }

  Widget _buildChapterTile(Chapter chapter) {
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
        title: Text(
          'Chapter ${chapter.number}: ${chapter.title}',
          style: TextStyle(
            color: chapter.isRead ? Colors.white : Colors.grey[300],
            fontWeight: chapter.isRead ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          chapter.releaseDate,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chapter.isDownloaded)
              Icon(
                Icons.download_done,
                color: Colors.green[400],
                size: 20,
              ),
            if (chapter.isRead)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF6c5ce7),
                size: 20,
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToReader(int chapterNumber) {
    // For now, just show a message - later replace with actual navigation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${widget.name} - Chapter $chapterNumber'),
        backgroundColor: const Color(0xFF6c5ce7),
      ),
    );
    
    // Update last read chapter
    setState(() {
      if (chapterNumber > _lastReadChapter) {
        _lastReadChapter = chapterNumber;
        // Mark chapters as read up to current chapter
        for (int i = 0; i < chapterNumber && i < chapters.length; i++) {
          chapters[i] = Chapter(
            number: chapters[i].number,
            title: chapters[i].title,
            releaseDate: chapters[i].releaseDate,
            isRead: true,
            isDownloaded: chapters[i].isDownloaded,
          );
        }
      }
    });
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
              _buildSortOption('Latest First', Icons.arrow_downward),
              _buildSortOption('Oldest First', Icons.arrow_upward),
              _buildSortOption('Unread First', Icons.visibility_off),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6c5ce7)),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: () {
        Navigator.pop(context);
        setState(() {
          if (title == 'Oldest First') {
            chapters.sort((a, b) => a.number.compareTo(b.number));
          } else if (title == 'Latest First') {
            chapters.sort((a, b) => b.number.compareTo(a.number));
          } else if (title == 'Unread First') {
            chapters.sort((a, b) => a.isRead ? 1 : -1);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sorted by $title')),
        );
      },
    );
  }
}