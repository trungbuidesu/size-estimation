import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:size_estimation/constants/index.dart';
import 'package:size_estimation/views/camera_property/index.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:size_estimation/views/settings_screen/settings_screen.dart';
import 'package:size_estimation/views/methods_screen/components/index.dart';

class MethodsScreen extends StatefulWidget {
  const MethodsScreen({super.key});

  @override
  State<MethodsScreen> createState() => _MethodsScreenState();
}

class _MethodsScreenState extends State<MethodsScreen> {
  static const MethodChannel _arChannel =
      MethodChannel('com.example.size_estimation/arcore');
  bool _isCheckingSupport = false;
  bool _isArSupported = false;
  bool _useAdvancedCorrection = false;

  @override
  void initState() {
    super.initState();
    _detectArSupport();
  }

  Future<void> _detectArSupport() async {
    setState(() => _isCheckingSupport = true);

    bool supported = false;
    if (Platform.isAndroid) {
      try {
        final bool? result =
            await _arChannel.invokeMethod<bool>('checkArSupport');
        supported = result ?? false;
      } on PlatformException catch (_) {
        supported = false;
      }
    } else {
      supported = false;
    }

    if (!mounted) return;
    setState(() {
      _isArSupported = supported;
      _isCheckingSupport = false;
    });
  }

  void _onSelectArCore() {
    if (!_isArSupported) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bắt đầu ước lượng bằng ARCore')),
    );
    // TODO: Điều hướng tới flow ARCore thực tế.
  }

  void _onSelectMultiImage() {
    context.push('/${RouteNames.camera}');
  }

  void _onShowTutorial() {
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mở tutorial (TODO: liên kết tới màn hướng dẫn)'),
      ),
    );
  }

  void _showArInfoSheet() {
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
                    'ARCore (đo trực tiếp)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '- Dựng mặt phẳng bằng cảm biến + camera.\n'
                    '- Đo kích thước vật thể ngay trong không gian thực.\n'
                    '- Cần thiết bị hỗ trợ ARCore và bật cảm biến chuyển động.',
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Mẹo nhanh:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '- Quét mặt phẳng kỹ trước khi đo.\n'
                    '- Đủ sáng, giữ máy ổn định.\n'
                    '- Chọn vật tham chiếu nếu có.',
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
      setState(() => _useAdvancedCorrection = false);
      return;
    }

    // Check for manual profile
    final prefs = await SharedPreferences.getInstance();
    final requiredKeys = ['fx', 'fy', 'cx', 'cy'];
    bool isManualConfigured = requiredKeys.every((key) {
      final val = prefs.getString('calib_$key');
      return val != null && val.trim().isNotEmpty;
    });

    // Simulate checking for automatic profile
    bool hasProfile = false;

    if (!mounted) return;
    _showCalibrationProfileDialog(hasProfile, isManualConfigured);
  }

  void _showCalibrationProfileDialog(bool hasProfile, bool isManualConfigured) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chọn hồ sơ hiệu chỉnh'),
        content: SizedBox(
          width: double.maxFinite,
          child: Scrollbar(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hồ sơ thủ công (User Manual)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const CalibrationDisplayWidget(),
                  const SizedBox(height: 12),
                  Center(
                    child: FilledButton.icon(
                      onPressed: isManualConfigured
                          ? () {
                              Navigator.pop(ctx);
                              setState(() => _useAdvancedCorrection = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Đã chọn hồ sơ thủ công')),
                              );
                            }
                          : null,
                      icon: isManualConfigured
                          ? const Icon(Icons.check)
                          : const Icon(Icons.warning_amber_rounded),
                      label: Text(
                          isManualConfigured
                              ? "Sử dụng Profile này"
                              : "Chưa thiết lập\n(Vào Cài đặt để nhập)",
                          textAlign: TextAlign.center),
                    ),
                  ),
                  const Divider(height: 32),
                  const Text('Hồ sơ tự động (System)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (hasProfile) ...[
                    ListTile(
                      title: const Text("Auto-Calibration 2024-12-10"),
                      subtitle: const Text("RMS: 0.45 | Focal: 3050px"),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _useAdvancedCorrection = true);
                      },
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Chưa có hồ sơ hiệu chỉnh nào khác.',
                          style: TextStyle(
                              color: Colors.grey, fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Chọn phương pháp ước lượng',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMethodCard(
                            context: context,
                            title: _isCheckingSupport
                                ? 'Đang kiểm tra ARCore...'
                                : _isArSupported
                                    ? 'Ước lượng bằng ARCore'
                                    : 'ARCore không khả dụng',
                            subtitle: _isCheckingSupport
                                ? 'Đang xác thực khả năng hỗ trợ...'
                                : _isArSupported
                                    ? 'Thiết bị hỗ trợ. Đo trực tiếp.'
                                    : 'Thiết bị không hỗ trợ. Hãy dùng ảnh.',
                            icon: Icons.view_in_ar,
                            onTap: (_isArSupported && !_isCheckingSupport)
                                ? _onSelectArCore
                                : null,
                            isPrimary: _isArSupported,
                          ),
                          const SizedBox(height: 16),
                          _buildMethodCard(
                            context: context,
                            title: 'Ước lượng bằng nhiều ảnh',
                            subtitle: 'Chụp nhiều góc độ để xử lý.',
                            icon: Icons.photo_library_outlined,
                            onTap: _onSelectMultiImage,
                            isPrimary: false,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Flexible(
                                        child: Text(
                                          'Sử dụng hiệu chỉnh ảnh nâng cao',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) =>
                                                const CalibrationDescDialog(),
                                          );
                                        },
                                        child: const Icon(Icons.info_outline,
                                            size: 18, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _useAdvancedCorrection,
                                  onChanged: _handleAdvancedSwitch,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    required bool isPrimary,
    Widget? child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isPrimary
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final onBackgroundColor = isPrimary
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return SizedBox(
      height: 170, // Fixed height for consistency
      child: Card(
        color: backgroundColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isPrimary
              ? BorderSide.none
              : BorderSide(color: colorScheme.outline.withOpacity(0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: isPrimary ? _showArInfoSheet : _showMultiImageInfoSheet,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 32, color: onBackgroundColor),
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
                              color: onBackgroundColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: onBackgroundColor.withOpacity(0.8),
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
                  if (onTap == null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Không khả dụng',
                        style: TextStyle(
                            color: onBackgroundColor.withOpacity(0.5),
                            fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.arrow_forward,
                          color: onBackgroundColor.withOpacity(0.5)),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
