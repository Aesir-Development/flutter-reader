import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'dart:convert'; // For JsonDecoder
import 'package:path/path.dart' as path; // For basenameWithoutExtension
import '../services/plugin_service.dart'; // Import your PluginService (adjust path)

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({Key? key}) : super(key: key);

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  List<String> plugins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlugins();
  }

  Future<void> _loadPlugins() async {
    setState(() => _isLoading = true);
    try {
      plugins = await PluginService.getPluginNames();
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading plugins: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load plugins: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: RefreshIndicator(
        onRefresh: _loadPlugins,
        color: const Color(0xFF6c5ce7),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6c5ce7)),
      );
    }

    if (plugins.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.extension_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No plugins found',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check the plugins folder in assets',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPlugins,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6c5ce7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Refresh',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: plugins.length,
      itemBuilder: (context, index) {
        final pluginName = plugins[index];
        return _buildPluginTile(pluginName);
      },
    );
  }

  Widget _buildPluginTile(String pluginName) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      color: const Color(0xFF2a2a2a),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[800]!),
      ),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF6c5ce7).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.extension,
            color: Color(0xFF6c5ce7),
            size: 24,
          ),
        ),
        title: Text(
          pluginName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Text(
          'Plugin for browsing content', 
          style: TextStyle(color: Colors.grey),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey,
          size: 16,
        ),
        onTap: () {
          // TODO: Navigate to plugin details or activate it
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Selected: $pluginName')),
          );
        },
      ),
    );
  }
}