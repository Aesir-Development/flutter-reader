import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutterreader/models/manwha.dart';
import 'package:flutterreader/models/chapter.dart';
import 'package:flutterreader/services/plugin_service.dart';
import 'package:flutterreader/services/manhwa_service.dart';

class ManhwaDetailScreen extends StatefulWidget {
  final String manhwaId;
  final String name;
  final String pluginName;

  const ManhwaDetailScreen({
    super.key,
    required this.manhwaId,
    required this.name,
    required this.pluginName,
  });

  @override
  State<ManhwaDetailScreen> createState() => _ManhwaDetailScreenState();
}

class _ManhwaDetailScreenState extends State<ManhwaDetailScreen> {
  Manhwa? manhwa;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadManhwa();
  }

  Future<void> _loadManhwa() async {
    try {
      // Validate inputs
      if (widget.manhwaId.isEmpty) {
        throw Exception("Invalid manhwa ID");
      }
      if (widget.pluginName.isEmpty) {
        throw Exception("Invalid plugin name");
      }

      debugPrint("Loading manhwa: ID=${widget.manhwaId}, Plugin=${widget.pluginName}, Name=${widget.name}");

      await PluginService.loadPlugins();
      final result = await PluginService.getManhwaDetails(
        widget.pluginName,
        widget.manhwaId,
        name: widget.name,
      );

      if (result == null) {
        throw Exception("No manhwa details returned for ID: ${widget.manhwaId}");
      }

      setState(() {
        manhwa = result;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading manhwa: ID=${widget.manhwaId}, Plugin=${widget.pluginName}: $e\n$stackTrace');
      setState(() {
        error = 'Failed to load manhwa details: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _addToLibrary() async {
    if (manhwa == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot add to library: No manhwa data'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      await ManhwaService.addToLibrary(manhwa!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to library'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error adding to library: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to library: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2a2a2a),
        title: Text(
          manhwa?.name ?? widget.name,
          style: const TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6c5ce7)))
          : error != null
              ? Center(child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 16)))
              : manhwa == null
                  ? const Center(
                      child: Text('No data available', style: TextStyle(color: Colors.grey, fontSize: 16)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 200,
                              height: 300,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: manhwa!.coverImageUrl != null
                                    ? Image.network(
                                        manhwa!.coverImageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: const Color(0xFF6c5ce7),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.menu_book, color: Colors.white, size: 48),
                                                const SizedBox(height: 8),
                                                Text(
                                                  manhwa!.name,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        loadingBuilder: (context, child, progress) => progress == null
                                            ? child
                                            : const Center(child: CircularProgressIndicator()),
                                      )
                                    : Container(
                                        color: const Color(0xFF6c5ce7),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.menu_book, color: Colors.white, size: 48),
                                              const SizedBox(height: 8),
                                              Text(
                                                manhwa!.name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            manhwa!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Author: ${manhwa!.author}',
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          Text(
                            'Artist: ${manhwa!.artist}',
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Status: ${manhwa!.status}',
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: manhwa!.genres
                                .map((genre) => Chip(
                                      label: Text(genre, style: const TextStyle(fontSize: 12)),
                                      backgroundColor: const Color(0xFF6c5ce7).withOpacity(0.2),
                                      labelStyle: const TextStyle(color: Colors.white),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            manhwa!.description,
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _addToLibrary,
                              icon: const Icon(Icons.library_add, color: Colors.white),
                              label: const Text('Add to Library'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6c5ce7),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Chapters',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: manhwa!.chapters.length,
                            itemBuilder: (context, index) {
                              final chapter = manhwa!.chapters[index];
                              return ListTile(
                                title: Text(
                                  'Chapter ${chapter.number}: ${chapter.title}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: chapter.releaseDate != null
                                    ? Text(
                                        'Released: ${chapter.releaseDate!.toIso8601String().split('T')[0]}',
                                        style: const TextStyle(color: Colors.grey),
                                      )
                                    : null,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Chapter reading not implemented yet'),
                                      backgroundColor: Colors.orange,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
    );
  }
}