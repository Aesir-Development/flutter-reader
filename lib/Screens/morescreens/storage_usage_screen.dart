import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutterreader/services/sqlite_progress_service.dart';


class StorageUsageScreen extends StatefulWidget {
  const StorageUsageScreen({Key? key}) : super(key: key);

  @override
  State<StorageUsageScreen> createState() => _StorageUsageScreenState();
}

class _StorageUsageScreenState extends State<StorageUsageScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _storageData = {};
  List<Map<String, dynamic>> _manhwaStorageList = [];

  @override
  void initState() {
    super.initState();
    _calculateStorageUsage();
  }

  Future<void> _calculateStorageUsage() async {
    setState(() => _isLoading = true);
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final manhwaDir = Directory('${dir.path}/manhwa');
      
      int totalFiles = 0;
      int totalSize = 0;
      int totalManhwas = 0;
      List<Map<String, dynamic>> manhwaList = [];
      
      if (await manhwaDir.exists()) {
        final manhwas = await manhwaDir.list().toList();
        
        for (var manhwaFolder in manhwas) {
          if (manhwaFolder is Directory) {
            final manhwaName = manhwaFolder.path.split('/').last;
            int manhwaFiles = 0;
            int manhwaSize = 0;
            List<Map<String, dynamic>> chapterList = [];
            
            final chapters = await manhwaFolder.list().toList();
            for (var chapterFolder in chapters) {
              if (chapterFolder is Directory) {
                final chapterNumber = chapterFolder.path.split('/').last;
                int chapterFiles = 0;
                int chapterSize = 0;
                
                final files = await chapterFolder.list().toList();
                for (var file in files) {
                  if (file is File) {
                    try {
                      final size = await file.length();
                      chapterFiles++;
                      chapterSize += size;
                    } catch (e) {
                      // Skip files that can't be read
                    }
                  }
                }
                
                if (chapterFiles > 0) {
                  chapterList.add({
                    'number': chapterNumber,
                    'files': chapterFiles,
                    'size': chapterSize,
                  });
                  
                  manhwaFiles += chapterFiles;
                  manhwaSize += chapterSize;
                }
              }
            }
            
            if (manhwaFiles > 0) {
              // Sort chapters by number
              chapterList.sort((a, b) {
                final aNum = double.tryParse(a['number']) ?? 0;
                final bNum = double.tryParse(b['number']) ?? 0;
                return aNum.compareTo(bNum);
              });
              
              manhwaList.add({
                'name': manhwaName,
                'displayName': _formatManhwaName(manhwaName),
                'chapters': chapterList.length,
                'files': manhwaFiles,
                'size': manhwaSize,
                'chapterDetails': chapterList,
              });
              
              totalManhwas++;
              totalFiles += manhwaFiles;
              totalSize += manhwaSize;
            }
          }
        }
      }
      
      // Sort manhwas by size (largest first)
      manhwaList.sort((a, b) => (b['size'] as int).compareTo(a['size'] as int));
      
      setState(() {
        _storageData = {
          'totalManhwas': totalManhwas,
          'totalChapters': manhwaList.fold(0, (sum, manhwa) => sum + (manhwa['chapters'] as int)),
          'totalFiles': totalFiles,
          'totalSize': totalSize,
        };
        _manhwaStorageList = manhwaList;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to calculate storage: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatManhwaName(String name) {
    return name
        .split('-')
        .map((word) => word.isNotEmpty 
            ? word[0].toUpperCase() + word.substring(1).toLowerCase() 
            : word)
        .join(' ');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Color _getSizeColor(int size) {
    if (size < 50 * 1024 * 1024) return Colors.green; // < 50MB
    if (size < 200 * 1024 * 1024) return Colors.orange; // < 200MB
    return Colors.red; // > 200MB
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
          'Storage Usage',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _calculateStorageUsage,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6c5ce7)))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_manhwaStorageList.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildStorageSummary(),
        Expanded(child: _buildManhwaList()),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storage, color: Color(0xFF6c5ce7), size: 64),
          const SizedBox(height: 16),
          Text(
            'No Downloaded Content',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Download some chapters to see storage usage.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStorageSummary() {
    final totalSize = _storageData['totalSize'] as int;
    final totalManhwas = _storageData['totalManhwas'] as int;
    final totalChapters = _storageData['totalChapters'] as int;
    final totalFiles = _storageData['totalFiles'] as int;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6c5ce7).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6c5ce7).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storage, color: Color(0xFF6c5ce7), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Storage Used',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatBytes(totalSize),
                      style: TextStyle(
                        color: _getSizeColor(totalSize),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildStatCard('Manhwas', totalManhwas.toString(), Icons.book)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Chapters', totalChapters.toString(), Icons.bookmark)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Images', totalFiles.toString(), Icons.image)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF6c5ce7), size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildManhwaList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _manhwaStorageList.length,
      itemBuilder: (context, index) {
        final manhwa = _manhwaStorageList[index];
        final size = manhwa['size'] as int;
        final chapters = manhwa['chapters'] as int;
        final files = manhwa['files'] as int;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2a2a2a),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getSizeColor(size).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.menu_book, color: _getSizeColor(size), size: 20),
            ),
            title: Text(
              manhwa['displayName'],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '$chapters chapters • $files images • ${_formatBytes(size)}',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            children: (manhwa['chapterDetails'] as List<Map<String, dynamic>>).map((chapter) {
              final chapterSize = chapter['size'] as int;
              final chapterFiles = chapter['files'] as int;
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a1a),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6c5ce7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${chapter['number']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chapter ${chapter['number']}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '$chapterFiles images',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatBytes(chapterSize),
                      style: TextStyle(
                        color: _getSizeColor(chapterSize),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}