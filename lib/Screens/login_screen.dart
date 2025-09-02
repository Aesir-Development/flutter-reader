import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/progress_service.dart';
import '../services/manhwa_service.dart';
import '../services/sqlite_progress_service.dart';
import 'main_shell.dart';

class ManhwaLoginScreen extends StatefulWidget {
  const ManhwaLoginScreen({Key? key}) : super(key: key);

  @override
  State<ManhwaLoginScreen> createState() => _ManhwaLoginScreenState();
}

class _ManhwaLoginScreenState extends State<ManhwaLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ipController = TextEditingController();
  
  // Focus nodes for keyboard navigation
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isRegisterMode = false;
  bool _isOfflineMode = false;
  String _currentServerIP = 'Default Server';

  @override
  void initState() {
    super.initState();
    _loadCurrentServerIP();
    _checkExistingLogin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _ipController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentServerIP() async {
    setState(() {
      _currentServerIP = ApiService.getCurrentServerIP() ?? 'Default Server';
    });
  }

  Future<void> _checkExistingLogin() async {
    await ApiService.initialize();
    if (ApiService.isLoggedIn) {
      _performBackgroundSync();
      _navigateToMainShell();
    }
  }

  Future<void> _performBackgroundSync() async {
    try {
      final canConnect = await ApiService.checkConnection();
      if (canConnect) {
        await ProgressService.performFullSync();
      }
    } catch (e) {
      print('Background sync failed: $e');
    }
  }

  Future<bool> _hasExistingData() async {
    return await hasExistingData();
  }

  static Future<void> wipeDatabase(BuildContext context) async {
    try {
      await ManhwaService.clearAllData();
      await SQLiteProgressService.clearAllSettings();
      
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
      
      print('Database wiped successfully');
      
    } catch (e) {
      print('Error wiping database: $e');
      rethrow;
    }
  }
  
  static Future<bool> hasExistingData() async {
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

  Future<void> _wipeDatabase() async {
    try {
      setState(() => _isLoading = true);
      
      await wipeDatabase(context);
      _showSuccess('Database cleared successfully!');
      
    } catch (e) {
      _showError('Failed to clear database: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showServerIPDialog() async {
    _ipController.text = _currentServerIP == 'Default Server' ? '' : _currentServerIP;
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6c5ce7).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.dns, color: Color(0xFF6c5ce7), size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Server Configuration', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the IP address or domain of your server:',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ipController,
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                final ip = _ipController.text.trim();
                Navigator.pop(context, ip.isEmpty ? 'DEFAULT' : ip);
              },
              decoration: InputDecoration(
                labelText: 'Server IP/Domain',
                labelStyle: const TextStyle(color: Colors.grey),
                hintText: 'e.g. 192.168.1.100:3000 or myserver.com',
                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.6)),
                prefixIcon: const Icon(Icons.computer, color: Color(0xFF6c5ce7)),
                filled: true,
                fillColor: const Color(0xFF3a3a3a),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6c5ce7)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6c5ce7).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF6c5ce7).withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tips:',
                    style: TextStyle(color: Color(0xFF6c5ce7), fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Include port if needed (e.g. :8080)\n• Use http:// or https:// prefix if required\n• Leave empty to use default server\n• Press Enter to connect',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'DEFAULT'),
            child: const Text('Use Default', style: TextStyle(color: Colors.orange)),
          ),
          ElevatedButton(
            onPressed: () {
              final ip = _ipController.text.trim();
              Navigator.pop(context, ip.isEmpty ? 'DEFAULT' : ip);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6c5ce7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    
    if (result != null) {
      await _updateServerIP(result);
    }
  }

  Future<void> _updateServerIP(String serverIP) async {
    setState(() => _isLoading = true);
    
    try {
      if (serverIP == 'DEFAULT') {
        await ApiService.setServerIP(null);
        setState(() {
          _currentServerIP = 'Default Server';
        });
        _showSuccess('Switched to default server');
      } else {
        await ApiService.setServerIP(serverIP);
        
        final canConnect = await ApiService.checkConnection();
        
        if (canConnect) {
          setState(() {
            _currentServerIP = serverIP;
          });
          _showSuccess('Connected to $serverIP successfully!');
        } else {
          _showError('Failed to connect to $serverIP. Please check the address.');
          await _loadCurrentServerIP();
        }
      }
    } catch (e) {
      _showError('Error updating server: $e');
      await _loadCurrentServerIP();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showWipeConfirmationDialog() async {
    final result = await showDialog<bool>(
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
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Existing Data Found', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your device already contains manhwa library data and reading progress.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warning',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Logging in will sync your account data. You can either:',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• WIPE: Clear local data and start fresh with your account',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• MERGE: Keep local data and merge with your account (may cause conflicts)',
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
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep & Merge', style: TextStyle(color: Color(0xFF6c5ce7))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Wipe & Start Fresh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final hasData = await _hasExistingData();
      
      if (hasData) {
        setState(() => _isLoading = false);
        
        final shouldWipe = await _showWipeConfirmationDialog();
        
        if (shouldWipe == null) {
          return;
        }
        
        setState(() => _isLoading = true);
        
        if (shouldWipe == true) {
          await _wipeDatabase();
        }
      }
      
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;
      
      AuthResult result;
      
      if (_isRegisterMode) {
        result = await ApiService.register(email, password);
      } else {
        result = await ApiService.login(email, password);
      }
      
      if (result.success) {
        _showSuccess(_isRegisterMode ? 'Registration successful!' : 'Login successful!');
        
        final syncSuccess = await ProgressService.performFullSync();
        if (!syncSuccess) {
          _showWarning('Logged in but sync failed. Working in offline mode.');
        }
        
        _navigateToMainShell();
      } else {
        _showError(result.error ?? 'Authentication failed');
      }
    } catch (e) {
      _showError('Network error. Please check your connection.');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _continueOffline() async {
    setState(() => _isOfflineMode = true);
    _showInfo('Working in offline mode. Login to sync across devices.');
    
    await Future.delayed(const Duration(milliseconds: 1500));
    _navigateToMainShell();
  }

  void _navigateToMainShell() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainShell()),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange, duration: const Duration(seconds: 4)),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF6c5ce7), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isWeb ? 32 : 24),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isWeb ? 400 : double.infinity,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildServerStatus(),
                const SizedBox(height: 24),
                if (!_isOfflineMode) ...[
                  _buildAuthForm(),
                  const SizedBox(height: 24),
                  _buildAuthButton(),
                  const SizedBox(height: 16),
                  _buildSwitchModeButton(),
                  const SizedBox(height: 24),
                  _buildOfflineOption(),
                ] else ...[
                  _buildOfflineMessage(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF6c5ce7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.menu_book, size: 48, color: Colors.white),
        ),
        const SizedBox(height: 24),
        const Text(
          'Manhwa Reader',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          _isOfflineMode 
              ? 'Offline Mode' 
              : _isRegisterMode 
                  ? 'Create your account'
                  : 'Login to sync across devices',
          style: TextStyle(fontSize: 16, color: Colors.grey[400]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildServerStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6c5ce7).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6c5ce7).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.dns, color: Color(0xFF6c5ce7), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Server', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  _currentServerIP,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isLoading ? null : _showServerIPDialog,
            icon: const Icon(Icons.settings, color: Color(0xFF6c5ce7), size: 20),
            tooltip: 'Change Server',
          ),
        ],
      ),
    );
  }

  Widget _buildAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            onFieldSubmitted: (_) {
              // Move focus to password field when Enter is pressed
              FocusScope.of(context).requestFocus(_passwordFocusNode);
            },
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.email, color: Color(0xFF6c5ce7)),
              filled: true,
              fillColor: const Color(0xFF2a2a2a),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6c5ce7)),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: Colors.white),
            onFieldSubmitted: (_) {
              // Trigger login when Enter is pressed in password field
              if (!_isLoading) {
                _handleAuth();
              }
            },
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.lock, color: Color(0xFF6c5ce7)),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              filled: true,
              fillColor: const Color(0xFF2a2a2a),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6c5ce7)),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAuthButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleAuth,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6c5ce7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                _isRegisterMode ? 'Register' : 'Login',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildSwitchModeButton() {
    return TextButton(
      onPressed: () {
        setState(() {
          _isRegisterMode = !_isRegisterMode;
        });
        // Clear validation errors when switching modes
        _formKey.currentState?.reset();
      },
      child: Text(
        _isRegisterMode 
            ? 'Already have an account? Login'
            : 'Don\'t have an account? Register',
        style: const TextStyle(color: Color(0xFF6c5ce7)),
      ),
    );
  }

  Widget _buildOfflineOption() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off, color: Colors.grey[400], size: 32),
          const SizedBox(height: 8),
          Text(
            'Use Offline Mode',
            style: TextStyle(color: Colors.grey[300], fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Continue without account. Your data will be stored locally.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _continueOffline,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[600]!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Continue Offline',
                style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6c5ce7).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.offline_bolt, color: Color(0xFF6c5ce7), size: 48),
          const SizedBox(height: 16),
          const Text(
            'Offline Mode Active',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your reading progress will be saved locally. Create an account later to sync across devices.',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: Color(0xFF6c5ce7), strokeWidth: 3),
        ],
      ),
    );
  }
}