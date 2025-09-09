import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/progress_service.dart';
import '../services/manhwa_service.dart';
import '../services/sqlite_progress_service.dart';
import 'library_screen.dart';
import 'update_screen.dart';
import 'social_screen.dart';
import 'browse_screen.dart';
import 'more_screen.dart';
import 'login_screen.dart';
import 'dart:async';

class MainShell extends StatefulWidget {
  const MainShell({Key? key}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 2; // Default to Library tab
  bool _isOnline = true;
  
  // Connection check throttling
  DateTime? _lastConnectionCheck;
  static const Duration _connectionCheckInterval = Duration(minutes: 5); // Reduced frequency
  
  Timer? _connectionTimer;

  final List<Widget> _screens = const [
    SocialScreen(), 
    UpdateScreen(),
    LibraryScreen(),
    BrowseScreen(), 
    MoreScreen(), 
  ];

  final List<String> _titles = [
    'Social',
    'Updates',
    'Library',
    'Browse',
    'More',
  ];

  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkConnectionStatus();
    // Initial connection check (uses cache if available)
  });
    
    // Set up periodic connection checks (reduced frequency)
    _startPeriodicConnectionCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionTimer?.cancel();
    ProgressService.dispose(); // Clean up sync timer
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Only check connection if enough time has passed since last check
      final now = DateTime.now();
      if (_lastConnectionCheck == null || 
          now.difference(_lastConnectionCheck!) > _connectionCheckInterval) {
        _checkConnectionStatus();
        _tryBackgroundSync();
      } else {
        print('Skipping connection check - too recent');
      }
    }
  }

  // OPTIMIZED: Reduced frequency connection checking
  void _startPeriodicConnectionCheck() {
    _connectionTimer?.cancel();
    
    // Check connection every 5 minutes instead of constantly
    _connectionTimer = Timer.periodic(_connectionCheckInterval, (_) {
      if (mounted && ApiService.isLoggedIn) {
        _checkConnectionStatus();
      }
    });
  }

  Future<void> _checkConnectionStatus() async {
    if (!mounted || !ApiService.isLoggedIn) return;
    
    _lastConnectionCheck = DateTime.now();
    
    // Use cached connection status first
    final cachedStatus = ApiService.cachedConnectionStatus;
    if (cachedStatus != null) {
      if (_isOnline != cachedStatus) {
        setState(() => _isOnline = cachedStatus);
        _showConnectionStatusMessage(cachedStatus);
      }
      return;
    }
    
    // Only do actual network check if no cached status available
    try {
      final isOnline = await ApiService.checkConnection();
      
      if (mounted && _isOnline != isOnline) {
        setState(() => _isOnline = isOnline);
        _showConnectionStatusMessage(isOnline);
        
        if (isOnline) {
          _tryBackgroundSync();
        }
      }
    } catch (e) {
      print('Connection check failed: $e');
    }
  }

  void _showConnectionStatusMessage(bool isOnline) {
    if (!mounted) return;
    
    if (isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_done, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Back online! Syncing progress...'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Offline - changes will sync when online'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _tryBackgroundSync() async {
    if (ApiService.isLoggedIn && _isOnline) {
      // Non-blocking background sync
      ProgressService.syncNow().then((success) {
        if (success) {
          print('Background sync completed successfully');
        }
      }).catchError((error) {
        print('Background sync failed: $error');
      });
    }
  }

  void _showSortOptions() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sort options coming soon!')),
    );
  }

  // Check if database has existing data
  Future<bool> _hasExistingData() async {
    try {
      final stats = await ManhwaService.getStats();
      final dbInfo = await SQLiteProgressService.getDatabaseInfo();
      
      final hasManhwas = (stats['total_manhwas'] ?? 0) > 0;
      final hasProgress = (dbInfo['progress_records'] ?? 0) > 0;
      
      return hasManhwas || hasProgress;
    } catch (e) {
      print('Error checking existing data: $e');
      return false;
    }
  }

  // Wipe all database data
  Future<void> _wipeDatabase() async {
    try {
      // Clear all manhwa data
      await ManhwaService.clearAllData();
      
      // Clear all progress data
      await SQLiteProgressService.clearAllSettings();
      
      // Clear any remaining progress records
      final db = await SQLiteProgressService.database;
      await db.update(
        'chapters',
        {
          'is_read': 0,
          'current_page': 0,
          'scroll_position': 0.0,
          'last_read_at': null,
          'reading_time_seconds': 0,
        },
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.delete_sweep, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('All local data has been cleared'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Failed to clear data: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      rethrow;
    }
  }

  // Show logout options dialog
  Future<String?> _showLogoutOptionsDialog() async {
    final hasData = await _hasExistingData();
    
    if (!hasData) {
      // If no data exists, just show simple logout confirmation
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a2a),
          title: const Text('Logout', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      return confirmed == true ? 'logout' : null;
    }

    // Show full options dialog with data wipe choice
    return await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Logout Options', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You have local manhwa data and reading progress stored on this device.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔒 Privacy Options',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• KEEP DATA: Logout but keep your library and progress (others using this device can access it)',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• WIPE DATA: Clear all data for privacy (recommended for shared devices)',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'What would you like to do?',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null), // Cancel
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'logout'), // Keep data
            child: const Text(
              'Logout & Keep Data',
              style: TextStyle(color: Color(0xFF6c5ce7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'wipe'), // Wipe data
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Logout & Wipe Data',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final result = await _showLogoutOptionsDialog();
    
    if (result == null) return; // User cancelled
    
    // Show loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          color: Color(0xFF2a2a2a),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF6c5ce7)),
                SizedBox(height: 16),
                Text('Processing logout...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Wipe data if requested
      if (result == 'wipe') {
        await _wipeDatabase();
      }

      // Clear connection cache on logout
      ApiService.clearConnectionCache();
      await ApiService.logout();
      
      // Hide loading dialog
      Navigator.pop(context);
      
      // Navigate to login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ManhwaLoginScreen()),
      );
      
    } catch (e) {
      // Hide loading dialog
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ENHANCED: Manual sync button in library header
  Future<void> _triggerManualSync() async {
    if (!ApiService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to sync progress'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Syncing progress...'),
          ],
        ),
        duration: Duration(seconds: 5),
        backgroundColor: Color(0xFF6c5ce7),
      ),
    );
    
    final success = await ProgressService.triggerManualSync();
    
    // Hide loading snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    // Show result
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(success ? 'Sync completed!' : 'Sync failed - will retry later'),
          ],
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildLibraryHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 32, 8, 24),
      color: const Color(0xFF2a2a2a),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                FutureBuilder<Map<String, dynamic>>(
                  future: ProgressService.getSyncStatus(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return _buildConnectionStatus();
                    }
                    
                    final status = snapshot.data!;
                    final isLoggedIn = status['isLoggedIn'] ?? false;
                    final isSyncing = status['isSyncing'] ?? false;
                    final hasPending = status['hasPendingSync'] ?? false;
                    final connectionStatus = status['connectionStatus'];
                    
                    if (!isLoggedIn) {
                      return const Row(
                        children: [
                          Icon(Icons.person_off, color: Colors.grey, size: 16),
                          SizedBox(width: 4),
                          Text('Local only', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      );
                    }
                    
                    Color statusColor;
                    IconData statusIcon;
                    String statusText;
                    
                    if (isSyncing) {
                      statusColor = Colors.blue;
                      statusIcon = Icons.sync;
                      statusText = 'Syncing...';
                    } else if (connectionStatus == false) {
                      statusColor = Colors.orange;
                      statusIcon = Icons.cloud_off;
                      statusText = 'Offline';
                    } else if (hasPending) {
                      statusColor = Colors.yellow;
                      statusIcon = Icons.cloud_queue;
                      statusText = 'Pending sync';
                    } else {
                      statusColor = Colors.green;
                      statusIcon = Icons.cloud_done;
                      statusText = 'Synced';
                    }
                    
                    return Row(
                      children: [
                        isSyncing
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                ),
                              )
                            : Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(color: statusColor, fontSize: 12),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Search functionality coming soon!')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.sort, color: Colors.white),
                onPressed: _showSortOptions,
              ),
              if (ApiService.isLoggedIn) ...[
                // Manual sync button
                IconButton(
                  icon: const Icon(Icons.sync, color: Colors.white),
                  onPressed: _triggerManualSync,
                  tooltip: 'Manual Sync',
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: _logout,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    if (!ApiService.isLoggedIn) {
      return const Row(
        children: [
          Icon(Icons.person_off, color: Colors.grey, size: 16),
          SizedBox(width: 4),
          Text('Local only', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      );
    }
    
    return Row(
      children: [
        Icon(
          _isOnline ? Icons.cloud_done : Icons.cloud_off,
          color: _isOnline ? Colors.green : Colors.orange,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          _isOnline ? 'Online' : 'Offline',
          style: TextStyle(
            color: _isOnline ? Colors.green : Colors.orange,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 32, 8, 24),
      color: const Color(0xFF2a2a2a),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titles[_currentIndex],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (ApiService.isLoggedIn) _buildConnectionStatus(),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search coming soon!')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: Column(
        children: [
          _currentIndex == 2
              ? _buildLibraryHeader(context)
              : _buildDefaultHeader(context),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF2a2a2a),
        selectedItemColor: const Color(0xFF6c5ce7),
        unselectedItemColor: Colors.grey[400],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.social_distance),
            label: 'Social',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.update),
            label: 'Updates',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Browse',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}