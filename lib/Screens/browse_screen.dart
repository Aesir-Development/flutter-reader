import 'package:flutter/material.dart';
import 'manhwa_screen.dart';

class Genre {
  final String name;
  final IconData icon;
  final Color color;

  Genre({required this.name, required this.icon, required this.color});
}

class FeaturedManhwa {
  final String id;
  final String title;
  final String description;
  final String genre;
  final double rating;
  final String coverUrl;
  final bool isNew;

  FeaturedManhwa({
    required this.id,
    required this.title,
    required this.description,
    required this.genre,
    required this.rating,
    required this.coverUrl,
    this.isNew = false,
  });
}

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({Key? key}) : super(key: key);

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final List<Genre> genres = [
    Genre(name: 'Action', icon: Icons.flash_on, color: Colors.red),
    Genre(name: 'Romance', icon: Icons.favorite, color: Colors.pink),
    Genre(name: 'Fantasy', icon: Icons.auto_awesome, color: Colors.purple),
    Genre(name: 'Drama', icon: Icons.theater_comedy, color: Colors.orange),
    Genre(name: 'Comedy', icon: Icons.sentiment_very_satisfied, color: Colors.yellow),
    Genre(name: 'Slice of Life', icon: Icons.home, color: Colors.green),
    Genre(name: 'Supernatural', icon: Icons.psychology, color: Colors.indigo),
    Genre(name: 'School', icon: Icons.school, color: Colors.blue),
  ];

  final List<FeaturedManhwa> featuredManhwas = [
    FeaturedManhwa(
      id: 'solo-leveling',
      title: 'Solo Leveling',
      description: 'The weakest hunter becomes the strongest through a mysterious system.',
      genre: 'Action, Fantasy',
      rating: 4.9,
      coverUrl: 'https://cdn.flamecomics.xyz/uploads/images/series/1/thumbnail.png',
      isNew: false,
    ),
    FeaturedManhwa(
      id: "Omniscient Reader's Viewpoint",
      title: "Omniscient Reader's Viewpoint",
      description: 'A reader finds himself inside his favorite web novel.',
      genre: 'Adventure, Drama',
      rating: 4.7,
      coverUrl: 'https://via.placeholder.com/200x280/a29bfe/ffffff?text=ORV',
      isNew: true,
    ),
    FeaturedManhwa(
      id: "A Stepmother's Märchen",
      title: "A Stepmother's Märchen",
      description: 'A tale of redemption and second chances in a fantasy world.',
      genre: 'Fantasy, Romance',
      rating: 4.8,
      coverUrl: 'https://cdn.flamecomics.xyz/uploads/images/series/37/thumbnail.png',
    ),
    FeaturedManhwa(
      id: '4',
      title: 'Black Cat and Soldier',
      description: 'A gripping post-apocalyptic story of survival and companionship.',
      genre: 'Action, Drama',
      rating: 4.6,
      coverUrl: 'https://via.placeholder.com/200x280/6c5ce7/ffffff?text=Black+Cat',
    ),
  ];

  final List<String> popularTags = [
    'Trending', 'Completed', 'Ongoing', 'New Release', 'Top Rated',
    'Action', 'Romance', 'Fantasy', 'Drama', 'Comedy'
  ];

  String selectedTag = 'Trending';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 24),
          _buildFeaturedSection(),
          const SizedBox(height: 24),
          _buildGenresSection(),
          const SizedBox(height: 24),
          _buildPopularTagsSection(),
          const SizedBox(height: 24),
          _buildRecommendedSection(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search manhwas...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          suffixIcon: IconButton(
            icon: Icon(Icons.filter_list, color: Colors.grey[400]),
            onPressed: _showFilterOptions,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onSubmitted: (query) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Searching for: $query')),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Featured',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: featuredManhwas.length,
            itemBuilder: (context, index) {
              return _buildFeaturedCard(featuredManhwas[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(FeaturedManhwa manhwa) {
    return GestureDetector(
      onTap: () => _navigateToManhwa(manhwa),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 16),
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
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    manhwa.coverUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.white70),
                      ),
                    ),
                  ),
                ),
                if (manhwa.isNew)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.yellow, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          manhwa.rating.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manhwa.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    manhwa.genre,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenresSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Browse by Genre',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: genres.length,
          itemBuilder: (context, index) {
            return _buildGenreCard(genres[index]);
          },
        ),
      ],
    );
  }

  Widget _buildGenreCard(Genre genre) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Browsing ${genre.name} manhwas')),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: genre.color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              genre.icon,
              color: genre.color,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              genre.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Popular Tags',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: popularTags.map((tag) => _buildTagChip(tag)).toList(),
        ),
      ],
    );
  }

  Widget _buildTagChip(String tag) {
    final isSelected = tag == selectedTag;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTag = tag;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Showing $tag manhwas')),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6c5ce7) : const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF6c5ce7) : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          tag,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recommended for You',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('View all recommendations')),
                );
              },
              child: const Text(
                'View All',
                style: TextStyle(color: Color(0xFF6c5ce7)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: featuredManhwas.length,
          itemBuilder: (context, index) {
            return _buildRecommendedItem(featuredManhwas[index]);
          },
        ),
      ],
    );
  }

  Widget _buildRecommendedItem(FeaturedManhwa manhwa) {
    return GestureDetector(
      onTap: () => _navigateToManhwa(manhwa),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                manhwa.coverUrl,
                width: 60,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 60,
                  height: 80,
                  color: Colors.grey[800],
                  child: const Icon(Icons.broken_image, color: Colors.white70),
                ),
              ),
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
                          manhwa.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (manhwa.isNew)
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
                    manhwa.description,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6c5ce7).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          manhwa.genre,
                          style: const TextStyle(
                            color: Color(0xFF6c5ce7),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.star, color: Colors.yellow[700], size: 14),
                      const SizedBox(width: 2),
                      Text(
                        manhwa.rating.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToManhwa(FeaturedManhwa manhwa) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManhwaScreen(
          manhwaId: manhwa.id,
          name: manhwa.title,
          genre: manhwa.genre,
        ),
      ),
    );
  }

  void _showFilterOptions() {
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
                'Filter Options',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildFilterOption('Status', Icons.radio_button_checked),
              _buildFilterOption('Genre', Icons.category),
              _buildFilterOption('Rating', Icons.star),
              _buildFilterOption('Release Year', Icons.calendar_today),
              _buildFilterOption('Popularity', Icons.trending_up),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6c5ce7)),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Filter by $title - Coming soon!')),
        );
      },
    );
  }
}