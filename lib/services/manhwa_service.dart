import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/manwha.dart';
import '../models/chapter.dart';
import 'api_service.dart';
import 'sqlite_progress_service.dart';
class ManhwaService {
  static Database? _database;
  static bool _initialized = false;
  static bool _factoryInitialized = false;
  static final Map<String, Manhwa> _cache = {};

  // Initialize the correct database factory for the platform
  static void _initializeDatabaseFactory() {
    if (_factoryInitialized) return;
    
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      print('Initialized FFI database factory for desktop platform');
    }
    _factoryInitialized = true;
  }

  // Initialize database
  static Future<Database> get database async {
    _initializeDatabaseFactory();
    
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'manhwa_database.db');
    
    print('Database path: $path');

    return await openDatabase(
      path,
      version: 2, // Increment version to add progress columns
      onCreate: (db, version) async {
        print('Creating database tables...');
        await _createTables(db);
        print('Database tables created successfully!');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          print('Upgrading database to add progress columns...');
          await _addProgressColumns(db);
          print('Database upgrade completed!');
        }
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE manhwas (
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

    await db.execute('''
      CREATE TABLE chapters (
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

    // Add app settings table for auth and sync
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Add pending sync table
    await db.execute('''
      CREATE TABLE pending_sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
      
      // Create new tables if they don't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_sync (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          data TEXT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await _createIndexes(db);
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

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initializeDatabaseFactory();
    _initialized = true;
  }

  // Helper methods for JSON encoding/decoding
  static String _encodeStringList(List<String> list) {
    return list.join('|');
  }

  static List<String> _decodeStringList(String? encoded) {
    if (encoded == null || encoded.isEmpty) return [];
    return encoded.split('|').where((s) => s.isNotEmpty).toList();
  }

  // Save a manhwa to database
  static Future<void> _saveManhwa(Manhwa manhwa) async {
    final db = await database;
    
    await db.insert(
      'manhwas',
      {
        'id': manhwa.id,
        'name': manhwa.name,
        'description': manhwa.description,
        'genres': _encodeStringList(manhwa.genres),
        'rating': manhwa.rating,
        'status': manhwa.status,
        'author': manhwa.author,
        'artist': manhwa.artist,
        'cover_image_url': manhwa.coverImageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    for (final chapter in manhwa.chapters) {
      await _saveChapter(manhwa.id, chapter);
    }

    _cache[manhwa.id] = manhwa;
  }

  static Future<void> _saveChapter(String manhwaId, Chapter chapter) async {
    final db = await database;
    
    await db.insert(
      'chapters',
      {
        'manhwa_id': manhwaId,
        'number': chapter.number,
        'title': chapter.title,
        'release_date': chapter.releaseDate.toIso8601String(),
        'is_read': chapter.isRead ? 1 : 0,
        'is_downloaded': chapter.isDownloaded ? 1 : 0,
        'images': _encodeStringList(chapter.images),
        'current_page': 0, // Initialize progress fields
        'scroll_position': 0.0,
        'last_read_at': null,
        'reading_time_seconds': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // NEW: Save reading progress
  static Future<void> saveProgress(
    String manhwaId, 
    int chapterNumber, 
    int pageIndex, 
    double scrollPosition,
    {bool markAsRead = false}
  ) async {
    await _ensureInitialized();
    
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

    // Invalidate cache for this manhwa
    _cache.remove(manhwaId);
  }

  // NEW: Get reading progress for a chapter
  static Future<Map<String, dynamic>?> getProgress(String manhwaId, int chapterNumber) async {
    await _ensureInitialized();

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
      return {
        'pageIndex': result['current_page'] as int,
        'scrollPosition': result['scroll_position'] as double,
        'lastRead': result['last_read_at'] as String?,
        'isRead': (result['is_read'] as int) == 1,
      };
    }
    
    return null;
  }

  // NEW: Mark chapter as completed
  static Future<void> markChapterCompleted(String manhwaId, int chapterNumber) async {
    await _ensureInitialized();
    
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

  // NEW: Get completed chapters
  static Future<Set<int>> getCompletedChapters(String manhwaId) async {
    await _ensureInitialized();
    
    final db = await database;
    final results = await db.query(
      'chapters',
      columns: ['number'],
      where: 'manhwa_id = ? AND is_read = 1',
      whereArgs: [manhwaId],
    );

    return results.map((row) => row['number'] as int).toSet();
  }

  // NEW: Find best chapter to continue reading
  static Future<num?> getContinueChapter(String manhwaId, List<int> allChapterNumbers) async {
    await _ensureInitialized();
    
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
      final row = results.first;
      final chapterNumber = (row['number'] as num).toDouble();
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

  // NEW: Clear all progress for a manhwa
  static Future<void> clearProgress(String manhwaId) async {
    await _ensureInitialized();
    
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

    // Invalidate cache for this manhwa
    _cache.remove(manhwaId);
  }

  // Auth data storage methods
  static Future<void> saveAuthData(String token, String userData) async {
    await _ensureInitialized();
    
    final db = await database;
    
    await db.insert(
      'app_settings',
      {'key': 'auth_token', 'value': token},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    await db.insert(
      'app_settings',
      {'key': 'user_data', 'value': userData},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, String>?> getAuthData() async {
    await _ensureInitialized();
    
    final db = await database;
    
    final tokenResult = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['auth_token'],
      limit: 1,
    );
    
    final userResult = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['user_data'],
      limit: 1,
    );
    
    if (tokenResult.isNotEmpty && userResult.isNotEmpty) {
      return {
        'token': tokenResult.first['value'] as String,
        'user_data': userResult.first['value'] as String,
      };
    }
    
    return null;
  }

  static Future<void> clearAuthData() async {
    await _ensureInitialized();
    
    final db = await database;
    await db.delete(
      'app_settings',
      where: 'key IN (?, ?)',
      whereArgs: ['auth_token', 'user_data'],
    );
  }

  // Sync state management
static Future<void> setLastSyncTime(DateTime time) async {
  // Use the retry-protected method instead of direct database access
  await SQLiteProgressService.saveSetting('last_sync', time.toIso8601String());
}

  static Future<DateTime?> getLastSyncTime() async {
    await _ensureInitialized();
    
    final db = await database;
    final result = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['last_sync'],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      return DateTime.tryParse(result.first['value'] as String);
    }
    
    return null;
  }

  // Pending sync operations
  static Future<void> addPendingProgressUpdate(ProgressUpdate update) async {
    await _ensureInitialized();
    
    final db = await database;
    
    // Remove existing update for same chapter
    final existingUpdates = await db.query(
      'pending_sync',
      where: 'type = ?',
      whereArgs: ['progress'],
    );

    for (final row in existingUpdates) {
      final data = jsonDecode(row['data'] as String);
      if (data['manhwaId'] == update.manhwaId && data['chapterNumber'] == update.chapterNumber) {
        await db.delete(
          'pending_sync',
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
    
    // Add new update
    await db.insert(
      'pending_sync',
      {
        'type': 'progress',
        'data': jsonEncode(update.toJson()),
      },
    );
  }

  static Future<List<ProgressUpdate>> getPendingProgressUpdates() async {
    await _ensureInitialized();
    
    final db = await database;
    
    final results = await db.query(
      'pending_sync',
      where: 'type = ?',
      whereArgs: ['progress'],
    );
    
    return results.map((row) {
      final data = jsonDecode(row['data'] as String);
      return ProgressUpdate(
        manhwaId: data['manhwaId'],
        chapterNumber: data['chapterNumber'],
        currentPage: data['currentPage'],
        scrollPosition: data['scrollPosition'].toDouble(),
        isRead: data['isRead'],
      );
    }).toList();
  }

  static Future<void> clearPendingProgressUpdates() async {
    await _ensureInitialized();
    
    final db = await database;
    await db.delete(
      'pending_sync',
      where: 'type = ?',
      whereArgs: ['progress'],
    );
  }

  // Get all manhwas from library
  static Future<List<Manhwa>> getAllManhwa() async {
    await _ensureInitialized();
    
    final db = await database;
    final manhwaResults = await db.query('manhwas', orderBy: 'name ASC');
    final List<Manhwa> manhwas = [];

    for (final manhwaData in manhwaResults) {
      final id = manhwaData['id'] as String;
      
      if (_cache.containsKey(id)) {
        manhwas.add(_cache[id]!);
        continue;
      }

      final chapterResults = await db.query(
        'chapters',
        where: 'manhwa_id = ?',
        whereArgs: [id],
        orderBy: 'number ASC',
      );

      final chapters = chapterResults.map((row) => Chapter(
        number: (row['number'] as num).toDouble(),
        title: row['title'] as String,
        releaseDate: DateTime.parse(row['release_date'] as String),
        isRead: (row['is_read'] as int) == 1,
        isDownloaded: (row['is_downloaded'] as int) == 1,
        images: _decodeStringList(row['images'] as String?),
      )).toList();

      final manhwa = Manhwa(
        id: id,
        name: manhwaData['name'] as String,
        description: manhwaData['description'] as String? ?? '',
        genres: _decodeStringList(manhwaData['genres'] as String?),
        rating: (manhwaData['rating'] as num?)?.toDouble() ?? 0.0,
        status: manhwaData['status'] as String? ?? 'Unknown',
        author: manhwaData['author'] as String? ?? 'Unknown',
        artist: manhwaData['artist'] as String? ?? 'Unknown',
        coverImageUrl: manhwaData['cover_image_url'] as String?,
        chapters: chapters,
      );

      _cache[id] = manhwa;
      manhwas.add(manhwa);
    }

    return manhwas;
  }

  static Future<List<String>> getManhwaKeys() async {
    await _ensureInitialized();
    final db = await database;
    final results = await db.query('manhwas', columns: ['id']);
    return results.map((row) => row['id'] as String).toList();
  }

  static Future<Manhwa?> getManhwaById(String id) async {
    await _ensureInitialized();
    
    if (_cache.containsKey(id)) {
      return _cache[id];
    }

    final db = await database;
    
    final manhwaResults = await db.query(
      'manhwas',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (manhwaResults.isEmpty) return null;

    final manhwaData = manhwaResults.first;

    final chapterResults = await db.query(
      'chapters',
      where: 'manhwa_id = ?',
      whereArgs: [id],
      orderBy: 'number ASC',
    );

    final chapters = chapterResults.map((row) => Chapter(
      number: row['number'] as double,
      title: row['title'] as String,
      releaseDate: DateTime.parse(row['release_date'] as String),
      isRead: (row['is_read'] as int) == 1,
      isDownloaded: (row['is_downloaded'] as int) == 1,
      images: _decodeStringList(row['images'] as String?),
    )).toList();

    final manhwa = Manhwa(
      id: manhwaData['id'] as String,
      name: manhwaData['name'] as String,
      description: manhwaData['description'] as String? ?? '',
      genres: _decodeStringList(manhwaData['genres'] as String?),
      rating: (manhwaData['rating'] as num?)?.toDouble() ?? 0.0,
      status: manhwaData['status'] as String? ?? 'Unknown',
      author: manhwaData['author'] as String? ?? 'Unknown',
      artist: manhwaData['artist'] as String? ?? 'Unknown',
      coverImageUrl: manhwaData['cover_image_url'] as String?,
      chapters: chapters,
    );

    _cache[id] = manhwa;
    return manhwa;
  }

  static Future<List<Chapter>> getChapters(String manhwaId) async {
    final manhwa = await getManhwaById(manhwaId);
    return manhwa?.chapters ?? [];
  }

  static Future<void> addToLibrary(Manhwa manhwa) async {
    await _ensureInitialized();
    await _saveManhwa(manhwa);
  }

  static Future<void> removeFromLibrary(String manhwaId) async {
    await _ensureInitialized();
    
    final db = await database;
    await db.delete('manhwas', where: 'id = ?', whereArgs: [manhwaId]);
    _cache.remove(manhwaId);
  }

  static Future<void> deleteManhwa(String manhwaId) async {
    await removeFromLibrary(manhwaId);
  }

  static Future<void> updateChapterReadStatus(String manhwaId, int chapterNumber, bool isRead) async {
    await _ensureInitialized();
    
    final db = await database;
    await db.update(
      'chapters',
      {
        'is_read': isRead ? 1 : 0,
        'last_read_at': isRead ? DateTime.now().toIso8601String() : null,
      },
      where: 'manhwa_id = ? AND number = ?',
      whereArgs: [manhwaId, chapterNumber],
    );

    if (_cache.containsKey(manhwaId)) {
      final manhwa = _cache[manhwaId]!;
      final updatedChapters = manhwa.chapters.map((chapter) {
        if (chapter.number == chapterNumber) {
          return chapter.copyWith(isRead: isRead);
        }
        return chapter;
      }).toList();
      
      _cache[manhwaId] = manhwa.copyWith(chapters: updatedChapters);
    }
  }

  static Future<List<Manhwa>> searchManhwas(String query) async {
    await _ensureInitialized();
    
    final db = await database;
    final results = await db.query(
      'manhwas',
      where: 'name LIKE ? OR description LIKE ? OR author LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );

    final List<Manhwa> manhwas = [];
    
    for (final manhwaData in results) {
      final manhwa = await getManhwaById(manhwaData['id'] as String);
      if (manhwa != null) manhwas.add(manhwa);
    }

    return manhwas;
  }

  static Future<Map<String, dynamic>> getStats() async {
    await _ensureInitialized();
    
    final db = await database;
    
    final manhwaCount = await db.rawQuery('SELECT COUNT(*) as count FROM manhwas');
    final chapterCount = await db.rawQuery('SELECT COUNT(*) as count FROM chapters');
    final readChapterCount = await db.rawQuery('SELECT COUNT(*) as count FROM chapters WHERE is_read = 1');
    
    return {
      'total_manhwas': Sqflite.firstIntValue(manhwaCount) ?? 0,
      'total_chapters': Sqflite.firstIntValue(chapterCount) ?? 0,
      'read_chapters': Sqflite.firstIntValue(readChapterCount) ?? 0,
    };
  }

  static Future<void> vacuum() async {
    await _ensureInitialized();
    final db = await database;
    await db.execute('VACUUM');
  }

  static Future<void> clearAllData() async {
    await _ensureInitialized();
    
    final db = await database;
    await db.delete('manhwas');
    _cache.clear();
  }

  static Future<Map<String, dynamic>> exportData() async {
    await _ensureInitialized();
    
    final manhwas = await getAllManhwa();
    final export = <String, dynamic>{};
    
    for (final manhwa in manhwas) {
      export[manhwa.id] = {
        'name': manhwa.name,
        'description': manhwa.description,
        'genres': manhwa.genres,
        'rating': manhwa.rating,
        'status': manhwa.status,
        'author': manhwa.author,
        'artist': manhwa.artist,
        'coverImageUrl': manhwa.coverImageUrl,
        'chapters': manhwa.chapters.map((c) => {
          'number': c.number,
          'title': c.title,
          'releaseDate': c.releaseDate.toIso8601String(),
          'isRead': c.isRead,
          'isDownloaded': c.isDownloaded,
          'images': c.images,
        }).toList(),
      };
    }
    
    return {
      'export_date': DateTime.now().toIso8601String(),
      'total_manhwas': manhwas.length,
      'data': export,
    };
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _cache.clear();
    _initialized = false;
    _factoryInitialized = false;
  }
  // Add these methods to your existing ManhwaService class

  // Server IP Management methods
  static Future<void> saveCustomServerIP(String serverIP) async {
    await _ensureInitialized();
    
    final db = await database;
    await db.insert(
      'app_settings',
      {
        'key': 'custom_server_ip',
        'value': serverIP,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getCustomServerIP() async {
    await _ensureInitialized();
    
    final db = await database;
    final result = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['custom_server_ip'],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      return result.first['value'] as String?;
    }
    
    return null;
  }

  static Future<void> removeCustomServerIP() async {
    await _ensureInitialized();
    
    final db = await database;
    await db.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['custom_server_ip'],
    );
  }

  // Optional: Get all app settings for debugging
  static Future<Map<String, String>> getAllSettings() async {
    await _ensureInitialized();
    
    final db = await database;
    final result = await db.query('app_settings');
    final settings = <String, String>{};
    
    for (final row in result) {
      settings[row['key'] as String] = row['value'] as String;
    }
    
    return settings;
  }

  // Enhanced method to get database info including progress records
  static Future<Map<String, int>> getDatabaseInfo() async {
    await _ensureInitialized();
    
    final db = await database;
    
    final manhwaCount = await db.rawQuery('SELECT COUNT(*) as count FROM manhwas');
    final chapterCount = await db.rawQuery('SELECT COUNT(*) as count FROM chapters');
    final readChapterCount = await db.rawQuery('SELECT COUNT(*) as count FROM chapters WHERE is_read = 1');
    final progressRecords = await db.rawQuery('SELECT COUNT(*) as count FROM chapters WHERE current_page > 0 OR scroll_position > 0');
    final settingsCount = await db.rawQuery('SELECT COUNT(*) as count FROM app_settings');
    
    return {
      'total_manhwas': Sqflite.firstIntValue(manhwaCount) ?? 0,
      'total_chapters': Sqflite.firstIntValue(chapterCount) ?? 0,
      'read_chapters': Sqflite.firstIntValue(readChapterCount) ?? 0,
      'progress_records': Sqflite.firstIntValue(progressRecords) ?? 0,
      'app_settings': Sqflite.firstIntValue(settingsCount) ?? 0,
    };
  }

  // Clear all app settings (useful for troubleshooting)
  static Future<void> clearAllSettings() async {
    await _ensureInitialized();
    
    final db = await database;
    await db.delete('app_settings');
    await db.delete('pending_sync');
  }
}
