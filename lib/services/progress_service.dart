import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
class ProgressService {
  // Save reading position for a chapter
  static Future<void> saveProgress(String manhwaId, int chapterNumber, int pageIndex, double scrollPosition) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = {
      'pageIndex': pageIndex,
      'scrollPosition': scrollPosition,
      'lastRead': DateTime.now().toIso8601String(),
    };
    await prefs.setString('progress_${manhwaId}_$chapterNumber', jsonEncode(progress));
  }

  // Get reading position for a chapter
  static Future<Map<String, dynamic>?> getProgress(String manhwaId, int chapterNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final progressJson = prefs.getString('progress_${manhwaId}_$chapterNumber');
    if (progressJson != null) {
      return jsonDecode(progressJson);
    }
    return null;
  }

  // Mark chapter as completed
  static Future<void> markCompleted(String manhwaId, int chapterNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('completed_${manhwaId}_$chapterNumber', true);
  }

  // Check if chapter is completed
  static Future<bool> isCompleted(String manhwaId, int chapterNumber) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('completed_${manhwaId}_$chapterNumber') ?? false;
  }

  // Get list of completed chapters
  static Future<Set<int>> getCompletedChapters(String manhwaId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('completed_$manhwaId'));
    final completed = <int>{};
    
    for (final key in keys) {
      if (prefs.getBool(key) == true) {
        final chapterNumber = int.tryParse(key.split('_').last);
        if (chapterNumber != null) {
          completed.add(chapterNumber);
        }
      }
    }
    return completed;
  }

// Find best chapter to continue from - prioritize recent activity
static Future<int?> getContinueChapter(String manhwaId, List<int> allChapterNumbers) async {
  final completed = await getCompletedChapters(manhwaId);
  
  // Look for chapters with progress, prioritizing most recent
  Map<int, DateTime> chapterActivity = {};
  Map<int, double> chapterProgress = {};
  
  for (final chapterNumber in allChapterNumbers) {
    if (!completed.contains(chapterNumber)) {
      final progress = await getProgress(manhwaId, chapterNumber);
      if (progress != null && (progress['pageIndex'] > 0 || progress['scrollPosition'] > 0.1)) {
        chapterActivity[chapterNumber] = DateTime.parse(progress['lastRead']);
        chapterProgress[chapterNumber] = progress['pageIndex'].toDouble();
      }
    }
  }
  
  if (chapterActivity.isNotEmpty) {
    // Sort by last read time (most recent first)
    final sortedByTime = chapterActivity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Return the most recently read chapter with progress
    return sortedByTime.first.key;
  }
  
  // If no progress found, return first unread chapter
  for (final chapterNumber in allChapterNumbers) {
    if (!completed.contains(chapterNumber)) {
      return chapterNumber;
    }
  }
  
  return null; // All chapters completed
}

  // Clear all progress for a manhwa
  static Future<void> clearProgress(String manhwaId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => 
        key.startsWith('progress_$manhwaId') || key.startsWith('completed_$manhwaId'));
    
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}