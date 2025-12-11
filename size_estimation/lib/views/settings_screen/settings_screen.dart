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
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Hiệu chỉnh nâng cao',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Nhập thông số thủ công',
                          style: TextStyle(fontSize: 16)),
                      SizedBox(height: 4),
                      Text(
                        'Cảnh báo: Việc nhập sai thông số có thể làm giảm đáng kể độ chính xác.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      SizedBox(height: 12),
                      CalibrationInputWidget(),
                    ],
                  ),
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

  @override
  void dispose() {
    super.dispose();
  }
}

class CalibrationInputWidget extends StatefulWidget {
  final bool readOnly;
  const CalibrationInputWidget({super.key, this.readOnly = false});

  @override
  State<CalibrationInputWidget> createState() => _CalibrationInputWidgetState();
}

class _CalibrationInputWidgetState extends State<CalibrationInputWidget> {
  final Map<String, TextEditingController> _controllers = {};
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
    for (var key in _keys) {
      _controllers[key] = TextEditingController();
    }
    _loadValues();
  }

  Future<void> _loadValues() async {
    final prefs = await SharedPreferences.getInstance();
    for (var key in _keys) {
      final val = prefs.getString('calib_$key') ?? '';
      _controllers[key]?.text = val;
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveValue(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calib_$key', value);
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGroupHeader('Intrinsic Parameters'),
        Row(
          children: [
            _buildInput('fx', 'Focal X'),
            const SizedBox(width: 8),
            _buildInput('fy', 'Focal Y'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildInput('cx', 'Principal X'),
            const SizedBox(width: 8),
            _buildInput('cy', 'Principal Y'),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupHeader('Distortion Coefficients'),
        Row(
          children: [
            _buildInput('k1', 'k1'),
            const SizedBox(width: 8),
            _buildInput('k2', 'k2'),
            const SizedBox(width: 8),
            _buildInput('k3', 'k3'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildInput('p1', 'p1'),
            const SizedBox(width: 8),
            _buildInput('p2', 'p2'),
          ],
        ),
      ],
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }

  Widget _buildInput(String key, String label) {
    return Expanded(
      child: TextField(
        controller: _controllers[key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 13),
        readOnly: widget.readOnly,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: widget.readOnly
              ? const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black12))
              : const OutlineInputBorder(),
          filled: widget.readOnly,
          fillColor: widget.readOnly ? Colors.grey.withOpacity(0.05) : null,
        ),
        onChanged: (val) {
          if (!widget.readOnly) _saveValue(key, val);
        },
      ),
    );
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
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Intrinsic Parameters",
              style: TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildRow("Focal Length X (fx):", 'fx'),
          _buildRow("Focal Length Y (fy):", 'fy'),
          _buildRow("Principal Point X (cx):", 'cx'),
          _buildRow("Principal Point Y (cy):", 'cy'),
          const Divider(height: 24),
          const Text("Distortion Coefficients",
              style: TextStyle(
                  color: Colors.blueGrey,
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
