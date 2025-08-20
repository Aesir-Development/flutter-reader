
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SQLiteProgressService {
  static Database? _database;
  static final Map<String, Map<String, dynamic>> _cache = {};

  // Initialize database
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'manhwa_progress.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            manhwa_id TEXT NOT NULL,
            chapter_number INTEGER NOT NULL,
            page_index INTEGER DEFAULT 0,
            scroll_position REAL DEFAULT 0.0,
            is_completed BOOLEAN DEFAULT FALSE,
            last_read TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(manhwa_id, chapter_number)
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_manhwa_progress ON progress(manhwa_id, last_read DESC)
        ''');

        await db.execute('''
          CREATE INDEX idx_completed ON progress(manhwa_id, is_completed)
        ''');
      },
    );
  }

  // Save reading position for a chapter
  static Future<void> saveProgress(
    String manhwaId, 
    int chapterNumber, 
    int pageIndex, 
    double scrollPosition
  ) async {
    final db = await database;
    
    await db.insert(
      'progress',
      {
        'manhwa_id': manhwaId,
        'chapter_number': chapterNumber,
        'page_index': pageIndex,
        'scroll_position': scrollPosition,
        'last_read': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update cache
    _updateCache(manhwaId, chapterNumber, {
      'pageIndex': pageIndex,
      'scrollPosition': scrollPosition,
      'lastRead': DateTime.now().toIso8601String(),
    });
  }

  // Get reading position for a chapter
  static Future<Map<String, dynamic>?> getProgress(String manhwaId, int chapterNumber) async {
    // Check cache first
    final cacheKey = '${manhwaId}_$chapterNumber';
    if (_cache.containsKey(manhwaId) && _cache[manhwaId]!.containsKey(cacheKey)) {
      return _cache[manhwaId]![cacheKey];
    }

    final db = await database;
    final results = await db.query(
      'progress',
      where: 'manhwa_id = ? AND chapter_number = ?',
      whereArgs: [manhwaId, chapterNumber],
      limit: 1,
    );

    if (results.isNotEmpty) {
      final result = results.first;
      final progress = {
        'pageIndex': result['page_index'] as int,
        'scrollPosition': result['scroll_position'] as double,
        'lastRead': result['last_read'] as String,
      };
      
      // Cache the result
      _updateCache(manhwaId, chapterNumber, progress);
      return progress;
    }
    
    return null;
  }

  // Mark chapter as completed
  static Future<void> markCompleted(String manhwaId, int chapterNumber) async {
    final db = await database;
    
    await db.insert(
      'progress',
      {
        'manhwa_id': manhwaId,
        'chapter_number': chapterNumber,
        'is_completed': true,
        'last_read': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Invalidate cache for this manhwa
    _cache.remove(manhwaId);
  }

  // Check if chapter is completed
  static Future<bool> isCompleted(String manhwaId, int chapterNumber) async {
    final db = await database;
    final results = await db.query(
      'progress',
      columns: ['is_completed'],
      where: 'manhwa_id = ? AND chapter_number = ? AND is_completed = 1',
      whereArgs: [manhwaId, chapterNumber],
      limit: 1,
    );

    return results.isNotEmpty;
  }

  // Get list of completed chapters (returns Set<int> for compatibility)
  static Future<Set<int>> getCompletedChapters(String manhwaId) async {
    final db = await database;
    final results = await db.query(
      'progress',
      columns: ['chapter_number'],
      where: 'manhwa_id = ? AND is_completed = 1',
      whereArgs: [manhwaId],
    );

    return results.map((row) => row['chapter_number'] as int).toSet();
  }

  // Find best chapter to continue from - prioritize recent activity
  static Future<int?> getContinueChapter(String manhwaId, List<int> allChapterNumbers) async {
    final completed = await getCompletedChapters(manhwaId);
    
    final db = await database;
    
    // Look for chapters with progress that aren't completed, ordered by most recent
    final results = await db.query(
      'progress',
      where: 'manhwa_id = ? AND is_completed = 0 AND (page_index > 0 OR scroll_position > 0.1)',
      whereArgs: [manhwaId],
      orderBy: 'last_read DESC',
      limit: 1,
    );

    if (results.isNotEmpty) {
      final chapterNumber = results.first['chapter_number'] as int;
      if (allChapterNumbers.contains(chapterNumber)) {
        return chapterNumber;
      }
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
    final db = await database;
    await db.delete(
      'progress',
      where: 'manhwa_id = ?',
      whereArgs: [manhwaId],
    );

    // Clear cache for this manhwa
    _cache.remove(manhwaId);
  }

  // Cache management
  static void _updateCache(String manhwaId, int chapterNumber, Map<String, dynamic> progress) {
    if (!_cache.containsKey(manhwaId)) {
      _cache[manhwaId] = {};
    }
    final cacheKey = '${manhwaId}_$chapterNumber';
    _cache[manhwaId]![cacheKey] = progress;
  }

  // Get all progress for a manhwa (useful for sync)
  static Future<Map<String, dynamic>> getManhwaProgress(String manhwaId) async {
    // Check cache first
    if (_cache.containsKey(manhwaId)) {
      return {'cached': true, 'progress': _cache[manhwaId]!};
    }

    final db = await database;
    final results = await db.query(
      'progress',
      where: 'manhwa_id = ?',
      whereArgs: [manhwaId],
      orderBy: 'chapter_number ASC',
    );

    final progress = <String, dynamic>{};
    final completed = <int>[];

    for (final row in results) {
      final chapterNumber = row['chapter_number'] as int;
      
      if (row['is_completed'] == 1) {
        completed.add(chapterNumber);
      }
      
      if (row['page_index'] != 0 || row['scroll_position'] != 0.0) {
        final cacheKey = '${manhwaId}_$chapterNumber';
        progress[cacheKey] = {
          'pageIndex': row['page_index'],
          'scrollPosition': row['scroll_position'],
          'lastRead': row['last_read'],
        };
      }
    }

    // Cache the results
    _cache[manhwaId] = progress;
    
    return {
      'progress': progress,
      'completed': completed,
    };
  }

  // Close database (call when app is disposed)
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _cache.clear();
  }

  // Database maintenance methods
  static Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  static Future<int> getProgressCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM progress');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Migration helper: Import from SharedPreferences (call once during migration)
  static Future<void> migrateFromSharedPreferences() async {
    // This method would help migrate existing SharedPreferences data
    // Implementation depends on your current SharedPreferences structure
    print('Migration from SharedPreferences would be implemented here');
  }
}