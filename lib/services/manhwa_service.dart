// services/manhwa_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/manwha.dart';
import '../models/chapter.dart';

abstract class ManhwaService {
  Future<List<Manhwa>> getAllManhwa();
  Future<Manhwa?> getManhwaById(String id);
  Future<List<Chapter>> getChapters(String manhwaId);
  Future<void> addToLibrary(String manhwaId);
  Future<void> removeFromLibrary(String manhwaId);
  Future<void> syncReadingProgress(String manhwaId, int lastReadChapter);
}

class HybridManhwaService implements ManhwaService {
  final String apiBaseUrl;
  final ScrapingPlugin scrapingPlugin;
  final StorageService storageService;
  final String userId;

  HybridManhwaService({
    required this.apiBaseUrl,
    required this.scrapingPlugin,
    required this.storageService,
    required this.userId,
  });

  @override
  Future<List<Manhwa>> getAllManhwa() async {
    try {
      // 1. Get user's library from your API
      final libraryResponse = await http.get(
        Uri.parse('$apiBaseUrl/users/$userId/library'),
        headers: {'Content-Type': 'application/json'},
      );

      if (libraryResponse.statusCode != 200) {
        throw Exception('Failed to fetch library');
      }

      final libraryData = json.decode(libraryResponse.body);
      final List<String> manhwaIds = List<String>.from(libraryData['manhwa_ids']);

      // 2. For each manhwa, get details from storage or plugin
      final List<Manhwa> manhwas = [];
      
      for (final manhwaId in manhwaIds) {
        // Check stored data first
        Manhwa? storedManhwa = await storageService.getManhwa(manhwaId);
        
        if (storedManhwa != null && !_shouldRefreshManhwaData(storedManhwa)) {
          manhwas.add(storedManhwa);
        } else {
          // Use plugin to get fresh data
          try {
            final manhwaData = await scrapingPlugin.getManhwaDetails(manhwaId);
            final manhwa = Manhwa.fromPluginData(manhwaData);
            manhwas.add(manhwa);
            
            // Store the result
            await storageService.saveManhwa(manhwa);
          } catch (e) {
            // If plugin fails, use stored data if available
            if (storedManhwa != null) {
              manhwas.add(storedManhwa);
            }
            print('Plugin failed for manhwa $manhwaId: $e');
          }
        }
      }

      return manhwas;
    } catch (e) {
      // Fallback to stored data if API fails
      return await storageService.getAllManhwa();
    }
  }

  @override
  Future<Manhwa?> getManhwaById(String id) async {
    // Check stored data first
    Manhwa? storedManhwa = await storageService.getManhwa(id);
    
    if (storedManhwa != null && !_shouldRefreshManhwaData(storedManhwa)) {
      return storedManhwa;
    }

    // Use plugin to get fresh data
    try {
      final manhwaData = await scrapingPlugin.getManhwaDetails(id);
      final manhwa = Manhwa.fromPluginData(manhwaData);
      await storageService.saveManhwa(manhwa);
      return manhwa;
    } catch (e) {
      print('Plugin failed for manhwa $id: $e');
      return storedManhwa; // Return stored version if plugin fails
    }
  }

  @override
  Future<List<Chapter>> getChapters(String manhwaId) async {
    // Get stored chapters
    List<Chapter>? storedChapters = await storageService.getChapters(manhwaId);
    
    if (storedChapters != null && !_shouldCheckForNewChapters(manhwaId)) {
      return storedChapters;
    }

    // Use plugin to get fresh chapter data
    try {
      final chapterData = await scrapingPlugin.getChapters(manhwaId);
      final chapters = chapterData.map((data) => Chapter.fromPluginData(data)).toList();
      await storageService.saveChapters(manhwaId, chapters);
      await storageService.updateLastChapterCheck(manhwaId, DateTime.now());
      return chapters;
    } catch (e) {
      print('Plugin failed for chapters $manhwaId: $e');
      return storedChapters ?? []; // Return stored or empty list
    }
  }

  @override
  Future<void> addToLibrary(String manhwaId) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/users/$userId/library'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'manhwa_id': manhwaId}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to add to library');
      }

      // Preload manhwa data using plugin
      await getManhwaById(manhwaId);
    } catch (e) {
      print('Failed to add manhwa to library: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeFromLibrary(String manhwaId) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/users/$userId/library/$manhwaId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to remove from library');
      }

      // Clear stored data
      await storageService.removeManhwa(manhwaId);
    } catch (e) {
      print('Failed to remove manhwa from library: $e');
      rethrow;
    }
  }

  @override
  Future<void> syncReadingProgress(String manhwaId, int lastReadChapter) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/users/$userId/progress'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'manhwa_id': manhwaId,
          'last_read_chapter': lastReadChapter,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to sync reading progress');
      }
    } catch (e) {
      print('Failed to sync reading progress: $e');
      // Don't rethrow - reading progress sync can fail silently
    }
  }

  bool _shouldRefreshManhwaData(Manhwa manhwa) {
    // Refresh manhwa metadata every 24 hours
    return manhwa.lastUpdated == null || 
           DateTime.now().difference(manhwa.lastUpdated!).inHours > 24;
  }

  bool _shouldCheckForNewChapters(String manhwaId) {
    // Check for new chapters every 6 hours
    final lastCheck = storageService.getLastChapterCheckTime(manhwaId);
    return lastCheck == null || 
           DateTime.now().difference(lastCheck).inHours > 6;
  }
}

// Interface for your QuickJS plugin system
abstract class ScrapingPlugin {
  Future<Map<String, dynamic>> getManhwaDetails(String manhwaId);
  Future<List<Map<String, dynamic>>> getChapters(String manhwaId);
  Future<List<String>> search(String query);
}


abstract class StorageService {
  Future<Manhwa?> getManhwa(String id);
  Future<List<Chapter>?> getChapters(String manhwaId);
  Future<void> saveManhwa(Manhwa manhwa);
  Future<void> saveChapters(String manhwaId, List<Chapter> chapters);
  Future<List<Manhwa>> getAllManhwa();
  Future<void> removeManhwa(String manhwaId);
  DateTime? getLastChapterCheckTime(String manhwaId);
  Future<void> updateLastChapterCheck(String manhwaId, DateTime time);
}