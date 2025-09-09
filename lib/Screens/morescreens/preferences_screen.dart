import 'package:flutter/material.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({Key? key}) : super(key: key);

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  bool _darkMode = true;
  bool _notifications = true;
  bool _autoDownload = false;
  bool _wifiOnlyDownload = true;
  String _defaultLanguage = 'English';
  String _downloadQuality = 'High';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2a2a2a),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Preferences',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF6c5ce7).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.tune, color: Color(0xFF6c5ce7), size: 64),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'App Preferences',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Customize your app experience.',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            _buildAppearanceSection(),
            const SizedBox(height: 16),
            _buildNotificationSection(),
            const SizedBox(height: 16),
            _buildDownloadSection(),
            const SizedBox(height: 16),
            _buildLanguageSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appearance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSwitchTile(
            Icons.dark_mode,
            'Dark Mode',
            'Use dark theme throughout the app',
            _darkMode,
            (value) => setState(() => _darkMode = value),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSwitchTile(
            Icons.notifications,
            'Push Notifications',
            'Receive notifications for new chapters',
            _notifications,
            (value) => setState(() => _notifications = value),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Downloads',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSwitchTile(
            Icons.download,
            'Auto Download',
            'Automatically download new chapters',
            _autoDownload,
            (value) => setState(() => _autoDownload = value),
          ),
          const SizedBox(height: 8),
          _buildSwitchTile(
            Icons.wifi,
            'WiFi Only',
            'Download only when connected to WiFi',
            _wifiOnlyDownload,
            (value) => setState(() => _wifiOnlyDownload = value),
          ),
          const SizedBox(height: 16),
          _buildDropdownTile(
            Icons.high_quality,
            'Download Quality',
            'Choose image quality for downloads',
            _downloadQuality,
            ['Low', 'Medium', 'High', 'Original'],
            (value) => setState(() => _downloadQuality = value!),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Language & Region',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDropdownTile(
            Icons.language,
            'Default Language',
            'Preferred language for content',
            _defaultLanguage,
            ['English', 'Korean', 'Japanese', 'Chinese'],
            (value) => setState(() => _defaultLanguage = value!),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6c5ce7), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF6c5ce7),
          inactiveThumbColor: Colors.grey,
        ),
      ],
    );
  }

  Widget _buildDropdownTile(
    IconData icon,
    String title,
    String subtitle,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6c5ce7), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a1a),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF6c5ce7).withOpacity(0.3)),
          ),
          child: DropdownButton<String>(
            value: value,
            onChanged: onChanged,
            dropdownColor: const Color(0xFF2a2a2a),
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}