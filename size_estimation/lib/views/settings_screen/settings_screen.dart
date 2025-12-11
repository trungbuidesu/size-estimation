import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _aspectRatioIndex = 1; // Default to 4:3 (Index 1) usually
  List<int> _timerPresets = [3, 5, 10];
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
          final List<String>? presets = prefs.getStringList('timer_presets');
          if (presets != null && presets.length == 3) {
            _timerPresets = presets.map((e) => int.tryParse(e) ?? 10).toList();
          }
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

  Future<void> _saveTimerPreset(int slotIndex, int value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _timerPresets[slotIndex] = value;
    });
    await prefs.setStringList(
        'timer_presets', _timerPresets.map((e) => e.toString()).toList());
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Bộ đếm giờ (Countdown)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ...List.generate(3, (index) {
                  return ListTile(
                    title: Text('Mức ${index + 1}'),
                    subtitle: Text('${_timerPresets[index]} giây'),
                    trailing: const Icon(Icons.edit, size: 16),
                    onTap: () => _showTimerPicker(index, _timerPresets[index]),
                  );
                }),
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

  void _showTimerPicker(int slotIndex, int currentValue) {
    int selectedValue = currentValue;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Chọn thời gian mức ${slotIndex + 1}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$selectedValue giây',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: selectedValue.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: selectedValue.toString(),
                    onChanged: (double value) {
                      setDialogState(() {
                        selectedValue = value.round();
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: () {
                    _saveTimerPreset(slotIndex, selectedValue);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
