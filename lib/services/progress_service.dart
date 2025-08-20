import 'sqlite_progress_service.dart';

class ProgressService {
  // Initialize the service (SQLite handles its own initialization)
  static Future<void> initialize() async {
    // SQLiteProgressService handles initialization internally
    // This method is kept for API compatibility
  }

  // Save reading position for a chapter
  static Future<void> saveProgress(String manhwaId, int chapterNumber, int pageIndex, double scrollPosition) async {
    await initialize();
    await SQLiteProgressService.saveProgress(manhwaId, chapterNumber, pageIndex, scrollPosition);
  }

  // Get reading position for a chapter
  static Future<Map<String, dynamic>?> getProgress(String manhwaId, int chapterNumber) async {
    await initialize();
    return await SQLiteProgressService.getProgress(manhwaId, chapterNumber);
  }

  // Mark chapter as completed
  static Future<void> markCompleted(String manhwaId, int chapterNumber) async {
    await initialize();
    await SQLiteProgressService.markCompleted(manhwaId, chapterNumber);
  }

  // Check if chapter is completed
  static Future<bool> isCompleted(String manhwaId, int chapterNumber) async {
    await initialize();
    return await SQLiteProgressService.isCompleted(manhwaId, chapterNumber);
  }

  // Get list of completed chapters
  static Future<Set<int>> getCompletedChapters(String manhwaId) async {
    await initialize();
    return await SQLiteProgressService.getCompletedChapters(manhwaId);
  }

  // Find best chapter to continue from - prioritize recent activity
  static Future<int?> getContinueChapter(String manhwaId, List<int> allChapterNumbers) async {
    await initialize();
    return await SQLiteProgressService.getContinueChapter(manhwaId, allChapterNumbers);
  }

  // Clear all progress for a manhwa
  static Future<void> clearProgress(String manhwaId) async {
    await initialize();
    await SQLiteProgressService.clearProgress(manhwaId);
  }

  // Get database statistics
  static Future<Map<String, dynamic>> getStats() async {
    await initialize();
    final count = await SQLiteProgressService.getProgressCount();
    return {
      'total_progress_entries': count,
    };
  }

  // Database maintenance
  static Future<void> vacuum() async {
    await initialize();
    await SQLiteProgressService.vacuum();
  }
}