// Updated SQLiteProgressService - Integrated with main database
import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class SQLiteProgressService {
  static Database? _database;
  static bool _factoryInitialized = false;
  static final Map<String, Map<String, dynamic>> _cache = {};

  // Initialize the correct database factory for the platform
  static void _initializeDatabaseFactory() {
    if (_factoryInitialized) return;
    
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _factoryInitialized = true;
  }

  // Use the same database as ManhwaService
  static Future<Database> get database async {
    _initializeDatabaseFactory();
    
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'manhwa_database.db'); // Same database as ManhwaService

    return await openDatabase(
      path,
      version: 2, // Increment version to trigger onUpgrade
      onCreate: (db, version) async {
        // Create tables if they don't exist (for new installations)
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add progress columns to existing chapters table
          await _addProgressColumns(db);
        }
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    // Create manhwas table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS manhwas (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        genres TEXT,
        rating REAL DEFAULT 0.0,
        status TEXT,
        author TEXT,
        artist TEXT,
        cover_image_url TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create chapters table with progress columns
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        manhwa_id TEXT NOT NULL,
        number INTEGER NOT NULL,
        title TEXT NOT NULL,
        release_date TEXT NOT NULL,
        is_read BOOLEAN DEFAULT FALSE,
        is_downloaded BOOLEAN DEFAULT FALSE,
        images TEXT,
        current_page INTEGER DEFAULT 0,
        scroll_position REAL DEFAULT 0.0,
        last_read_at TIMESTAMP,
        reading_time_seconds INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (manhwa_id) REFERENCES manhwas (id) ON DELETE CASCADE,
        UNIQUE(manhwa_id, number)
      )
    ''');

    await _createIndexes(db);
  }

  static Future<void> _addProgressColumns(Database db) async {
    try {
      await db.execute('ALTER TABLE chapters ADD COLUMN current_page INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE chapters ADD COLUMN scroll_position REAL DEFAULT 0.0');
      await db.execute('ALTER TABLE chapters ADD COLUMN last_read_at TIMESTAMP');
      await db.execute('ALTER TABLE chapters ADD COLUMN reading_time_seconds INTEGER DEFAULT 0');
      await _createIndexes(db);
      print('Progress columns added successfully');
    } catch (e) {
      print('Progress columns may already exist: $e');
    }
  }

  static Future<void> _createIndexes(Database db) async {
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_manhwa_chapters ON chapters(manhwa_id, number)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_chapter_read_status ON chapters(manhwa_id, is_read)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_last_read ON chapters(manhwa_id, last_read_at DESC)');
    } catch (e) {
      print('Indexes may already exist: $e');
    }
  }

  // Save reading position for a chapter
  static Future<void> saveProgress(
    String manhwaId, 
    int chapterNumber, 
    int pageIndex, 
    double scrollPosition,
    {bool markAsRead = false}
  ) async {
    final db = await database;
    
    final updateData = {
      'current_page': pageIndex,
      'scroll_position': scrollPosition,
      'last_read_at': DateTime.now().toIso8601String(),
    };
    
    if (markAsRead) {
      updateData['is_read'] = 1;
    }
    
    await db.update(
      'chapters',
      updateData,
      where: 'manhwa_id = ? AND number = ?',
      whereArgs: [manhwaId, chapterNumber],
    );

    // Update cache
    _updateCache(manhwaId, chapterNumber, {
      'pageIndex': pageIndex,
      'scrollPosition': scrollPosition,
      'lastRead': DateTime.now().toIso8601String(),
      'isRead': markAsRead,
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
      'chapters',
      columns: ['current_page', 'scroll_position', 'last_read_at', 'is_read'],
      where: 'manhwa_id = ? AND number = ?',
      whereArgs: [manhwaId, chapterNumber],
      limit: 1,
    );

    if (results.isNotEmpty) {
      final result = results.first;
      final progress = {
        'pageIndex': result['current_page'] as int,
        'scrollPosition': result['scroll_position'] as double,
        'lastRead': result['last_read_at'] as String?,
        'isRead': (result['is_read'] as int) == 1,
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
    
    await db.update(
      'chapters',
      {
        'is_read': 1,
        'last_read_at': DateTime.now().toIso8601String(),
      },
      where: 'manhwa_id = ? AND number = ?',
      whereArgs: [manhwaId, chapterNumber],
    );

    // Invalidate cache for this manhwa
    _cache.remove(manhwaId);
  }

  // Check if chapter is completed
  static Future<bool> isCompleted(String manhwaId, int chapterNumber) async {
    final db = await database;
    final results = await db.query(
      'chapters',
      columns: ['is_read'],
      where: 'manhwa_id = ? AND number = ? AND is_read = 1',
      whereArgs: [manhwaId, chapterNumber],
      limit: 1,
    );

    return results.isNotEmpty;
  }

  // Get list of completed chapters
  static Future<Set<int>> getCompletedChapters(String manhwaId) async {
    final db = await database;
    final results = await db.query(
      'chapters',
      columns: ['number'],
      where: 'manhwa_id = ? AND is_read = 1',
      whereArgs: [manhwaId],
    );

    return results.map((row) => row['number'] as int).toSet();
  }

  // Find best chapter to continue from
  static Future<int?> getContinueChapter(String manhwaId, List<int> allChapterNumbers) async {
    final db = await database;
    
    // Look for chapters with progress that aren't completed, ordered by most recent
    final results = await db.query(
      'chapters',
      columns: ['number'],
      where: 'manhwa_id = ? AND is_read = 0 AND (current_page > 0 OR scroll_position > 0.1)',
      whereArgs: [manhwaId],
      orderBy: 'last_read_at DESC',
      limit: 1,
    );

    if (results.isNotEmpty) {
      final chapterNumber = results.first['number'] as int;
      if (allChapterNumbers.contains(chapterNumber)) {
        return chapterNumber;
      }
    }
    
    // If no progress found, return first unread chapter
    final completed = await getCompletedChapters(manhwaId);
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
    await db.update(
      'chapters',
      {
        'is_read': 0,
        'current_page': 0,
        'scroll_position': 0.0,
        'last_read_at': null,
      },
      where: 'manhwa_id = ?',
      whereArgs: [manhwaId],
    );

    // Clear cache for this manhwa
    _cache.remove(manhwaId);
  }

  // Get reading statistics
  static Future<Map<String, dynamic>> getReadingStats(String manhwaId) async {
    final db = await database;
    
    final totalChapters = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chapters WHERE manhwa_id = ?',
      [manhwaId],
    );
    
    final readChapters = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chapters WHERE manhwa_id = ? AND is_read = 1',
      [manhwaId],
    );
    
    final chaptersWithProgress = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chapters WHERE manhwa_id = ? AND (current_page > 0 OR scroll_position > 0.1)',
      [manhwaId],
    );
    
    final total = Sqflite.firstIntValue(totalChapters) ?? 0;
    final read = Sqflite.firstIntValue(readChapters) ?? 0;
    final inProgress = Sqflite.firstIntValue(chaptersWithProgress) ?? 0;
    
    return {
      'total_chapters': total,
      'read_chapters': read,
      'chapters_in_progress': inProgress,
      'completion_percentage': total > 0 ? (read / total * 100).round() : 0,
    };
  }

  // Cache management
  static void _updateCache(String manhwaId, int chapterNumber, Map<String, dynamic> progress) {
    if (!_cache.containsKey(manhwaId)) {
      _cache[manhwaId] = {};
    }
    final cacheKey = '${manhwaId}_$chapterNumber';
    _cache[manhwaId]![cacheKey] = progress;
  }

  // Get all progress for a manhwa
  static Future<Map<String, dynamic>> getManhwaProgress(String manhwaId) async {
    final db = await database;
    final results = await db.query(
      'chapters',
      where: 'manhwa_id = ?',
      whereArgs: [manhwaId],
      orderBy: 'number ASC',
    );

    final progress = <String, dynamic>{};
    final completed = <int>[];

    for (final row in results) {
      final chapterNumber = row['number'] as int;
      
      if ((row['is_read'] as int) == 1) {
        completed.add(chapterNumber);
      }
      
      if ((row['current_page'] as int) > 0 || (row['scroll_position'] as double) > 0.0) {
        final cacheKey = '${manhwaId}_$chapterNumber';
        progress[cacheKey] = {
          'pageIndex': row['current_page'],
          'scrollPosition': row['scroll_position'],
          'lastRead': row['last_read_at'],
          'isRead': (row['is_read'] as int) == 1,
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

  // Migration helper: Migrate from separate progress database
  static Future<void> migrateFromSeparateDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final oldProgressPath = join(dbPath, 'manhwa_progress.db');
      final oldProgressFile = File(oldProgressPath);
      
      if (!await oldProgressFile.exists()) {
        print('No old progress database found, skipping migration');
        return;
      }

      final oldDb = await openDatabase(oldProgressPath);
      final progressData = await oldDb.query('progress');
      
      print('Migrating ${progressData.length} progress records...');
      
      final newDb = await database;
      int migratedCount = 0;
      
      for (final row in progressData) {
        try {
          await newDb.update(
            'chapters',
            {
              'current_page': row['page_index'],
              'scroll_position': row['scroll_position'],
              'is_read': row['is_completed'],
              'last_read_at': row['last_read'],
            },
            where: 'manhwa_id = ? AND number = ?',
            whereArgs: [row['manhwa_id'], row['chapter_number']],
          );
          migratedCount++;
        } catch (e) {
          print('Failed to migrate progress for ${row['manhwa_id']} chapter ${row['chapter_number']}: $e');
        }
      }
      
      await oldDb.close();
      print('Migration complete: $migratedCount records migrated');
      
      // Optionally delete old database
      // await oldProgressFile.delete();
      
    } catch (e) {
      print('Migration failed: $e');
    }
  }

  // Close database
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _cache.clear();
  }

  // Database maintenance
  static Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  static Future<int> getProgressCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chapters WHERE current_page > 0 OR scroll_position > 0.0 OR is_read = 1'
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}