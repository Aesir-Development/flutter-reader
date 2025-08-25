import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/progress_service.dart';
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
  
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isRegisterMode = false;
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  Future<void> _checkExistingLogin() async {
    await ApiService.initialize();
    if (ApiService.isLoggedIn) {
      // Try to sync if online, but don't block
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
      // Continue anyway - offline mode
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    try {
      AuthResult result;
      
      if (_isRegisterMode) {
        result = await ApiService.register(email, password);
      } else {
        result = await ApiService.login(email, password);
      }
      
      if (result.success) {
        _showSuccess(_isRegisterMode ? 'Registration' : 'Login');
        
        // Perform initial sync
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
    
    // Small delay for user to see the message
    await Future.delayed(const Duration(milliseconds: 1500));
    _navigateToMainShell();
  }

  void _navigateToMainShell() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainShell()),
    );
  }

  void _showSuccess(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action successful! Welcome to Manhwa Reader'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6c5ce7),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showCredentials() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text('Demo Credentials', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Use any of these credentials to login:', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            const Text('Email: admin@manhwa.com', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Text('Password: admin123', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Email: user@manhwa.com', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Text('Password: user123', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Email: demo@manhwa.com', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Text('Password: demo123', style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF6c5ce7))),
          ),
        ],
      ),
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
                const SizedBox(height: 40),
                if (!_isOfflineMode) ...[
                  _buildAuthForm(),
                  const SizedBox(height: 24),
                  _buildAuthButton(),
                  const SizedBox(height: 16),
                  _buildSwitchModeButton(),
                  const SizedBox(height: 16),
                  _buildCredentialsButton(),
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
          child: const Icon(
            Icons.menu_book,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Manhwa Reader',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isOfflineMode 
              ? 'Offline Mode' 
              : _isRegisterMode 
                  ? 'Create your account'
                  : 'Login to sync across devices',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[400],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
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
            obscureText: !_isPasswordVisible,
            style: const TextStyle(color: Colors.white),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                _isRegisterMode ? 'Register' : 'Login',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
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
      },
      child: Text(
        _isRegisterMode 
            ? 'Already have an account? Login'
            : 'Don\'t have an account? Register',
        style: const TextStyle(
          color: Color(0xFF6c5ce7),
        ),
      ),
    );
  }

  Widget _buildCredentialsButton() {
    return TextButton(
      onPressed: _showCredentials,
      child: const Text(
        'Show Demo Credentials',
        style: TextStyle(
          color: Color(0xFF6c5ce7),
          decoration: TextDecoration.underline,
        ),
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
          Icon(
            Icons.cloud_off,
            color: Colors.grey[400],
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Use Offline Mode',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Continue without account. Your data will be stored locally.',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _continueOffline,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[600]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Continue Offline',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.bold,
                ),
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
          const Icon(
            Icons.offline_bolt,
            color: Color(0xFF6c5ce7),
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Offline Mode Active',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your reading progress will be saved locally. Create an account later to sync across devices.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(
            color: Color(0xFF6c5ce7),
            strokeWidth: 3,
          ),
        ],
      ),
    );
  }
}