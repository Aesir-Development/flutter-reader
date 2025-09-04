import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'manhwa_service.dart';
import 'sqlite_progress_service.dart';
class ApiService {
  static const String _defaultBaseUrl = 'http://localhost:8080';
  static String _baseUrl = _defaultBaseUrl;
  
  static String? _authToken;
  static User? _currentUser;
  
  // Connection caching
  static bool? _lastConnectionStatus;
  static DateTime? _lastConnectionCheck;
  static const Duration _connectionCacheTimeout = Duration(minutes: 2);

  // Initialize from database
  static Future<void> initialize() async {
    // Load custom server IP if exists
    await _loadCustomServerIP();
    
    // Load auth data
    final authData = await ManhwaService.getAuthData();
    if (authData != null) {
      _authToken = authData['token'];
      _currentUser = User.fromJson(jsonDecode(authData['user_data']!));
    }
  }

  // Server IP Management
  static String? getCurrentServerIP() {
    if (_baseUrl == _defaultBaseUrl) {
      return null; // Return null for default server
    }
    return _baseUrl;
  }

  static Future<void> setServerIP(String? ip) async {
    if (ip == null || ip.trim().isEmpty) {
      // Reset to default server
      _baseUrl = _defaultBaseUrl;
      await ManhwaService.removeCustomServerIP();
    } else {
      // Set custom server IP
      String serverUrl = ip.trim();
      
      // Add http:// if no protocol is specified
      if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
        serverUrl = 'http://$serverUrl';
      }
      
      // Remove trailing slash if present
      if (serverUrl.endsWith('/')) {
        serverUrl = serverUrl.substring(0, serverUrl.length - 1);
      }
      
      _baseUrl = serverUrl;
      await ManhwaService.saveCustomServerIP(serverUrl);
    }
    
    // Clear connection cache when server changes
    clearConnectionCache();
    
