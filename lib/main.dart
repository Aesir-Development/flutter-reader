import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutterreader/Screens/login_screen.dart';
import 'services/sqlite_progress_service.dart';
import 'package:flutterreader/services/plugin_service.dart';
import 'services/manhwa_service.dart';
import 'services/progress_service.dart';
import 'services/api_service.dart';
import '../services/plugin_service.dart';
 
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await initializeApp();
  //await SQLiteProgressService.addDummyData();
  runApp(MyApp());
}

Future<void> initializeApp() async {
  try {
    print('🚀 Initializing Manhwa Reader...');

    // 1. Initialize database
    print('📚 Initializing manhwa database...');
    final stats = await ManhwaService.getStats();
    print('✅ Database initialized! Stats: $stats');
    
    // ADD DELAY
    await Future.delayed(const Duration(milliseconds: 500));

    // 2. Initialize progress service
    print('🔄 Initializing progress service...');
    await ProgressService.initialize();
    print('✅ Progress service initialized!');

    // ADD DELAY before sync
    await Future.delayed(const Duration(milliseconds: 300));

    // 3. Background sync (make it non-blocking)
    if (ApiService.isLoggedIn) {
      print('👤 User is logged in, attempting background sync...');
      try {
        final canConnect = await ApiService.checkConnection();
        if (canConnect) {
          final syncSuccess = await ProgressService.performFullSync();
          print(syncSuccess
              ? '✅ Background sync successful!'
              : '⚠️ Background sync failed');
        } else {
          print('📱 No connection, working offline');
        }
      } catch (e) {
        print('! Background sync failed: $e');
        // Continue app startup even if sync fails
      }
    }

    print('👩‍🦽 Initializing Lua engine!');
    PluginService.loadPlugins().then((map) {
      // if (kDebugMode) {
      debugPrint('⚠️ Debug mode: Lua engine will run a test!');
      PluginService.runTest();
      // }
    });

    print('✅ Lua engine initialized!');

    print('🎉 App initialization complete!');
  } catch (e) {
    print('❌ App initialization failed: $e');
    // Continue anyway - app should work offline
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manhwa Reader',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ManhwaLoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

Future<void> initializeManhwaDatabase() async {
  try {
    // This will automatically:
    // 1. Create the database tables
    // 2. Migrate your data from manhwa_data.dart if the database is empty
    // 3. Set up all the indexes

    final stats = await ManhwaService.getStats();
    print('Database initialized successfully!');
    print('Total manhwas: ${stats['total_manhwas']}');
    print('Total chapters: ${stats['total_chapters']}');
    print('Read chapters: ${stats['read_chapters']}');

    // Optional: Get first few manhwas to verify everything works
    final manhwas = await ManhwaService.getAllManhwa();
    print(
        'Sample manhwa: ${manhwas.isNotEmpty ? manhwas.first.name : 'None found'}');
  } catch (e) {
    print('Failed to initialize database: $e');
    // Handle error - maybe show a dialog to user
  }
}

// Add this function to test your migration thoroughly
Future<void> verifyMigrationSuccess() async {
  print('=== Verifying Migration Success ===');

  try {
    // Get stats
    final stats = await ManhwaService.getStats();
    print('Database Stats:');
    print('  Total manhwas: ${stats['total_manhwas']}');
    print('  Total chapters: ${stats['total_chapters']}');
    print('  Read chapters: ${stats['read_chapters']}');

    if (stats.containsKey('error')) {
      print('⚠️  Database has errors: ${stats['error']}');
      return;
    }

    // Get all manhwa and verify data integrity
    final allManhwa = await ManhwaService.getAllManhwa();
    print('\n📚 Manhwa Library:');

    int totalChapters = 0;
    for (final manhwa in allManhwa) {
      print('  ✓ ${manhwa.name}');
      print('    - ID: ${manhwa.id}');
      print('    - Chapters: ${manhwa.chapters.length}');
      print('    - Author: ${manhwa.author}');
      print('    - Status: ${manhwa.status}');
      print('    - Rating: ${manhwa.rating}');
      totalChapters += manhwa.chapters.length;
    }

    print('\n📊 Summary:');
    print('  Total manhwas loaded: ${allManhwa.length}');
    print('  Total chapters loaded: $totalChapters');

    // Test search functionality
    final searchResults = await ManhwaService.searchManhwas('solo');
    print('  Search test ("solo"): ${searchResults.length} results');

    // Test individual manhwa retrieval
    if (allManhwa.isNotEmpty) {
      final testId = allManhwa.first.id;
      final individual = await ManhwaService.getManhwaById(testId);
      print(
          '  Individual retrieval test: ${individual != null ? "✓ Success" : "✗ Failed"}');
    }

    print('\n🎉 Migration verification complete!');

    if (allManhwa.length >= 8 && totalChapters > 0) {
      print(
          '✅ Migration appears successful! Safe to consider removing legacy dependencies.');
    } else {
      print('⚠️  Migration may be incomplete. Keep legacy data as backup.');
    }
  } catch (e) {
    print('❌ Verification failed: $e');
    print('Keep legacy data as backup!');
  }
}
