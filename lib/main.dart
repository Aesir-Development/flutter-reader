import 'package:flutter/material.dart';
import 'package:flutterreader/Screens/main_shell.dart';
import 'services/manhwa_service.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await verifyMigrationSuccess();
  // Test the database
  try {
    print('Initializing manhwa database...');
    final stats = await ManhwaService.getStats();
    print('Database initialized successfully!');
    print('Stats: $stats');
  } catch (e) {
    print('Database initialization failed: $e');
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manhwa Reader',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const MainShell(),
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
    print('Sample manhwa: ${manhwas.isNotEmpty ? manhwas.first.name : 'None found'}');
    
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
      print('  Individual retrieval test: ${individual != null ? "✓ Success" : "✗ Failed"}');
    }
    
    print('\n🎉 Migration verification complete!');
    
    if (allManhwa.length >= 8 && totalChapters > 0) {
      print('✅ Migration appears successful! Safe to consider removing legacy dependencies.');
    } else {
      print('⚠️  Migration may be incomplete. Keep legacy data as backup.');
    }
    
  } catch (e) {
    print('❌ Verification failed: $e');
    print('Keep legacy data as backup!');
  }
}