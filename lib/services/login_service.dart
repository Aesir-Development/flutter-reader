import 'package:http/http.dart' as http;
import 'dart:convert';
import 'sqlite_progress_service.dart';

class LoginService {
  static const String baseUrl = 'http://localhost:8080'; 
  
  // Login user and save token
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Save the JWT token
        await SQLiteProgressService.saveSetting('auth_token', data['token']);
        
        return data;
      } else {
        print('Login failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  // Register user and save token
  static Future<Map<String, dynamic>?> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        
        // Save the JWT token
        await SQLiteProgressService.saveSetting('auth_token', data['token']);
        
        return data;
      } else {
        print('Registration failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Registration error: $e');
      return null;
    }
  }

  // Get stored auth token
  static Future<String?> getAuthToken() async {
    return await SQLiteProgressService.getSetting('auth_token');
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  // Logout (clear token)
  static Future<void> logout() async {
    await SQLiteProgressService.deleteSetting('auth_token');
  }

  // Get headers with auth token for API calls
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}