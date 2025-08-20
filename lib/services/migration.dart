import 'manhwa_service.dart';
import '../Data/manhwa_data.dart';

class PureSQLiteMigration {
  // Check if SQLite database has any data
  static Future<bool> isDatabasePopulated() async {
    try {
      final stats = await ManhwaService.getStats();
      return (stats['total_manhwas'] ?? 0) > 0;
    } catch (e) {
      return false;
    }
  }

  // Run migration if database is empty
  static Future<void> runMigrationIfNeeded() async {
    try {
      final isPopulated = await isDatabasePopulated();
      
      if (isPopulated) {
        print('SQLite database already has data, skipping migration');
        return;
      }

      print('SQLite database is empty, starting migration...');
      await _migrateAllData();
      
    } catch (e) {
      print('Migration check failed: $e');
      // Try migration anyway as a fallback
      await _migrateAllData();
    }
  }

  static Future<void> _migrateAllData() async {
    try {
      print('Migrating ${manhwaDatabase.length} manhwas to SQLite...');
      
      int successCount = 0;
      for (final entry in manhwaDatabase.entries) {
        try {
          await ManhwaService.addToLibrary(entry.value); // Use addToLibrary
          successCount++;
          print('✓ Migrated: ${entry.value.name}');
        } catch (e) {
          print('✗ Failed to migrate ${entry.value.name}: $e');
        }
      }
      
      print('Migration completed: $successCount/${manhwaDatabase.length} manhwas');
      
      // Verify migration
      final stats = await ManhwaService.getStats();
      print('Database now contains: ${stats['total_manhwas']} manhwas, ${stats['total_chapters']} chapters');
      
    } catch (e) {
      print('Migration failed: $e');
      rethrow;
    }
  }

  // Force re-migration (clears SQLite first)
  static Future<void> forceMigration() async {
    try {
      print('Force migration: clearing existing data...');
      
      // Clear existing SQLite data
      final existingKeys = await ManhwaService.getManhwaKeys();
      for (final key in existingKeys) {
        await ManhwaService.deleteManhwa(key);
      }
      
      // Run migration
      await _migrateAllData();
      
    } catch (e) {
      print('Force migration failed: $e');
      rethrow;
    }
  }
}