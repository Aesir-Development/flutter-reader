import 'package:flutter/material.dart';
import 'package:flutterreader/services/sqlite_progress_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DownloadedChaptersScreen extends StatefulWidget {
  const DownloadedChaptersScreen({Key? key}) : super(key: key);

  @override
  State<DownloadedChaptersScreen> createState() => _DownloadedChaptersScreenState();
}

class _DownloadedChaptersScreenState extends State<DownloadedChaptersScreen> {
  List<Map<String, dynamic>> _downloadedChapters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloadedChapters();
  }

  Future<void> _loadDownloadedChapters() async {
    setState(() => _isLoading = true);
    try {
      final chapters = await SQLiteProgressService.getAllDownloadedChapters();
      setState(() {
        _downloadedChapters = chapters;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load downloads: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteChapterDownload(String manhwaId, double chapterNumber, String manhwaName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final chapterDir = Directory('${dir.path}/manhwa/$manhwaId/$chapterNumber');
      
      if (await chapterDir.exists()) {
        await chapterDir.delete(recursive: true);
      }
      
      await SQLiteProgressService.unmarkDownloaded(manhwaId, chapterNumber);
      
      setState(() {
        _downloadedChapters.removeWhere(
          (chapter) => chapter['manhwaId'] == manhwaId && chapter['chapterNumber'] == chapterNumber
        );
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chapter $chapterNumber of $manhwaName deleted'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete download: $e'),
          backgroundColor: Colors.red,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Downloaded Chapters',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDownloadedChapters,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6c5ce7)),
            )
          : _downloadedChapters.isEmpty
              ? _buildEmptyState()
              : _buildDownloadsList(),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off,
            size: 64,
            color: Color(0xFF6c5ce7),
          ),
          const SizedBox(height: 16),
          Text(
            'No Downloaded Chapters',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Download chapters from manhwa pages to read offline.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2a2a2a),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6c5ce7).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF6c5ce7), size: 32),
                const SizedBox(height: 12),
                Text(
                  'How to download chapters:',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Go to any manhwa page\n2. Tap the download icon next to chapters\n3. Wait for download to complete\n4. Chapters will appear here for offline reading',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsList() {
    // Group chapters by manhwa
    final groupedChapters = <String, List<Map<String, dynamic>>>{};
    for (final chapter in _downloadedChapters) {
      final manhwaName = chapter['manhwaName'] as String;
      if (!groupedChapters.containsKey(manhwaName)) {
        groupedChapters[manhwaName] = [];
      }
      groupedChapters[manhwaName]!.add(chapter);
    }

    // Sort chapters within each manhwa by chapter number
    for (final chapters in groupedChapters.values) {
      chapters.sort((a, b) => (a['chapterNumber'] as double).compareTo(b['chapterNumber'] as double));
    }

    return Column(
      children: [
        // Summary header
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2a2a2a),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6c5ce7).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.download_done, color: Color(0xFF6c5ce7), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_downloadedChapters.length} Chapters Downloaded',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Across ${groupedChapters.length} manhwa${groupedChapters.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Text(
                  'OFFLINE',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Downloads list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: groupedChapters.length,
            itemBuilder: (context, index) {
              final manhwaName = groupedChapters.keys.elementAt(index);
              final chapters = groupedChapters[manhwaName]!;
              
              return Card(
                color: const Color(0xFF2a2a2a),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                child: ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6c5ce7).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.menu_book, color: Color(0xFF6c5ce7), size: 20),
                  ),
                  title: Text(
                    manhwaName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    '${chapters.length} chapter${chapters.length == 1 ? '' : 's'} downloaded',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  children: chapters.map((chapter) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1a1a1a),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6c5ce7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '${chapter['chapterNumber']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          'Chapter ${chapter['chapterNumber']}',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'OFFLINE',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                              onPressed: () => _showDeleteConfirmation(chapter),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.play_arrow, color: Colors.grey, size: 18),
                          ],
                        ),
                        onTap: () {
                          // TODO: Navigate to reader with this specific chapter
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Opening $manhwaName Chapter ${chapter['chapterNumber']}'),
                              backgroundColor: const Color(0xFF2a2a2a),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> chapter) {
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
                'Delete Chapter ${chapter['chapterNumber']} of ${chapter['manhwaName']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Confirm Delete', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteChapterDownload(
                    chapter['manhwaId'].toString(),
                    chapter['chapterNumber'] as double,
                    chapter['manhwaName'] as String,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.grey),
                title: const Text('Cancel', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}