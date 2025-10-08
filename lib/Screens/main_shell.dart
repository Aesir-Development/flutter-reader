import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutterreader/Screens/manhwa_search_delegate.dart';
import 'package:flutterreader/services/api_service.dart';
import 'package:flutterreader/services/plugin_service.dart';
import 'package:flutterreader/services/progress_service.dart';
import 'library_screen.dart';
import 'browse_screen.dart';
import 'more_screen.dart';
import 'social_screen.dart';
import 'update_screen.dart';
import 'login_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({Key? key}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 2; // Default to Library tab
  bool _isOnline = true;
  List<String> pluginNames = [];

  DateTime? _lastConnectionCheck;
  static const Duration _connectionCheckInterval = Duration(minutes: 5);
  Timer? _connectionTimer;

  final List<Widget> _screens = const [
    SocialScreen(),
    UpdateScreen(),
    LibraryScreen(),
    BrowseScreen(),
    MoreScreen(),
  ];

  final List<String> _titles = ['Social', 'Updates', 'Library', 'Browse', 'More'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectionStatus();
      _loadPluginNames();
    });

    _startPeriodicConnectionCheck();
  }

  Future<void> _loadPluginNames() async {
    try {
      final names = await PluginService.getPluginNames();
      setState(() => pluginNames = names);
    } catch (e) {
      debugPrint("Error loading plugin names: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionTimer?.cancel();
    ProgressService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastConnectionCheck == null ||
          now.difference(_lastConnectionCheck!) > _connectionCheckInterval) {
        _checkConnectionStatus();
        _tryBackgroundSync();
      }
    }
  }

  void _startPeriodicConnectionCheck() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer.periodic(_connectionCheckInterval, (_) {
      if (mounted && ApiService.isLoggedIn) _checkConnectionStatus();
    });
  }

  Future<void> _checkConnectionStatus() async {
    if (!mounted || !ApiService.isLoggedIn) return;

    _lastConnectionCheck = DateTime.now();
    final cachedStatus = ApiService.cachedConnectionStatus;
    if (cachedStatus != null) {
      if (_isOnline != cachedStatus) {
        setState(() => _isOnline = cachedStatus);
        _showConnectionStatusMessage(cachedStatus);
      }
      return;
    }

    try {
      final isOnline = await ApiService.checkConnection();
      if (mounted && _isOnline != isOnline) {
        setState(() => _isOnline = isOnline);
        _showConnectionStatusMessage(isOnline);
        if (isOnline) _tryBackgroundSync();
      }
    } catch (e) {
      debugPrint('Connection check failed: $e');
    }
  }

  void _showConnectionStatusMessage(bool isOnline) {
    if (!mounted) return;
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(isOnline ? Icons.cloud_done : Icons.cloud_off, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(isOnline
              ? 'Back online! Syncing progress...'
              : 'Offline - changes will sync when online'),
        ],
      ),
      backgroundColor: isOnline ? Colors.green : Colors.orange,
      duration: const Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _tryBackgroundSync() async {
    if (!ApiService.isLoggedIn || !_isOnline) return;
    try {
      final success = await ProgressService.syncNow();
      debugPrint(success ? 'Background sync completed successfully' : 'Background sync failed');
    } catch (e) {
      debugPrint('Background sync failed: $e');
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
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
      ApiService.clearConnectionCache();
      await ApiService.logout();
      if (Navigator.canPop(context)) Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ManhwaLoginScreen()),
      );
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _triggerManualSync() async {
    if (!ApiService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to sync progress'), backgroundColor: Colors.orange),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Syncing progress...'),
          ],
        ),
        duration: Duration(seconds: 5),
        backgroundColor: Color(0xFF6c5ce7),
      ),
    );

    final success = await ProgressService.triggerManualSync();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(success ? 'Sync completed!' : 'Sync failed - will retry later'),
          ],
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildHeader() {
    final isLibrary = _currentIndex == 2;
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
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              if (ApiService.isLoggedIn)
                Row(
                  children: [
                    Icon(_isOnline ? Icons.cloud_done : Icons.cloud_off,
                        color: _isOnline ? Colors.green : Colors.orange, size: 16),
                    const SizedBox(width: 4),
                    Text(_isOnline ? 'Online' : 'Offline',
                        style: TextStyle(color: _isOnline ? Colors.green : Colors.orange, fontSize: 12)),
                  ],
                ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  showSearch(
                    context: context,
                    delegate: ManhwaSearchDelegate(),
                  );
                },
              ),
              if (ApiService.isLoggedIn)
                IconButton(icon: const Icon(Icons.sync, color: Colors.white), onPressed: _triggerManualSync),
              if (ApiService.isLoggedIn)
                IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _logout),
            ],
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
          _buildHeader(),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF2a2a2a),
        selectedItemColor: const Color(0xFF6c5ce7),
        unselectedItemColor: Colors.grey[400],
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.social_distance), label: 'Social'),
          BottomNavigationBarItem(icon: Icon(Icons.update), label: 'Updates'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Browse'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
