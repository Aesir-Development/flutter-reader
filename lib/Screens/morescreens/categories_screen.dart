import 'package:flutter/material.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  @override
  State<CategoriesScreen> createState() => _CustomCategoriesScreenState();
}

class _CustomCategoriesScreenState extends State<CategoriesScreen> {
  final List<Map<String, dynamic>> _customCategories = [
    {
      'id': '1',
      'name': 'Currently Reading',
      'icon': Icons.menu_book,
      'color': Colors.blue,
      'count': 5,
      'isDefault': true,
    },
    {
      'id': '2', 
      'name': 'Favorites',
      'icon': Icons.favorite,
      'color': Colors.red,
      'count': 8,
      'isDefault': true,
    },
    {
      'id': '3',
      'name': 'Plan to Read',
      'icon': Icons.bookmark_border,
      'color': Colors.orange,
      'count': 12,
      'isDefault': true,
    },
    {
      'id': '4',
      'name': 'Completed',
      'icon': Icons.check_circle,
      'color': Colors.green,
      'count': 3,
      'isDefault': true,
    },
    {
      'id': '5',
      'name': 'Action Packed',
      'icon': Icons.flash_on,
      'color': Colors.purple,
      'count': 6,
      'isDefault': false,
    },
  ];

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
          'Custom Categories',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showAddCategoryDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildDefaultCategoriesSection(),
            const SizedBox(height: 24),
            _buildCustomCategoriesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6c5ce7).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6c5ce7).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.collections_bookmark, color: Color(0xFF6c5ce7), size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Organize Your Library',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create custom categories to organize your manhwa. These will appear as tabs in your library.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultCategoriesSection() {
    final defaultCategories = _customCategories.where((cat) => cat['isDefault'] == true).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star, color: Color(0xFF6c5ce7), size: 20),
            const SizedBox(width: 8),
            const Text(
              'Default Categories',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Text(
                'Built-in',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'These categories are always available and cannot be deleted.',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        ...defaultCategories.map((category) => _buildCategoryTile(category, isDefault: true)).toList(),
      ],
    );
  }

  Widget _buildCustomCategoriesSection() {
    final customCategories = _customCategories.where((cat) => cat['isDefault'] == false).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.create, color: Color(0xFF6c5ce7), size: 20),
            const SizedBox(width: 8),
            const Text(
              'Custom Categories',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6c5ce7).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF6c5ce7).withOpacity(0.3)),
              ),
              child: Text(
                '${customCategories.length}',
                style: const TextStyle(
                  color: Color(0xFF6c5ce7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Create your own categories to organize manhwa however you like.',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        if (customCategories.isEmpty) 
          _buildEmptyCustomCategories()
        else
          ...customCategories.map((category) => _buildCategoryTile(category, isDefault: false)).toList(),
      ],
    );
  }

  Widget _buildEmptyCustomCategories() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.add_circle_outline, color: Colors.grey[400], size: 48),
          const SizedBox(height: 12),
          Text(
            'No Custom Categories Yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to create your first custom category.',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> category, {required bool isDefault}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (category['color'] as Color).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(category['icon'], color: category['color'], size: 20),
        ),
        title: Text(
          category['name'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${category['count']} manhwas',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDefault) ...[
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey, size: 18),
                onPressed: () => _showEditCategoryDialog(category),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                onPressed: () => _showDeleteConfirmation(category),
              ),
            ] else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'DEFAULT',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.drag_handle, color: Colors.grey, size: 18),
          ],
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Managing "${category['name']}" category'),
              backgroundColor: const Color(0xFF2a2a2a),
            ),
          );
        },
      ),
    );
  }

  void _showAddCategoryDialog() {
    String name = '';
    IconData selectedIcon = Icons.bookmark;
    Color selectedColor = Colors.blue;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a2a),
          title: const Text(
            'Create Category',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category Name', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => name = value,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter category name',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFF1a1a1a),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Icon', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              _buildIconSelector(selectedIcon, (icon) {
                setDialogState(() => selectedIcon = icon);
              }),
              const SizedBox(height: 16),
              const Text('Color', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              _buildColorSelector(selectedColor, (color) {
                setDialogState(() => selectedColor = color);
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: name.isNotEmpty ? () {
                _addCategory(name, selectedIcon, selectedColor);
                Navigator.pop(context);
              } : null,
              child: const Text('Create', style: TextStyle(color: Color(0xFF6c5ce7))),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(Map<String, dynamic> category) {
    String name = category['name'];
    IconData selectedIcon = category['icon'];
    Color selectedColor = category['color'];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2a2a2a),
          title: const Text(
            'Edit Category',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category Name', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: name),
                onChanged: (value) => name = value,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter category name',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFF1a1a1a),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Icon', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              _buildIconSelector(selectedIcon, (icon) {
                setDialogState(() => selectedIcon = icon);
              }),
              const SizedBox(height: 16),
              const Text('Color', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              _buildColorSelector(selectedColor, (color) {
                setDialogState(() => selectedColor = color);
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: name.isNotEmpty ? () {
                _editCategory(category['id'], name, selectedIcon, selectedColor);
                Navigator.pop(context);
              } : null,
              child: const Text('Save', style: TextStyle(color: Color(0xFF6c5ce7))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconSelector(IconData selectedIcon, Function(IconData) onIconSelected) {
    final icons = [
      Icons.bookmark, Icons.favorite, Icons.star, Icons.flash_on,
      Icons.auto_awesome, Icons.schedule, Icons.trending_up, Icons.emoji_events,
      Icons.local_fire_department, Icons.psychology, Icons.explore, Icons.school,
    ];
    
    return Wrap(
      spacing: 8,
      children: icons.map((icon) {
        final isSelected = icon == selectedIcon;
        return GestureDetector(
          onTap: () => onIconSelected(icon),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF6c5ce7) : const Color(0xFF1a1a1a),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? const Color(0xFF6c5ce7) : Colors.grey[600]!,
              ),
            ),
            child: Icon(icon, color: isSelected ? Colors.white : Colors.grey[400], size: 20),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorSelector(Color selectedColor, Function(Color) onColorSelected) {
    final colors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange,
      Colors.purple, Colors.pink, Colors.teal, Colors.indigo,
    ];
    
    return Wrap(
      spacing: 8,
      children: colors.map((color) {
        final isSelected = color == selectedColor;
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
          ),
        );
      }).toList(),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text('Delete Category', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${category['name']}"? This action cannot be undone.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              _deleteCategory(category['id']);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addCategory(String name, IconData icon, Color color) {
    setState(() {
      _customCategories.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
        'icon': icon,
        'color': color,
        'count': 0,
        'isDefault': false,
      });
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Created category "$name"'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _editCategory(String id, String name, IconData icon, Color color) {
    setState(() {
      final index = _customCategories.indexWhere((cat) => cat['id'] == id);
      if (index != -1) {
        _customCategories[index] = {
          ..._customCategories[index],
          'name': name,
          'icon': icon,
          'color': color,
        };
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Updated category "$name"'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _deleteCategory(String id) {
    final category = _customCategories.firstWhere((cat) => cat['id'] == id);
    setState(() {
      _customCategories.removeWhere((cat) => cat['id'] == id);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted category "${category['name']}"'),
        backgroundColor: Colors.red,
      ),
    );
  }
}