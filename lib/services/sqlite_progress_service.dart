import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../Data/manhwa_data.dart'; 

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
      version: 3, // Increment version to trigger onUpgrade
      onCreate: (db, version) async {
        // Create tables if they don't exist (for new installations)
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add progress columns to existing chapters table
          await _addProgressColumns(db);
        }
        if (oldVersion < 3) {
          // Add app_settings table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_settings (
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
        }
      },
    );
  }

  static Future<T> _executeWithRetry<T>(Future<T> Function() operation, {int maxRetries = 3}) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (e.toString().contains('database is locked') && attempts < maxRetries) {
          print('Database locked, retrying... (attempt $attempts/$maxRetries)');
          await Future.delayed(Duration(milliseconds: 100 * attempts)); // Exponential backoff
          continue;
        }
        rethrow; // If not a lock error or max retries reached
      }
    }
    
    throw Exception('Max retries exceeded');
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
        number REAL NOT NULL,
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

    // Create app_settings table for storing auth tokens and app preferences
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_chapter_downloaded ON chapters(manhwa_id, is_downloaded)');
    } catch (e) {
      print('Indexes may already exist: $e');
    }
  }

  // Save reading position for a chapter
  static Future<void> saveProgress(
    String manhwaId, 
    double chapterNumber, 
    int pageIndex, 
    double scrollPosition,
    {bool markAsRead = false}
  ) async {
    await _executeWithRetry(() async {
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
    });
    
    _updateCache(manhwaId, chapterNumber, {
      'pageIndex': pageIndex,
      'scrollPosition': scrollPosition,
      'lastRead': DateTime.now().toIso8601String(),
      'isRead': markAsRead,
    });
  }

  // Get reading position for a chapter
  static Future<Map<String, dynamic>?> getProgress(String manhwaId, double chapterNumber) async {
    // Clear cache to ensure fresh data
    _cache.remove(manhwaId);
    print('Cleared cache for manhwaId=$manhwaId');

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
        'pageIndex': (result['current_page'] as num).toInt(),
        'scrollPosition': (result['scroll_position'] as num).toDouble(),
        'lastRead': result['last_read_at'] as String?,
        'isRead': (result['is_read'] as int) == 1,
      };
      
      print('SQLiteProgressService.getProgress: Retrieved for manhwaId=$manhwaId, chapter=$chapterNumber: $progress');
      
      // Cache the result
      _updateCache(manhwaId, chapterNumber, progress);
      return progress;
    }
    
    print('SQLiteProgressService.getProgress: No progress found for manhwaId=$manhwaId, chapter=$chapterNumber');
    return null;
  }

  // Mark chapter as completed
  static Future<void> markCompleted(String manhwaId, double chapterNumber) async {
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

  // Unmark chapter as completed
  static Future<void> unmarkCompleted(String manhwaId, double chapterNumber) async {
    final db = await database;
    
    await db.update(
      'chapters',
      {
        'is_read': 0,
        'last_read_at': DateTime.now().toIso8601String(),
      },
      where: 'manhwa_id = ? AND number = ?',
      whereArgs: [manhwaId, chapterNumber],
    );

    // Invalidate cache for this manhwa
    _cache.remove(manhwaId);
  }

  // Mark chapter as downloaded
static Future<void> markDownloaded(String manhwaId, double chapterNumber) async {
  print('=== markDownloaded DEBUG ===');
  print('Marking manhwa_id: "$manhwaId", chapter: $chapterNumber as downloaded');
  
  final db = await database;
  
  // Check if the chapter exists first
  final existingChapter = await db.query(
    'chapters',
    where: 'manhwa_id = ? AND number = ?',
    whereArgs: [manhwaId, chapterNumber],
  );
  
  print('Existing chapter found: ${existingChapter.length}');
  if (existingChapter.isNotEmpty) {
    print('Chapter details: ${existingChapter.first}');
  }
  
  final updatedRows = await db.update(
    'chapters',
    {'is_downloaded': 1},
    where: 'manhwa_id = ? AND number = ?',
    whereArgs: [manhwaId, chapterNumber],
  );

  print('Updated rows: $updatedRows');
  
  // Verify the update
  final verifyUpdate = await db.query(
    'chapters',
    where: 'manhwa_id = ? AND number = ?',
    whereArgs: [manhwaId, chapterNumber],
  );
  
  if (verifyUpdate.isNotEmpty) {
    print('Verification - is_downloaded: ${verifyUpdate.first['is_downloaded']}');
  } else {
    print('ERROR: Chapter not found after update!');
  }
  
  // Invalidate cache for this manhwa
  _cache.remove(manhwaId);
  print('=== END markDownloaded DEBUG ===');
}

  // Unmark chapter as downloaded
  static Future<void> unmarkDownloaded(String manhwaId, double chapterNumber) async {
    final db = await database;
    
    await db.update(
      'chapters',
      {'is_downloaded': 0},
      where: 'manhwa_id = ? AND number = ?',
      whereArgs: [manhwaId, chapterNumber],
    );

    // Invalidate cache for this manhwa
    _cache.remove(manhwaId);
  }

  // Check if chapter is completed
  static Future<bool> isCompleted(String manhwaId, double chapterNumber) async {
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
  static Future<Set<double>> getCompletedChapters(String manhwaId) async {
    final db = await database;
    final results = await db.query(
      'chapters',
      columns: ['number'],
      where: 'manhwa_id = ? AND is_read = 1',
      whereArgs: [manhwaId],
    );

    return results.map((row) => (row['number'] as num).toDouble()).toSet();
  }

  // Get list of downloaded chapters for a manhwa
static Future<Set<double>> getDownloadedChapters(String manhwaId) async {
  print('=== getDownloadedChapters DEBUG ===');
  print('Querying for manhwaId: "$manhwaId"');
  
  final db = await database;
  
  // First, let's see what's actually in the database
  final allChapters = await db.query('chapters');
  print('Total chapters in database: ${allChapters.length}');
  
  // Show all manhwa_ids in database
  final allManhwaIds = await db.rawQuery('SELECT DISTINCT manhwa_id FROM chapters');
  print('All manhwa_ids in database: ${allManhwaIds.map((row) => row['manhwa_id']).toList()}');
  
  // Show downloaded chapters for all manhwas
  final allDownloaded = await db.query(
    'chapters',
    columns: ['manhwa_id', 'number', 'is_downloaded'],
    where: 'is_downloaded = 1',
  );
  print('All downloaded chapters: ${allDownloaded.length}');
  for (var row in allDownloaded) {
    print('- manhwa_id: "${row['manhwa_id']}", chapter: ${row['number']}, downloaded: ${row['is_downloaded']}');
  }
  
  // Now try the actual query
  final results = await db.query(
    'chapters',
    columns: ['number'],
    where: 'manhwa_id = ? AND is_downloaded = 1',
    whereArgs: [manhwaId],
  );
  
  print('Query results for manhwa_id "$manhwaId": ${results.length} chapters');
  for (var row in results) {
    print('- Chapter: ${row['number']}');
  }

  final downloadedChapters = results.map((row) => (row['number'] as num).toDouble()).toSet();
  print('Returning: $downloadedChapters');
  print('=== END getDownloadedChapters DEBUG ===');
  
  return downloadedChapters;
}


  // Get all downloaded chapters across all manhwa
  static Future<List<Map<String, dynamic>>> getAllDownloadedChapters() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT m.name as manhwaName, c.number as chapterNumber, c.manhwa_id as manhwaId
      FROM chapters c
      JOIN manhwas m ON c.manhwa_id = m.id
      WHERE c.is_downloaded = 1
      ORDER BY m.name ASC, c.number ASC
    ''');
    
    return results.map((row) => {
      'manhwaName': row['manhwaName'] as String,
      'chapterNumber': (row['chapterNumber'] as num).toDouble(), // Cast to double
      'manhwaId': row['manhwaId'] as String,
    }).toList();
  }

  // Find best chapter to continue from
  static Future<double?> getContinueChapter(String manhwaId, List<double> allChapterNumbers) async {
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
      final chapterNumber = (results.first['number'] as num).toDouble();
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
  static void _updateCache(String manhwaId, double chapterNumber, Map<String, dynamic> progress) {
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
    final completed = <double>[];

    for (final row in results) {
      final chapterNumber = (row['number'] as num).toDouble();
      
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

  // ===== APP SETTINGS METHODS =====
  
  // Save a setting (auth tokens, preferences, etc.)
  static Future<void> saveSetting(String key, String value) async {
    await _executeWithRetry(() async {
      final db = await database;
      await db.rawInsert(
        'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
        [key, value]
      );
    });
    print('Setting saved: $key');
  }

  // Get a setting by key
  static Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT value FROM app_settings WHERE key = ?',
      [key]
    );
    
    if (result.isNotEmpty) {
      final value = result.first['value'] as String?;
      print('Setting retrieved: $key = $value');
      return value;
    }
    
    print('Setting not found: $key');
    return null;
  }

  // Delete a setting by key
  static Future<void> deleteSetting(String key) async {
    await _executeWithRetry(() async {
      final db = await database;
      final deletedRows = await db.delete(
        'app_settings',
        where: 'key = ?',
        whereArgs: [key],
      );
      print('Setting deleted: $key ($deletedRows rows affected)');
    });
  }

  // Get all settings
  static Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final results = await db.query('app_settings');
    
    final settings = <String, String>{};
    for (final row in results) {
      settings[row['key'] as String] = row['value'] as String;
    }
    
    return settings;
  }

  // Check if a setting exists
  static Future<bool> hasSetting(String key) async {
    final value = await getSetting(key);
    return value != null;
  }

  // Clear all settings
  static Future<void> clearAllSettings() async {
    final db = await database;
    await db.delete('app_settings');
    print('All settings cleared');
  }

  // ===== UTILITY METHODS =====

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

  // Add all manhwa from manhwa_data.dart to database
  static Future<void> addDummyData() async {
    try {
      final db = await database;
      
      for (final entry in manhwaDatabase.entries) {
        final manhwa = entry.value;
        
        // Add manhwa
        await db.insert('manhwas', {
          'id': manhwa.id,
          'name': manhwa.name,
          'description': manhwa.description,
          'genres': manhwa.genres.join(','),
          'rating': manhwa.rating,
          'status': manhwa.status,
          'author': manhwa.author,
          'artist': manhwa.artist,
          'cover_image_url': manhwa.coverImageUrl ?? '',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        
        // Add chapters
        for (final chapter in manhwa.chapters) {
          await db.insert('chapters', {
            'manhwa_id': manhwa.id,
            'number': chapter.number,
            'title': chapter.title,
            'release_date': chapter.releaseDate.toIso8601String(),
            'images': chapter.images.join('|'),
            'is_read': 0, // Use 0 instead of false
            'is_downloaded': 0, // Use 0 instead of false
            'current_page': 0,
            'scroll_position': 0.0,
            'reading_time_seconds': 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      
      print('Added ${manhwaDatabase.length} manhwas to database');
      
    } catch (e) {
      print('Error adding dummy data: $e');
      rethrow;
    }
  }

  // Force recreate database (use once for fixing schema issues)
  static Future<void> forceRecreateDatabase() async {
    try {
      // Close existing connection
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      // Delete database file
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'manhwa_database.db');
      final file = File(path);
      
      if (await file.exists()) {
        await file.delete();
        print('Database file deleted successfully');
      }
      
      // Clear cache
      _cache.clear();
      
      // Reinitialize database (will create new one with proper schema)
      _database = await _initDatabase();
      print('Database recreated successfully');
      
    } catch (e) {
      print('Error recreating database: $e');
      rethrow;
    }
  }

  // Get database info for debugging
  static Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    
    final manhwaCount = await db.rawQuery('SELECT COUNT(*) as count FROM manhwas');
    final chapterCount = await db.rawQuery('SELECT COUNT(*) as count FROM chapters');
    final settingsCount = await db.rawQuery('SELECT COUNT(*) as count FROM app_settings');
    final progressCount = await getProgressCount();
    
    return {
      'manhwas': Sqflite.firstIntValue(manhwaCount) ?? 0,
      'chapters': Sqflite.firstIntValue(chapterCount) ?? 0,
      'settings': Sqflite.firstIntValue(settingsCount) ?? 0,
      'progress_records': progressCount,
      'database_version': 3,
    };
  }
}