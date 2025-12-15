import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:size_estimation/constants/index.dart';
import 'package:size_estimation/views/camera_property/index.dart';
import 'package:size_estimation/views/settings_screen/settings_screen.dart';
import 'package:size_estimation/views/methods_screen/components/index.dart';
import 'package:size_estimation/models/calibration_profile.dart';
import 'package:size_estimation/services/calibration_service.dart';
import 'package:size_estimation/views/calibration_playground/profile_selection_dialog.dart';

class MethodsScreen extends StatefulWidget {
  const MethodsScreen({super.key});

  @override
  State<MethodsScreen> createState() => _MethodsScreenState();
}

class _MethodsScreenState extends State<MethodsScreen> {
  static const MethodChannel _cameraChannel =
      MethodChannel('com.example.size_estimation/camera_utils');
  bool _useAdvancedCorrection = false;
  bool _isCalibrationExpanded = false;
  CalibrationProfile? _selectedProfile;
  final CalibrationService _calibrationService = CalibrationService();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void initState() {
    super.initState();
    _loadActiveProfile();
  }

  Future<void> _loadActiveProfile() async {
    final profile = await _calibrationService.getActiveProfile();
    if (profile != null && mounted) {
      setState(() {
        _selectedProfile = profile;
        _useAdvancedCorrection = true;
      });
    }
  }

  Future<void> _onSelectMultiImage() async {
    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    String profileName = "Mặc định (Device Intrinsics)";
    Map<String, String> params = {};
    List<double>? distortion;

    try {
      if (_useAdvancedCorrection && _selectedProfile != null) {
        profileName = _selectedProfile!.name;

        params['fx'] = _selectedProfile!.fx.toString();
        params['fy'] = _selectedProfile!.fy.toString();
        params['cx'] = _selectedProfile!.cx.toString();
        params['cy'] = _selectedProfile!.cy.toString();

        if (_selectedProfile!.distortionCoefficients.isNotEmpty) {
          distortion = _selectedProfile!.distortionCoefficients;
        }
      } else {
        // Fetch from Camera2 API via MethodChannel
        final Map<dynamic, dynamic> result = await _cameraChannel
            .invokeMethod('getCameraProperties', {'cameraId': '0'});

        final properties = result.cast<String, dynamic>();

        // Parse LENS_INTRINSIC_CALIBRATION [fx, fy, cx, cy, s]
        if (properties['LENS_INTRINSIC_CALIBRATION'] != null) {
          var val = properties['LENS_INTRINSIC_CALIBRATION'];
          List<dynamic> intrinsics = [];
          if (val is List) {
            intrinsics = val;
          } else if (val is String) {
            intrinsics = val
                .replaceAll('[', '')
                .replaceAll(']', '')
                .split(',')
                .map((e) => e.trim())
                .toList();
          }

          if (intrinsics.length >= 5) {
            params['fx'] = intrinsics[0].toString();
            params['fy'] = intrinsics[1].toString();
            params['cx'] = intrinsics[2].toString();
            params['cy'] = intrinsics[3].toString();
            params['s'] = intrinsics[4].toString();
          }
        }

        // Parse LENS_RADIAL_DISTORTION [k1, k2, k3, k4, k5, k6]
        if (properties['LENS_RADIAL_DISTORTION'] != null) {
          var val = properties['LENS_RADIAL_DISTORTION'];
          List<dynamic> rawDist = [];

          if (val is List) {
            rawDist = val;
          } else if (val is String) {
            rawDist = val
                .replaceAll('[', '')
                .replaceAll(']', '')
                .split(',')
                .map((e) => e.trim())
                .toList();
          }

          try {
            distortion = rawDist
                .map((e) => double.tryParse(e.toString()) ?? 0.0)
                .toList();
          } catch (e) {
            debugPrint("Error parsing distortion: $e");
          }
        }

        if (params.isEmpty) {
          params['Status'] = "Không thể đọc thông số từ Camera API";
        }
      }
    } catch (e) {
      debugPrint("Error fetching params: $e");
      params['Error'] = "Lỗi: ${e.toString()}";
    } finally {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings_input_component, color: Colors.blue),
            SizedBox(width: 8),
            Text("Kiểm tra thông số"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _useAdvancedCorrection
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color:
                          _useAdvancedCorrection ? Colors.orange : Colors.blue),
                ),
                child: Text(
                  profileName,
                  style: TextStyle(
                    color: _useAdvancedCorrection
                        ? Colors.orange[800]
                        : Colors.blue[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text("Intrinsics (Pinhole Model)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Divider(height: 8),
              if (params.containsKey('Error'))
                Text(params['Error']!,
                    style: const TextStyle(color: Colors.red, fontSize: 12))
              else if (params.containsKey('Status'))
                Text(params['Status']!,
                    style: const TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 12))
              else ...[
                _buildParamRow("Focal Length X (fx)", params['fx'] ?? 'N/A'),
                _buildParamRow("Focal Length Y (fy)", params['fy'] ?? 'N/A'),
                _buildParamRow("Principal Point X (cx)", params['cx'] ?? 'N/A'),
                _buildParamRow("Principal Point Y (cy)", params['cy'] ?? 'N/A'),
                if (params.containsKey('s'))
                  _buildParamRow("Skew (s)", params['s'] ?? 'N/A'),
              ],
              if (distortion != null && distortion.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text("Distortion (Radial)",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Divider(height: 8),
                Text(
                  distortion.join(', '),
                  style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      color: Colors.black87),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                "Nhấn 'Bắt đầu' để sử dụng các thông số này.",
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Quay lại"),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/${RouteNames.camera}');
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text("Bắt đầu"),
          ),
        ],
      ),
    );
  }

