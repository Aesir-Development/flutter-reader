import 'package:flutter/material.dart';

class ReadingSettingsScreen extends StatefulWidget {
  const ReadingSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ReadingSettingsScreen> createState() => _ReadingSettingsScreenState();
}

class _ReadingSettingsScreenState extends State<ReadingSettingsScreen> {
  String _readingMode = 'Vertical';
  double _brightness = 0.8;
  double _imageScale = 1.0;
  bool _hapticFeedback = true;
  bool _fullScreenReading = false;
  bool _keepScreenOn = true;
  String _tapToTurn = 'Right Side';

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
          'Reading Settings',
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
                child: const Icon(Icons.chrome_reader_mode, color: Color(0xFF6c5ce7), size: 64),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Reading Settings',
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
                'Customize your reading experience.',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            _buildReadingModeSection(),
            const SizedBox(height: 16),
            _buildVisualSection(),
            const SizedBox(height: 16),
            _buildInteractionSection(),
            const SizedBox(height: 16),
            _buildDisplaySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingModeSection() {
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
            'Reading Mode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDropdownTile(
            Icons.view_agenda,
            'Reading Direction',
            'How pages are displayed',
            _readingMode,
            ['Vertical', 'Horizontal', 'Webtoon'],
            (value) => setState(() => _readingMode = value!),
          ),
          const SizedBox(height: 16),
          _buildDropdownTile(
            Icons.touch_app,
            'Tap to Turn Page',
            'Which side advances pages',
            _tapToTurn,
            ['Right Side', 'Left Side', 'Both Sides', 'Disabled'],
            (value) => setState(() => _tapToTurn = value!),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualSection() {
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
            'Visual Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSliderTile(
            Icons.brightness_6,
            'Brightness',
            'Adjust reading brightness',
            _brightness,
            0.3,
            1.0,
            (value) => setState(() => _brightness = value),
          ),
          const SizedBox(height: 16),
          _buildSliderTile(
            Icons.zoom_in,
            'Image Scale',
            'Zoom level for images',
            _imageScale,
            0.5,
            2.0,
            (value) => setState(() => _imageScale = value),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionSection() {
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
            'Interaction',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSwitchTile(
            Icons.vibration,
            'Haptic Feedback',
            'Vibrate on page turns and interactions',
            _hapticFeedback,
            (value) => setState(() => _hapticFeedback = value),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplaySection() {
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
            'Display',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSwitchTile(
            Icons.fullscreen,
            'Fullscreen Reading',
            'Hide status bar while reading',
            _fullScreenReading,
            (value) => setState(() => _fullScreenReading = value),
          ),
          const SizedBox(height: 8),
          _buildSwitchTile(
            Icons.screen_lock_portrait,
            'Keep Screen On',
            'Prevent screen from turning off while reading',
            _keepScreenOn,
            (value) => setState(() => _keepScreenOn = value),
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

  Widget _buildSliderTile(
    IconData icon,
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6c5ce7).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFF6c5ce7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF6c5ce7),
            inactiveTrackColor: Colors.grey[700],
            thumbColor: const Color(0xFF6c5ce7),
            overlayColor: const Color(0xFF6c5ce7).withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
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