    // Clear auth data when switching servers (optional - you might want to keep it)
    // await logout();
  }

  static Future<void> _loadCustomServerIP() async {
    final customIP = await ManhwaService.getCustomServerIP();
    if (customIP != null) {
      _baseUrl = customIP;
    } else {
      _baseUrl = _defaultBaseUrl;
    }
  }

  static String get baseUrl => _baseUrl;

  // Check if user is logged in
  static bool get isLoggedIn => _authToken != null && _currentUser != null;
  static User? get currentUser => _currentUser;

  // Common headers
  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    
    return headers;
  }

  // Authentication
  static Future<AuthResult> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await _saveAuthData(data['token'], User.fromJson(data['user']));
        
        // Clear connection cache since we just made a successful request
        _updateConnectionCache(true);
        
        return AuthResult.success(_currentUser!);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Registration failed';
        return AuthResult.error(error);
      }
    } on SocketException {
      _updateConnectionCache(false);
      return AuthResult.error('Cannot connect to server. Please check your connection and server address.');
    } on HttpException {
      _updateConnectionCache(false);
      return AuthResult.error('Server error. Please try again later.');
    } catch (e) {
      _updateConnectionCache(false);
      return AuthResult.error('Network error: ${e.toString()}');
    }
  }

  static Future<AuthResult> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveAuthData(data['token'], User.fromJson(data['user']));
        
        // Clear connection cache since we just made a successful request
        _updateConnectionCache(true);
        
        return AuthResult.success(_currentUser!);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Login failed';
        return AuthResult.error(error);
      }
    } on SocketException {
      _updateConnectionCache(false);
      return AuthResult.error('Cannot connect to server. Please check your connection and server address.');
    } on HttpException {
      _updateConnectionCache(false);
      return AuthResult.error('Server error. Please try again later.');
    } catch (e) {
      _updateConnectionCache(false);
      return AuthResult.error('Network error: ${e.toString()}');
    }
  }

  static Future<void> logout() async {
    await ManhwaService.clearAuthData();
    _authToken = null;
    _currentUser = null;
    
    // Clear connection cache
    _lastConnectionStatus = null;
    _lastConnectionCheck = null;
  }

  static Future<void> _saveAuthData(String token, User user) async {
    _authToken = token;
    _currentUser = user;
    
    await ManhwaService.saveAuthData(token, jsonEncode(user.toJson()));
  }

  // Sync operations
  static Future<SyncResult> pullSync() async {
    if (!isLoggedIn) return SyncResult.error('Not logged in');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/sync/pull'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final syncData = SyncData.fromJson(data);
        
        // Save last sync time in database
        await SQLiteProgressService.saveSetting('last_sync', DateTime.now().toIso8601String());
        
        // Update connection cache
        _updateConnectionCache(true);
        
        return SyncResult.success(syncData);
      } else {
        return SyncResult.error('Failed to sync: ${response.statusCode}');
      }
    } on SocketException {
      _updateConnectionCache(false);
      return SyncResult.error('Cannot connect to server');
    } catch (e) {
      _updateConnectionCache(false);
      return SyncResult.error('Network error: ${e.toString()}');
    }
  }

  static Future<SyncResult> pushProgress(List<ProgressUpdate> updates) async {
    if (!isLoggedIn) return SyncResult.error('Not logged in');
    if (updates.isEmpty) return SyncResult.success(null);

    try {
      print('Pushing ${updates.length} progress updates to server...');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/sync/progress'),
        headers: _headers,
        body: jsonEncode(updates.map((u) => u.toJson()).toList()),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        _updateConnectionCache(true);
        print('Successfully pushed progress updates');
        return SyncResult.success(null);
      } else {
        print('Failed to push progress: ${response.statusCode}');
        return SyncResult.error('Failed to push progress: ${response.statusCode}');
      }
    } on SocketException {
      _updateConnectionCache(false);
      print('Failed to push progress: Cannot connect to server');
      return SyncResult.error('Cannot connect to server');
    } catch (e) {
      _updateConnectionCache(false);
      print('Failed to push progress: $e');
      return SyncResult.error('Network error: ${e.toString()}');
    }
  }

  static Future<SyncResult> syncLibrary({
    List<String> add = const [],
    List<String> remove = const [],
  }) async {
    if (!isLoggedIn) return SyncResult.error('Not logged in');
    if (add.isEmpty && remove.isEmpty) return SyncResult.success(null);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/sync/library'),
        headers: _headers,
        body: jsonEncode({
          'add': add,
          'remove': remove,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        _updateConnectionCache(true);
        return SyncResult.success(null);
      } else {
        return SyncResult.error('Failed to sync library: ${response.statusCode}');
      }
    } on SocketException {
      _updateConnectionCache(false);
      return SyncResult.error('Cannot connect to server');
    } catch (e) {
      _updateConnectionCache(false);
      return SyncResult.error('Network error: ${e.toString()}');
    }
  }

  // Utility
  static Future<Map<String, dynamic>?> getUserStats() async {
    if (!isLoggedIn) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/stats'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _updateConnectionCache(true);
        return jsonDecode(response.body);
      }
    } on SocketException {
      _updateConnectionCache(false);
      print('Failed to get user stats: Cannot connect to server');
    } catch (e) {
      _updateConnectionCache(false);
      print('Failed to get user stats: $e');
    }
    
    return null;
  }

  // OPTIMIZED CONNECTION CHECK WITH CACHING
  static Future<bool> checkConnection() async {
    // Return cached result if it's still valid
    if (_lastConnectionStatus != null && 
        _lastConnectionCheck != null && 
        DateTime.now().difference(_lastConnectionCheck!) < _connectionCacheTimeout) {
      return _lastConnectionStatus!;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/hey'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      
      final isOnline = response.statusCode == 200;
      _updateConnectionCache(isOnline);
      return isOnline;
      
    } on SocketException {
      _updateConnectionCache(false);
      return false;
    } catch (e) {
      _updateConnectionCache(false);
      return false;
    }
  }

  // Get cached connection status without network call
  static bool? get cachedConnectionStatus => _lastConnectionStatus;

  // Force refresh connection status
  static Future<bool> forceCheckConnection() async {
    _lastConnectionStatus = null;
    _lastConnectionCheck = null;
    return await checkConnection();
  }

  // Update connection cache
  static void _updateConnectionCache(bool isOnline) {
    _lastConnectionStatus = isOnline;
    _lastConnectionCheck = DateTime.now();
  }

  // Clear connection cache (call when you want to force a fresh check)
  static void clearConnectionCache() {
    _lastConnectionStatus = null;
    _lastConnectionCheck = null;
  }

  // Test connection to a specific server without changing current server
  static Future<bool> testConnection(String serverUrl) async {
    try {
      String testUrl = serverUrl.trim();
      
      // Add http:// if no protocol is specified
      if (!testUrl.startsWith('http://') && !testUrl.startsWith('https://')) {
        testUrl = 'http://$testUrl';
      }
      
      // Remove trailing slash if present
      if (testUrl.endsWith('/')) {
        testUrl = testUrl.substring(0, testUrl.length - 1);
      }
      
      final response = await http.get(
        Uri.parse('$testUrl/hey'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      
      return response.statusCode == 200;
      
    } catch (e) {
      return false;
    }
  }
}

// Data models (unchanged)
class User {
  final int id;
  final String email;

  User({required this.id, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
    };
  }
}

class SyncData {
  final List<String> library;
  final List<RemoteProgress> progress;
  final DateTime lastSync;

  SyncData({
    required this.library,
    required this.progress,
    required this.lastSync,
  });

  factory SyncData.fromJson(Map<String, dynamic> json) {
    return SyncData(
      library: List<String>.from(json['library'] ?? []),
      progress: (json['progress'] as List? ?? [])
          .map((p) => RemoteProgress.fromJson(p))
          .toList(),
      lastSync: DateTime.parse(json['lastSync']),
    );
  }
}

class RemoteProgress {
  final String manhwaId;
  final double chapterNumber;
  final int currentPage;
  final double scrollPosition;
  final bool isRead;
  final DateTime lastReadAt;
  final DateTime updatedAt;

  RemoteProgress({
    required this.manhwaId,
    required this.chapterNumber,
    required this.currentPage,
    required this.scrollPosition,
    required this.isRead,
    required this.lastReadAt,
    required this.updatedAt,
  });

factory RemoteProgress.fromJson(Map<String, dynamic> json) {
  return RemoteProgress(
    manhwaId: json['manhwaId'],
    chapterNumber: (json['chapterNumber'] as num).toDouble(),
    currentPage: (json['currentPage'] as num).toInt(),
    scrollPosition: (json['scrollPosition'] as num).toDouble(),
    isRead: json['isRead'] is bool ? json['isRead'] : (json['isRead'] == 1),
    lastReadAt: DateTime.parse(json['lastReadAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );
}
}

class ProgressUpdate {
  final String manhwaId;
  final double chapterNumber;
  final int currentPage;
  final double scrollPosition;
  final bool isRead;

  ProgressUpdate({
    required this.manhwaId,
    required this.chapterNumber,
    required this.currentPage,
    required this.scrollPosition,
    required this.isRead,
  });

  Map<String, dynamic> toJson() {
    return {
      'manhwaId': manhwaId,
      'chapterNumber': chapterNumber,
      'currentPage': currentPage,
      'scrollPosition': scrollPosition,
      'isRead': isRead,
    };
  }
}

// Result classes (unchanged)
class AuthResult {
  final bool success;
  final User? user;
  final String? error;

  AuthResult.success(this.user) : success = true, error = null;
  AuthResult.error(this.error) : success = false, user = null;
}

class SyncResult {
  final bool success;
  final SyncData? data;
  final String? error;

  SyncResult.success(this.data) : success = true, error = null;
  SyncResult.error(this.error) : success = false, data = null;
}
