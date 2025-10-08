import 'dart:convert';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:flutter_lua_vm/lua_vm.dart';
import 'package:flutterreader/models/manwha.dart';
import 'package:flutterreader/services/plugin_service.dart';
import 'package:flutterreader/Screens/manhwa_detail_screen.dart';

class ManhwaSearchDelegate extends SearchDelegate {
  ManhwaSearchDelegate();

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: const Color(0xFF1a1a1a),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2a2a2a),
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.grey),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildSuggestions(BuildContext context) => const Center(
        child: Text(
          'Enter a manhwa name',
          style: TextStyle(color: Colors.grey),
        ),
      );

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<Manhwa>>(
      future: _searchAllPlugins(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6c5ce7)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No results found', style: TextStyle(color: Colors.grey)),
          );
        }

        final results = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              mainAxisExtent: 260,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: results.length,
            itemBuilder: (context, index) => _buildManhwaCard(context, results[index]),
          ),
        );
      },
    );
  }

  /// Searches the query in all plugins and combines the results.
  Future<List<Manhwa>> _searchAllPlugins(String query) async {
    try {
      await PluginService.loadPlugins();
      final pluginNames = await PluginService.getPluginNames();
      final List<Manhwa> allManhwas = [];

      for (String pluginName in pluginNames) {
        try {
          List<Pointer<Variant>> args = [PluginService.lvm.stringArg(query)];
          final result = await PluginService.lvm.exec("$pluginName.GetSearch", args);
          debugPrint("Search result for $pluginName: $result");

          if (result == null || result.isEmpty) continue;

          List<dynamic> jsonResult = jsonDecode(result);
          var manhwas = jsonResult.map((item) => Manhwa(
                id: item['id']?.toString() ?? '',
                name: item['title'] ?? '',
                description: item['description'] ?? '',
                genres: List<String>.from(item['genres'] ?? []),

                rating: (item['rating'] ?? 0.0).toDouble(),
                status: item['status'] ?? '',
                author: item['author'] ?? '',
                artist: item['artist'] ?? '',
                lastUpdated: item['lastUpdated'] != null ? DateTime.tryParse(item['lastUpdated']) : null,
                chapters: [], // Empty list; chapters fetched in ManhwaDetailScreen
                coverImageUrl: item['thumbnail'],
                pluginName: pluginName,
                chapterCount: item['chapter_count']?.toInt() ?? 0, // Use chapter_count from search
              )).toList();

          allManhwas.addAll(manhwas);
        } catch (e, stackTrace) {
          debugPrint('Search failed for $pluginName: $e\n$stackTrace');
        }
      }

      return allManhwas;
    } catch (e, stackTrace) {
      debugPrint("Search error: $e\n$stackTrace");
      return [];
    }
  }

  /// Builds a card for a manhwa in the search results.
  Widget _buildManhwaCard(BuildContext context, Manhwa manhwa) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => ManhwaDetailScreen(
            manhwaId: manhwa.id,
            name: manhwa.name,
            pluginName: manhwa.pluginName ?? 'FLAMECOMICS',
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        loadingBuilder: (context, child, progress) => progress == null
                            ? child
                            : Container(
                                color: Colors.grey[900],
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                      )
                    : _buildPlaceholderImage(manhwa),
              ),
            ),
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
                          style: TextStyle(color: Colors.grey[400], fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${manhwa.chapterCount} chapters',
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

  /// Builds a placeholder image when the cover image fails to load.
  Widget _buildPlaceholderImage(Manhwa manhwa) => Container(
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