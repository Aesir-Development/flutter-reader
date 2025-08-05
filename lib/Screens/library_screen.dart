import 'package:flutter/material.dart';
import 'manhwa_screen.dart';

class Manhwa {
  final String id;
  final String name;
  final String genre;
  final int totalChapters;
  final String coverUrl;

  Manhwa({
    required this.id,
    required this.name,
    required this.genre,
    required this.totalChapters,
    required this.coverUrl,
  });
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _currentIndex = 0;

  // Hardcoded test data
  final List<Manhwa> manhwas = [
    Manhwa(
      id: '1',
      name: 'Solo Leveling',
      genre: 'Action, Fantasy',
      totalChapters: 179,
      coverUrl: 'https://cdn.flamecomics.xyz/uploads/images/series/1/thumbnail.png',),
    Manhwa(
      id: '2',
      name: 'Tower of God',
      genre: 'Adventure, Drama',
      totalChapters: 588,
      coverUrl: 'https://via.placeholder.com/200x280/a29bfe/ffffff?text=Tower+of+God',
    ),
    Manhwa(
      id: '3',
      name: 'The Beginning After The End',
      genre: 'Fantasy, Adventure',
      totalChapters: 169,
      coverUrl: 'https://via.placeholder.com/200x280/fd79a8/ffffff?text=TBATE',
    ),
    Manhwa(
      id: '4',
      name: 'Noblesse',
      genre: 'Action, Supernatural',
      totalChapters: 544,
      coverUrl: 'https://via.placeholder.com/200x280/00b894/ffffff?text=Noblesse',
    ),
    Manhwa(
      id: '5',
      name: 'God of High School',
      genre: 'Action, Martial Arts',
      totalChapters: 569,
      coverUrl: 'https://via.placeholder.com/200x280/e17055/ffffff?text=GoHS',
    ),
    Manhwa(
      id: '6',
      name: 'Omniscient Reader',
      genre: 'Fantasy, Drama',
      totalChapters: 209,
      coverUrl: 'https://via.placeholder.com/200x280/0984e3/ffffff?text=ORV',
    ),
    Manhwa(
      id: '7',
      name: 'Hardcore Leveling Warrior',
      genre: 'Action, Gaming',
      totalChapters: 329,
      coverUrl: 'https://via.placeholder.com/200x280/fdcb6e/ffffff?text=HCLW',
    ),
    Manhwa(
      id: '8',
      name: 'Lookism',
      genre: 'Drama, School',
      totalChapters: 476,
      coverUrl: 'https://via.placeholder.com/200x280/6c5ce7/ffffff?text=Lookism',
    ),
    Manhwa(
      id: '9',
      name: 'Windbreaker',
      genre: 'Sports, Drama',
      totalChapters: 488,
      coverUrl: 'https://via.placeholder.com/200x280/00cec9/ffffff?text=Windbreaker',
    ),
    Manhwa(
      id: '10',
      name: 'UnOrdinary',
      genre: 'Supernatural, School',
      totalChapters: 329,
      coverUrl: 'https://via.placeholder.com/200x280/74b9ff/ffffff?text=UnOrdinary',
    ),
    Manhwa(
      id: '11',
      name: 'Weak Hero',
      genre: 'Action, School',
      totalChapters: 285,
      coverUrl: 'https://via.placeholder.com/200x280/55a3ff/ffffff?text=Weak+Hero',
    ),
    Manhwa(
      id: '12',
      name: 'Eleceed',
      genre: 'Action, Supernatural',
      totalChapters: 279,
      coverUrl: 'https://via.placeholder.com/200x280/ff7675/ffffff?text=Eleceed',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: _buildAppBar(),
      body: _buildLibraryGrid(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF2a2a2a),
      elevation: 0,
      title: const Text(
        'Library',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () {
            // Search functionality to be implemented
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Search functionality coming soon!')),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.sort, color: Colors.white),
          onPressed: () {
            // Sort functionality to be implemented
            _showSortOptions();
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildLibraryGrid() {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160, // max width of each tile
            mainAxisExtent: 260,     // fixed height of each tile
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemCount: manhwas.length,
          itemBuilder: (context, index) {
            return _buildManhwaCard(manhwas[index]);
          },
        );
      },
    ),
  );
}


  Widget _buildManhwaCard(Manhwa manhwa) {
    return GestureDetector(
      onTap: () {
        // Navigate to manhwa detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ManhwaScreen(
              id: manhwa.id,
              name: manhwa.name,
              genre: manhwa.genre,
              totalChapters: manhwa.totalChapters,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           // Cover Image
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  manhwa.coverUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.white70),
                    ),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[900],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
            ),
            // Info Section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      manhwa.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          manhwa.genre,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${manhwa.totalChapters} chapters',
                          style: const TextStyle(
                            color: Color(0xFF6c5ce7),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xFF2a2a2a),
      selectedItemColor: const Color(0xFF6c5ce7),
      unselectedItemColor: Colors.grey[400],
      selectedFontSize: 12,
      unselectedFontSize: 12,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
        
        // Show which tab was tapped (functionality to be implemented)
        final tabNames = ['Library', 'Updates', 'History', 'Browse', 'More'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tabNames[index]} tab selected'),
            duration: const Duration(milliseconds: 500),
          ),
        );
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.library_books),
          label: 'Library',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.update),
          label: 'Updates',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.explore),
          label: 'Browse',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.more_horiz),
          label: 'More',
        ),
      ],
    );
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
                'Sort by',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildSortOption('Name (A-Z)', Icons.sort_by_alpha),
              _buildSortOption('Recently Added', Icons.access_time),
              _buildSortOption('Total Chapters', Icons.numbers),
              _buildSortOption('Genre', Icons.category),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sorted by $title')),
        );
      },
    );
  }
}