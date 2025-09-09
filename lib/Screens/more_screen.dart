import 'package:flutter/material.dart';
import 'morescreens/about_screen.dart';
import 'morescreens/local_backup_screen.dart';
import 'morescreens/categories_screen.dart';
import 'morescreens/statistics_screen.dart';
import 'morescreens/profile_screen.dart';
import 'morescreens/plugin_manager_screen.dart';
import 'morescreens/preferences_screen.dart';
import 'morescreens/reading_settings_screen.dart';
import 'morescreens/downloaded_chapters_screen.dart';
import 'morescreens/storage_usage_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline, color: Color(0xFF6c5ce7)),
            title: const Text(
              'About',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup, color: Color(0xFF6c5ce7)),
            title: const Text(
              'Local Backup',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LocalBackupScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.category, color: Color(0xFF6c5ce7)),
            title: const Text(
              'Categories',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CategoriesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart, color: Color(0xFF6c5ce7)),
            title: const Text(
              'Statistics',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatisticsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download, color: Color(0xFF6c5ce7)),
            title: const Text(
              'Downloaded Chapters',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DownloadedChaptersScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage, color: Color(0xFF6c5ce7)),
            title: const Text(
              'Storage Usage',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StorageUsageScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Color(0xFF6c5ce7)),
            title: const Text(
              'Profile',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.extension, color: Color(0xFF6c5ce7)),
            title: const Text(
              'Plugin Manager',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PluginManagerScreen()),
              );
            },
          ),
          ExpansionTile(
            leading: const Icon(Icons.settings, color: Color(0xFF6c5ce7)),
            title: const Text(
              'Settings',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            children: [
              ListTile(
                leading: const Icon(Icons.tune, color: Color(0xFF6c5ce7)),
                title: const Text(
                  'Preferences',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PreferencesScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.chrome_reader_mode, color: Color(0xFF6c5ce7)),
                title: const Text(
                  'Reading Settings',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReadingSettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