  Widget _buildParamRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _selectProfile() async {
    final selected = await showDialog<CalibrationProfile>(
      context: context,
      builder: (context) => ProfileSelectionDialog(
        currentProfile: _selectedProfile,
      ),
    );

    if (selected != null) {
      await _calibrationService.setActiveProfile(selected.name);
      setState(() {
        _selectedProfile = selected;
        _useAdvancedCorrection = true;
      });
    } else if (selected == null && _selectedProfile != null) {
      // User cleared selection
      await _calibrationService.clearActiveProfile();
      setState(() {
        _selectedProfile = null;
        _useAdvancedCorrection = false;
      });
    }
  }

  void _onShowTutorial() {
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mở tutorial (TODO: liên kết tới màn hướng dẫn)'),
      ),
    );
  }

  void _showMultiImageInfoSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, controller) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ListView(
                controller: controller,
                children: [
                  const Text(
                    'Nhiều ảnh từ các góc độ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '- Chụp/tải nhiều ảnh ở các góc khác nhau.\n'
                    '- Hệ thống xử lý ảnh để ước lượng kích thước/khối tích.\n'
                    '- Hoạt động trên hầu hết thiết bị, không cần AR.',
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Mẹo nhanh:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '- Chụp 4-6 góc (trước/sau/trái/phải/chéo trên/dưới).\n'
                    '- Đủ sáng, tránh bóng gắt.\n'
                    '- Có vật chuẩn kích thước (thẻ, tờ A4) càng tốt.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _onShowTutorial,
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Xem hướng dẫn chi tiết'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCameraProperties() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                controller: controller, // Attach controller for dragging
                child: const CameraPropertiesWidget(),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleAdvancedSwitch(bool value) async {
    if (!value) {
      await _calibrationService.clearActiveProfile();
      setState(() {
        _useAdvancedCorrection = false;
        _selectedProfile = null;
      });
      return;
    }

    // Show profile selection dialog
    await _selectProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chức năng chính'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Cài đặt',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.perm_device_information),
            tooltip: 'Thuộc tính Camera',
            onPressed: _showCameraProperties,
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Đo kích thước vật thể',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 8),
                const SizedBox(height: 16),
                _buildMethodCard(
                  context: context,
                  title: 'Ước lượng bằng nhiều ảnh',
                  subtitle: 'Chụp nhiều góc độ để xử lý.',
                  icon: Icons.photo_library_outlined,
                  onTap: _onSelectMultiImage,
                  onLongPress: _showMultiImageInfoSheet,
                  cardColor: Theme.of(context)
                      .colorScheme
                      .tertiaryContainer
                      .withOpacity(0.7),
                  textColor: Theme.of(context).colorScheme.onTertiaryContainer,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'Sử dụng hiệu chỉnh ảnh nâng cao',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Switch(
                        value: _useAdvancedCorrection,
                        onChanged: _handleAdvancedSwitch,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Công cụ nâng cao',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _buildCalibrationCard(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalibrationCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = colorScheme.secondaryContainer.withOpacity(0.7);
    final onBackgroundColor = colorScheme.onSecondaryContainer;

    return Card(
      color: backgroundColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          LayoutBuilder(builder: (context, constraints) {
            return InkWell(
              onLongPress: () {
                showDialog(
                  context: context,
                  builder: (ctx) =>
                      const CalibrationDescDialog(onConfirm: null),
                );
              },
              onTap: () {},
              onTapUp: (details) {
                final isRightSide =
                    details.localPosition.dx > constraints.maxWidth - 56;

                if (_isCalibrationExpanded) {
                  // When expanded, collapse on any tap
                  setState(() => _isCalibrationExpanded = false);
                } else {
                  if (isRightSide) {
                    // Tap on expand icon - expand to show settings
                    setState(() => _isCalibrationExpanded = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      await Future.delayed(const Duration(milliseconds: 100));
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                  } else {
                    // Tap on main area - go to Calibration Playground
                    context.push('/calibration-playground');
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.perm_data_setting_outlined,
                        size: 32, color: onBackgroundColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Hiệu chỉnh ảnh nâng cao',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: onBackgroundColor,
                        ),
                      ),
                    ),
                    Icon(
                      _isCalibrationExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: onBackgroundColor,
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_isCalibrationExpanded) ...[
            Divider(color: onBackgroundColor.withOpacity(0.1), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Switch to enable/disable Advanced Correction
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Use Advanced Correction',
                              style: TextStyle(
                                color: onBackgroundColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (_selectedProfile != null)
                              Text(
                                'Profile: ${_selectedProfile!.name}',
                                style: TextStyle(
                                  color: onBackgroundColor.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _useAdvancedCorrection,
                        onChanged: _handleAdvancedSwitch,
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Button to select profile
                  if (_useAdvancedCorrection)
                    OutlinedButton.icon(
                      onPressed: _selectProfile,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: Text(_selectedProfile == null
                          ? 'Select Profile'
                          : 'Change Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: onBackgroundColor,
                        side: BorderSide(
                            color: onBackgroundColor.withOpacity(0.3)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const CalibrationDisplayWidget(),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.push('/calibration-playground'),
                    icon: const Icon(Icons.science),
                    label: const Text('Calibration Playground'),
                  )
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    required VoidCallback? onLongPress,
    required Color cardColor,
    required Color textColor,
    Widget? child,
  }) {
    final isEnabled = onTap != null;
    // Visually disable if not enabled
    final effectiveBackgroundColor = isEnabled
        ? cardColor
        : Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.5);
    final effectiveTextColor = isEnabled
        ? textColor
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.38);

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: effectiveTextColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: effectiveTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: effectiveTextColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (child != null) ...[
            const Spacer(),
            child,
          ] else ...[
            const Spacer(),
            if (!isEnabled)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Không khả dụng trên thiết bị này',
                  style: TextStyle(
                      color: effectiveTextColor.withOpacity(0.6),
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.arrow_forward,
                    color: effectiveTextColor.withOpacity(0.5)),
              ),
          ],
        ],
      ),
    );

    return SizedBox(
      height: 170,
      child: Card(
        color: effectiveBackgroundColor,
        elevation: isEnabled ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: isEnabled
            ? InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                child: content,
              )
            : GestureDetector(
                onLongPress: onLongPress,
                behavior: HitTestBehavior.opaque,
                child: SizedBox.expand(child: content),
              ),
      ),
    );
  }
}
