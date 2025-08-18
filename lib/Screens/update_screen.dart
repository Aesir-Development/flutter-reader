import 'package:flutter/material.dart';
import 'manhwa_screen.dart';

class UpdateItem {
  final String id;
  final String manhwaTitle;
  final int chapterNumber;
  final String chapterTitle;
  final DateTime updateTime;
  final String coverUrl;
  final bool isRead;
  final bool isNew;

  UpdateItem({
    required this.id,
    required this.manhwaTitle,
    required this.chapterNumber,
    required this.chapterTitle,
    required this.updateTime,
    required this.coverUrl,
    this.isRead = false,
    this.isNew = false,
  });
}

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({Key? key}) : super(key: key);

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';
  List<UpdateItem> allUpdates = [];
  
  final List<String> _filterOptions = ['All', 'Unread', 'Read', 'Downloaded'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _generateSampleUpdates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generateSampleUpdates() {
    final now = DateTime.now();
    allUpdates = [
      UpdateItem(
        id: 'solo-leveling',
        manhwaTitle: 'Solo Leveling',
        chapterNumber: 180,
        chapterTitle: 'The Final Battle Begins',
        updateTime: now.subtract(const Duration(hours: 2)),
        coverUrl: 'https://cdn.flamecomics.xyz/uploads/images/series/1/thumbnail.png',
        isNew: true,
      ),
      UpdateItem(
        id: "Omniscient Reader's Viewpoint",
        manhwaTitle: "Omniscient Reader's Viewpoint",
        chapterNumber: 173,
        chapterTitle: 'Constellation Wars',
        updateTime: now.subtract(const Duration(hours: 6)),
        coverUrl: 'https://via.placeholder.com/60x80/a29bfe/ffffff?text=ORV',
        isRead: true,
      ),
      UpdateItem(
        id: "A Stepmother's Märchen",
        manhwaTitle: "A Stepmother's Märchen",
        chapterNumber: 68,
        chapterTitle: 'New Beginnings',
        updateTime: now.subtract(const Duration(days: 1)),
        coverUrl: 'https://cdn.flamecomics.xyz/uploads/images/series/37/thumbnail.png',
      ),
      UpdateItem(
        id: '4',
        manhwaTitle: 'Black Cat and Soldier',
        chapterNumber: 51,
        chapterTitle: 'Unexpected Alliance',
        updateTime: now.subtract(const Duration(days: 2)),
        coverUrl: 'https://via.placeholder.com/60x80/6c5ce7/ffffff?text=Black+Cat',
        isRead: true,
      ),
      UpdateItem(
        id: 'solo-leveling',
        manhwaTitle: 'Solo Leveling',
        chapterNumber: 179,
        chapterTitle: 'Power Awakening',
        updateTime: now.subtract(const Duration(days: 3)),
        coverUrl: 'https://cdn.flamecomics.xyz/uploads/images/series/1/thumbnail.png',
        isRead: true,
      ),
      UpdateItem(
        id: "Omniscient Reader's Viewpoint",
        manhwaTitle: "Omniscient Reader's Viewpoint",
        chapterNumber: 172,
        chapterTitle: 'Hidden Truth',
        updateTime: now.subtract(const Duration(days: 4)),
        coverUrl: 'https://via.placeholder.com/60x80/a29bfe/ffffff?text=ORV',
        isRead: true,
      ),
    ];
  }

  List<UpdateItem> get filteredUpdates {
    switch (_selectedFilter) {
      case 'Unread':
        return allUpdates.where((update) => !update.isRead).toList();
      case 'Read':
        return allUpdates.where((update) => update.isRead).toList();
      case 'Downloaded':
        return allUpdates.where((update) => update.isRead).toList(); // Simulate downloaded
      default:
        return allUpdates;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabBar(),
        _buildFilterChips(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUpdatesTab(),
              _buildScheduleTab(),
              _buildHistoryTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF2a2a2a),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF6c5ce7),
        unselectedLabelColor: Colors.grey[400],
        indicatorColor: const Color(0xFF6c5ce7),
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Updates'),
          Tab(text: 'Schedule'),
          Tab(text: 'History'),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF2a2a2a),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterOptions.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF6c5ce7) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF6c5ce7) : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[400],
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.grey[400]),
            onPressed: () {
              setState(() {
                _generateSampleUpdates();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Updates refreshed!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUpdatesTab() {
    final updates = filteredUpdates;
    
    if (updates.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _generateSampleUpdates();
        });
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: updates.length,
        itemBuilder: (context, index) {
          return _buildUpdateItem(updates[index]);
        },
      ),
    );
  }

  Widget _buildScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScheduleCard('Today', [
            'Solo Leveling - Chapter 181 (Expected)',
            'Tower of God - Chapter 598 (Expected)',
          ], Colors.green),
          const SizedBox(height: 16),
          _buildScheduleCard('Tomorrow', [
            'Omniscient Reader\'s Viewpoint - Chapter 174',
            'The Beginning After The End - Chapter 178',
          ], Colors.blue),
          const SizedBox(height: 16),
          _buildScheduleCard('This Week', [
            'A Stepmother\'s Märchen - Chapter 69',
            'Black Cat and Soldier - Chapter 52',
            'Nano Machine - Chapter 145',
            'Return of the Mount Hua Sect - Chapter 98',
          ], Colors.orange),
          const SizedBox(height: 16),
          _buildScheduleCard('Next Week', [
            'Lookism - Chapter 478',
            'How to Fight - Chapter 156',
            'Manager Kim - Chapter 134',
          ], Colors.purple),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final readUpdates = allUpdates.where((u) => u.isRead).toList();
    
    if (readUpdates.isEmpty) {
      return _buildEmptyState(message: 'No reading history yet', icon: Icons.history);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: readUpdates.length,
      itemBuilder: (context, index) {
        return _buildHistoryItem(readUpdates[index]);
      },
    );
  }

  Widget _buildUpdateItem(UpdateItem update) {
    return GestureDetector(
      onTap: () => _navigateToManhwa(update),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: update.isNew ? const Color(0xFF6c5ce7).withOpacity(0.5) : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    update.coverUrl,
                    width: 50,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 50,
                      height: 70,
                      color: Colors.grey[800],
                      child: const Icon(Icons.broken_image, color: Colors.white70, size: 20),
                    ),
                  ),
                ),
                if (update.isNew)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          update.manhwaTitle,
                          style: TextStyle(
                            color: update.isRead ? Colors.grey[400] : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (update.isNew)
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
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chapter ${update.chapterNumber}: ${update.chapterTitle}',
                    style: TextStyle(
                      color: update.isRead ? Colors.grey[500] : const Color(0xFF6c5ce7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.grey[500],
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimeAgo(update.updateTime),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
                      if (update.isRead)
                        Icon(
                          Icons.check_circle,
                          color: Colors.grey[500],
                          size: 16,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color: Colors.grey[400],
                size: 20,
              ),
              onPressed: () => _showUpdateOptions(update),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(UpdateItem update) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              update.coverUrl,
              width: 40,
              height: 55,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 40,
                height: 55,
                color: Colors.grey[800],
                child: const Icon(Icons.broken_image, color: Colors.white70, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  update.manhwaTitle,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Chapter ${update.chapterNumber}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTimeAgo(update.updateTime),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(String title, List<String> items, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyState({String? message, IconData? icon}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon ?? Icons.update,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            message ?? 'No updates available',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${difference.inDays ~/ 7}w ago';
    }
  }

  void _navigateToManhwa(UpdateItem update) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManhwaScreen(
          manhwaId: update.id,
          name: update.manhwaTitle,
          genre: 'Action, Fantasy', // You might want to store this in UpdateItem
        ),
      ),
    );
  }

  void _showUpdateOptions(UpdateItem update) {
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
            children: [
              ListTile(
                leading: const Icon(Icons.visibility, color: Color(0xFF6c5ce7)),
                title: Text(
                  update.isRead ? 'Mark as Unread' : 'Mark as Read',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    final index = allUpdates.indexWhere((u) => 
                      u.id == update.id && u.chapterNumber == update.chapterNumber);
                    if (index != -1) {
                      allUpdates[index] = UpdateItem(
                        id: update.id,
                        manhwaTitle: update.manhwaTitle,
                        chapterNumber: update.chapterNumber,
                        chapterTitle: update.chapterTitle,
                        updateTime: update.updateTime,
                        coverUrl: update.coverUrl,
                        isRead: !update.isRead,
                        isNew: update.isNew,
                      );
                    }
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Color(0xFF6c5ce7)),
                title: const Text('Download Chapter', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Downloading ${update.manhwaTitle} Chapter ${update.chapterNumber}')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Color(0xFF6c5ce7)),
                title: const Text('Share', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share functionality coming soon!')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}