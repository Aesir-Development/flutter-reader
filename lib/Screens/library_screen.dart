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
  final List<Manhwa> manhwas = [
    Manhwa(
      id: '1',
      name: 'Solo Leveling',
      genre: 'Action, Fantasy',
      totalChapters: 179,
      coverUrl: 'https://cdn.flamecomics.xyz/uploads/images/series/1/thumbnail.png',
    ),
    Manhwa(
      id: '2',
      name: "Omniscient Reader's Viewpoint",
      genre: 'Adventure, Drama',
      totalChapters: 588,
      coverUrl: 'https://via.placeholder.com/200x280/a29bfe/ffffff?text=Tower+of+God',
    ),
    Manhwa(
      id: '3',
      name: "A Stepmother's Märchen",
      genre: 'Fantasy, Romance',
      totalChapters: 66,
      coverUrl: 'https://cdn.flamecomics.xyz/uploads/images/series/37/thumbnail.png',
    ),
    Manhwa(
      id: '4',
      name: 'Black Cat and Soldier',
      genre: 'Action, Drama',
      totalChapters: 50,
      coverUrl: 'https://via.placeholder.com/200x280/6c5ce7/ffffff?text=Black+Cat+and+Soldier',
    ),
    
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildLibraryGrid()),
      ],
    );
  }

  Widget _buildLibraryGrid() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          mainAxisExtent: 260,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: manhwas.length,
        itemBuilder: (context, index) {
          return _buildManhwaCard(manhwas[index]);
        },
      ),
    );
  }

  Widget _buildManhwaCard(Manhwa manhwa) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ManhwaScreen(
              manhwaId: manhwa.id,
              name: manhwa.name,
              genre: manhwa.genre,
             // totalChapters: manhwa.totalChapters,
              //chapters: [], 
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
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
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
