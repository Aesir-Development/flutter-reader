import 'dart:async';
import 'sqlite_progress_service.dart';
import 'api_service.dart';
import 'manhwa_service.dart';

class ProgressService {
  static Timer? _syncTimer;
  static bool _isSyncing = false;
  
  // Initialize with auto-sync
  static Future<void> initialize() async {
    await ApiService.initialize();
    _startPeriodicSync();
  }

  // Save progress with auto-sync
  static Future<void> saveProgress(
    String manhwaId, 
    int chapterNumber, 
    int pageIndex, 
    double scrollPosition,
  ) async {
    // Save locally first
    await SQLiteProgressService.saveProgress(manhwaId, chapterNumber, pageIndex, scrollPosition);
    
    // Queue for sync if logged in
    if (ApiService.isLoggedIn) {
      final update = ProgressUpdate(
        manhwaId: manhwaId,
        chapterNumber: chapterNumber,
        currentPage: pageIndex,
        scrollPosition: scrollPosition,
        isRead: false,
      );
      
      await ManhwaService.addPendingProgressUpdate(update);
      
      // Try immediate sync if not already syncing
      if (!_isSyncing) {
        _trySyncNow();
      }
    }
  }

  // Mark completed with sync
  static Future<void> markCompleted(String manhwaId, int chapterNumber) async {
    await SQLiteProgressService.markCompleted(manhwaId, chapterNumber);
    
    if (ApiService.isLoggedIn) {
      final update = ProgressUpdate(
        manhwaId: manhwaId,
        chapterNumber: chapterNumber,
        currentPage: 0, // Will be updated with actual page later
        scrollPosition: 0.0,
        isRead: true,
      );
      
      await ManhwaService.addPendingProgressUpdate(update);
      _trySyncNow();
    }
  }

  // Delegate other methods to SQLite service
  static Future<Map<String, dynamic>?> getProgress(String manhwaId, int chapterNumber) =>
      SQLiteProgressService.getProgress(manhwaId, chapterNumber);

  static Future<bool> isCompleted(String manhwaId, int chapterNumber) =>
      SQLiteProgressService.isCompleted(manhwaId, chapterNumber);

  static Future<Set<int>> getCompletedChapters(String manhwaId) =>
      SQLiteProgressService.getCompletedChapters(manhwaId);

  static Future<int?> getContinueChapter(String manhwaId, List<int> allChapterNumbers) =>
      SQLiteProgressService.getContinueChapter(manhwaId, allChapterNumbers);

  static Future<void> clearProgress(String manhwaId) =>
      SQLiteProgressService.clearProgress(manhwaId);

  // Sync management
  static void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (ApiService.isLoggedIn && !_isSyncing) {
        _trySyncNow();
      }
    });
  }

  static Future<void> _trySyncNow() async {
    if (_isSyncing || !ApiService.isLoggedIn) return;
    
    _isSyncing = true;
    
    try {
      final canConnect = await ApiService.checkConnection();
      if (!canConnect) return;
      
      final pendingUpdates = await ManhwaService.getPendingProgressUpdates();
      if (pendingUpdates.isNotEmpty) {
        final result = await ApiService.pushProgress(pendingUpdates);
        if (result.success) {
          await ManhwaService.clearPendingProgressUpdates();
          print('Synced ${pendingUpdates.length} progress updates');
        }
      }
    } catch (e) {
      print('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Full sync (called after login)
  static Future<bool> performFullSync() async {
    if (!ApiService.isLoggedIn || _isSyncing) return false;
    
    _isSyncing = true;
    
    try {
      print('Starting full sync...');
      
      // Pull data from server
      final pullResult = await ApiService.pullSync();
      if (!pullResult.success) {
        print('Failed to pull sync data: ${pullResult.error}');
        return false;
      }
      
      final syncData = pullResult.data!;
      
      // Merge progress data
      await _mergeProgressData(syncData.progress);
      
      // Push any pending updates
      final pendingUpdates = await ManhwaService.getPendingProgressUpdates();
      if (pendingUpdates.isNotEmpty) {
        final pushResult = await ApiService.pushProgress(pendingUpdates);
        if (pushResult.success) {
          await ManhwaService.clearPendingProgressUpdates();
        }
      }
      
      print('Full sync completed successfully');
      return true;
      
    } catch (e) {
      print('Full sync failed: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> _mergeProgressData(List<RemoteProgress> serverProgress) async {
    for (final remoteProgress in serverProgress) {
      // Get local progress
      final localProgress = await getProgress(
        remoteProgress.manhwaId, 
        remoteProgress.chapterNumber,
      );
      
      // Use server data if it's newer or local doesn't exist
      if (localProgress == null || 
          remoteProgress.updatedAt.isAfter(
            DateTime.tryParse(localProgress['lastRead'] ?? '') ?? DateTime(1970)
          )) {
        
        await SQLiteProgressService.saveProgress(
          remoteProgress.manhwaId,
          remoteProgress.chapterNumber,
          remoteProgress.currentPage,
          remoteProgress.scrollPosition,
        );
        
        if (remoteProgress.isRead) {
          await SQLiteProgressService.markCompleted(
            remoteProgress.manhwaId,
            remoteProgress.chapterNumber,
          );
        }
      }
    }
  }

  // Clean up
  static void dispose() {
    _syncTimer?.cancel();
  }
}