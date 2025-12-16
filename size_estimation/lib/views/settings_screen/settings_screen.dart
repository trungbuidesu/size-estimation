import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:size_estimation/views/shared_components/index.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
                const Divider(),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Bộ đếm giờ (Countdown)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
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
              ],
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
            return CommonAlertDialog(
              title: 'Chọn thời gian mức ${slotIndex + 1}',
              icon: Icons.timer,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$selectedValue giây',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                  Slider(
                    value: selectedValue.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: selectedValue.toString(),
                    activeColor: Theme.of(context).colorScheme.primary,
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
                FilledButton(
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

  @override
  void dispose() {
    super.dispose();
  }
}

class CalibrationDisplayWidget extends StatefulWidget {
  const CalibrationDisplayWidget({super.key});

  @override
  State<CalibrationDisplayWidget> createState() =>
      _CalibrationDisplayWidgetState();
}

class _CalibrationDisplayWidgetState extends State<CalibrationDisplayWidget> {
  Map<String, String> _values = {};
  final List<String> _keys = [
    'fx',
    'fy',
    'cx',
    'cy',
    'k1',
    'k2',
    'p1',
    'p2',
    'k3'
  ];

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  Future<void> _loadValues() async {
    final prefs = await SharedPreferences.getInstance();
    final newValues = <String, String>{};
    for (var key in _keys) {
      final val = prefs.getString('calib_$key');
      newValues[key] = (val == null || val.trim().isEmpty) ? '-' : val;
    }
    if (mounted) setState(() => _values = newValues);
  }

  Widget _buildRow(String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(_values[key] ?? '-', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCompact(String label, String key) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(_values[key] ?? '-', style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_values.isEmpty)
      return const SizedBox(
          height: 100, child: Center(child: CircularProgressIndicator()));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Intrinsic Parameters",
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildRow("Focal Length X (fx):", 'fx'),
          _buildRow("Focal Length Y (fy):", 'fy'),
          _buildRow("Principal Point X (cx):", 'cx'),
          _buildRow("Principal Point Y (cy):", 'cy'),
          const Divider(height: 24),
          Text("Distortion Coefficients",
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 16, runSpacing: 8, children: [
            _buildCompact("k1", 'k1'),
            _buildCompact("k2", 'k2'),
            _buildCompact("k3", 'k3'),
            _buildCompact("p1", 'p1'),
            _buildCompact("p2", 'p2'),
          ])
        ],
      ),
    );
  }
}
