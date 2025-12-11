import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _aspectRatioIndex = 1; // Default to 4:3 (Index 1) usually
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _aspectRatioIndex = prefs.getInt('default_aspect_ratio') ?? 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveAspectRatio(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_aspect_ratio', index);
    setState(() {
      _aspectRatioIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Camera',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('Tỉ lệ khung hình mặc định'),
                  subtitle: Text(_getRatioLabel(_aspectRatioIndex)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showRatioSelectionDialog(),
                ),
                const Divider(),
              ],
            ),
    );
  }

  String _getRatioLabel(int index) {
    switch (index) {
      case 0:
        return '1:1 (Vuông)';
      case 1:
        return '4:3 (Tiêu chuẩn)';
      case 2:
        return '16:9 (Toàn màn hình)';
      default:
        return '4:3 (Tiêu chuẩn)';
    }
  }

  void _showRatioSelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chọn tỉ lệ khung hình'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<int>(
              title: const Text('1:1 (Vuông)'),
              value: 0,
              groupValue: _aspectRatioIndex,
              onChanged: (val) {
                if (val != null) {
                  _saveAspectRatio(val);
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<int>(
              title: const Text('4:3 (Tiêu chuẩn)'),
              value: 1,
              groupValue: _aspectRatioIndex,
              onChanged: (val) {
                if (val != null) {
                  _saveAspectRatio(val);
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<int>(
              title: const Text('16:9 (Toàn màn hình)'),
              value: 2,
              groupValue: _aspectRatioIndex,
              onChanged: (val) {
                if (val != null) {
                  _saveAspectRatio(val);
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
