import 'package:flutter/material.dart';
import '../Data/manhwa_data.dart';
import '../models/manwha.dart';
import 'manhwa_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Manhwa> manhwas = [];

  @override
  void initState() {
    super.initState();
    manhwas = manhwaDatabase.values.toList();
  }

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
              genre: manhwa.genreString,
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
                child: manhwa.coverImageUrl != null
                    ? Image.network(
                        manhwa.coverImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(manhwa),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.grey[900],
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                      )
                    : _buildPlaceholderImage(manhwa),
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
                          manhwa.genreString,
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

  Widget _buildPlaceholderImage(Manhwa manhwa) {
    return Container(
      color: const Color(0xFF6c5ce7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                manhwa.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
        setState(() {
          switch (title) {
            case 'Name (A-Z)':
              manhwas.sort((a, b) => a.name.compareTo(b.name));
              break;
            case 'Total Chapters':
              manhwas.sort((a, b) => b.totalChapters.compareTo(a.totalChapters));
              break;
            case 'Genre':
              manhwas.sort((a, b) => a.genreString.compareTo(b.genreString));
              break;
            default:
              break;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sorted by $title')),
        );
      },
    );
  }
}