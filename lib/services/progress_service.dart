import 'dart:async';
import 'sqlite_progress_service.dart';
import 'api_service.dart';
import 'manhwa_service.dart';

class ProgressService {
  static Timer? _periodicSyncTimer;
  static bool _isSyncing = false;
  static bool _hasPendingSync = false;
  
  // Initialize with reduced frequency periodic sync
  static Future<void> initialize() async {
    await ApiService.initialize();
    _startPeriodicSync();
  }

  // Save progress locally only - NO immediate sync
  static Future<void> saveProgress(
    String manhwaId, 
    double chapterNumber, 
    int pageIndex, 
    double scrollPosition,
  ) async {
    print('ProgressService.saveProgress: manhwaId=$manhwaId, chapter=$chapterNumber, page=$pageIndex, scrollPosition=$scrollPosition');

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
      _hasPendingSync = true;
      
      print('Progress saved locally and queued for sync (${manhwaId}_${chapterNumber}_${pageIndex}_$scrollPosition)');
    }
  }

  // Mark completed and queue for sync (but don't sync immediately unless requested)
  static Future<void> markCompleted(String manhwaId, double chapterNumber, {bool syncImmediately = false}) async {
    await SQLiteProgressService.markCompleted(manhwaId, chapterNumber);
    
    if (ApiService.isLoggedIn) {
      final update = ProgressUpdate(
        manhwaId: manhwaId,
        chapterNumber: chapterNumber,
        currentPage: 0,
        scrollPosition: 0.0,
        isRead: true,
      );
      
      await ManhwaService.addPendingProgressUpdate(update);
      _hasPendingSync = true;
      
      if (syncImmediately) {
        await syncNow();
      }
    }
  }

  // Unmark completed and queue for sync (but don't sync immediately unless requested)
  static Future<void> unmarkCompleted(String manhwaId, double chapterNumber, {bool syncImmediately = false}) async {
    await SQLiteProgressService.unmarkCompleted(manhwaId, chapterNumber);
    
    if (ApiService.isLoggedIn) {
      final update = ProgressUpdate(
        manhwaId: manhwaId,
        chapterNumber: chapterNumber,
        currentPage: 0,
        scrollPosition: 0.0,
        isRead: false,
      );
      
      await ManhwaService.addPendingProgressUpdate(update);
      _hasPendingSync = true;
      
      if (syncImmediately) {
        await syncNow();
      }
    }
  }

  // Explicit sync method - call this when exiting chapter/reader
  static Future<bool> syncNow({bool force = false}) async {
    if (!ApiService.isLoggedIn) {
      print('Not logged in, skipping sync');
      return false;
    }
    
    if (_isSyncing && !force) {
      print('Sync already in progress');
      return false;
    }
    
    if (!_hasPendingSync && !force) {
      print('No pending changes to sync');
      return true;
    }

    print('🔄 Starting explicit sync...');
    _isSyncing = true;
    
    try {
      // Check connection first (uses cache)
      final isOnline = await ApiService.checkConnection();
      if (!isOnline) {
        print('❌ No connection available for sync');
        return false;
      }
      
      final pendingUpdates = await ManhwaService.getPendingProgressUpdates();
      if (pendingUpdates.isEmpty) {
        print('✅ No pending updates to sync');
        _hasPendingSync = false;
        return true;
      }
      
      print('📤 Syncing ${pendingUpdates.length} progress updates...');
      final result = await ApiService.pushProgress(pendingUpdates);
      
      if (result.success) {
        await ManhwaService.clearPendingProgressUpdates();
        _hasPendingSync = false;
        print('✅ Sync completed successfully');
        return true;
      } else {
        print('❌ Sync failed: ${result.error}');
        return false;
      }
      
    } catch (e) {
      print('❌ Sync failed with exception: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  // Delegate other methods to SQLite service
  static Future<Map<String, dynamic>?> getProgress(String manhwaId, double chapterNumber) =>
      SQLiteProgressService.getProgress(manhwaId, chapterNumber);

  static Future<bool> isCompleted(String manhwaId, double chapterNumber) =>
      SQLiteProgressService.isCompleted(manhwaId, chapterNumber);

  static Future<Set<double>> getCompletedChapters(String manhwaId) =>
      SQLiteProgressService.getCompletedChapters(manhwaId);

  static Future<double?> getContinueChapter(String manhwaId, List<double> allChapterNumbers) =>
      SQLiteProgressService.getContinueChapter(manhwaId, allChapterNumbers);

  static Future<void> clearProgress(String manhwaId) =>
      SQLiteProgressService.clearProgress(manhwaId);

  // Reduced frequency periodic sync - only as fallback
  static void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    
    // Reduced frequency: every 30 minutes instead of 5
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (ApiService.isLoggedIn && !_isSyncing && _hasPendingSync) {
        print('⏰ Periodic sync triggered');
        syncNow();
      }
    });
  }

  // Full sync (called after login or when explicitly requested)
  static Future<bool> performFullSync() async {
    if (!ApiService.isLoggedIn) {
      print('Not logged in for full sync');
      return false;
    }
    
    if (_isSyncing) {
      print('Sync already in progress');
      return false;
    }

    _isSyncing = true;
    
    try {
      print('🔄 Starting full sync...');
      
      // Check connection with longer timeout for full sync
      final isOnline = await ApiService.forceCheckConnection();
      if (!isOnline) {
        print('❌ No connection available for full sync');
        return false;
      }
      
      // Pull data from server
      print('📥 Pulling data from server...');
      final pullResult = await ApiService.pullSync();
      if (!pullResult.success) {
        print('❌ Failed to pull sync data: ${pullResult.error}');
        return false;
      }
      
      final syncData = pullResult.data!;
      
      // Merge progress data
      print('🔄 Merging progress data...');
      await _mergeProgressData(syncData.progress);
      
      // Push any pending updates
      final pendingUpdates = await ManhwaService.getPendingProgressUpdates();
      if (pendingUpdates.isNotEmpty) {
        print('📤 Pushing ${pendingUpdates.length} pending updates...');
        final pushResult = await ApiService.pushProgress(pendingUpdates);
        if (pushResult.success) {
          await ManhwaService.clearPendingProgressUpdates();
          _hasPendingSync = false;
        }
      }
      
      print('✅ Full sync completed successfully');
      return true;
      
    } catch (e) {
      print('❌ Full sync failed: $e');
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
        } else {
          await SQLiteProgressService.unmarkCompleted(
            remoteProgress.manhwaId,
            remoteProgress.chapterNumber,
          );
        }
      }
    }
  }

  // Get sync status for UI
  static bool get isSyncing => _isSyncing;
  static bool get hasPendingSync => _hasPendingSync;
  
  static Future<Map<String, dynamic>> getSyncStatus() async {
    final pendingCount = (await ManhwaService.getPendingProgressUpdates()).length;
    final lastSync = await ManhwaService.getLastSyncTime();
    final connectionStatus = ApiService.cachedConnectionStatus;
    
    return {
      'isLoggedIn': ApiService.isLoggedIn,
      'isSyncing': _isSyncing,
      'pendingUpdates': pendingCount,
      'lastSync': lastSync?.toIso8601String(),
      'connectionStatus': connectionStatus,
      'hasPendingSync': _hasPendingSync,
    };
  }

  // Manual sync trigger (for UI buttons)
  static Future<bool> triggerManualSync() async {
    print('📱 Manual sync triggered by user');
    return await syncNow(force: true);
  }

  // Clean up
  static void dispose() {
    _periodicSyncTimer?.cancel();
  }
}