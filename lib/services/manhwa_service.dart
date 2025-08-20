import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/manwha.dart';
import '../models/chapter.dart';

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
      version: 1,
      onCreate: (db, version) async {
        print('Creating database tables...');
        
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
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (manhwa_id) REFERENCES manhwas (id) ON DELETE CASCADE,
            UNIQUE(manhwa_id, number)
          )
        ''');

        await db.execute('CREATE INDEX idx_manhwa_chapters ON chapters(manhwa_id, number)');
        await db.execute('CREATE INDEX idx_chapter_read_status ON chapters(manhwa_id, is_read)');
        
        print('Database tables created successfully!');
      },
    );
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
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
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
        number: row['number'] as int,
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
      number: row['number'] as int,
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
      {'is_read': isRead ? 1 : 0},
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
}