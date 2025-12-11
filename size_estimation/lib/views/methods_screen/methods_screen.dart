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
  bool _isCalibrationExpanded = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
                  onLongPress: _showArInfoSheet,
                  cardColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.7),
                  textColor: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
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
                  setState(() => _isCalibrationExpanded = false);
                } else {
                  if (isRightSide) {
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
                    _showCalibrationActionDialog(context);
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
                  const CalibrationDisplayWidget(),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _showCalibrationActionDialog(context),
                    icon: const Icon(Icons.animation),
                    label: const Text('Hiệu chỉnh'),
                  )
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  void _showCalibrationActionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => CalibrationDescDialog(
        onConfirm: _checkAndConfirmCalibration,
      ),
    );
  }

  Future<void> _checkAndConfirmCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    // Keys for automatic calibration profile (distinct from 'calib_' for manual)
    final requiredKeys = ['fx', 'fy', 'cx', 'cy', 'k1', 'k2', 'p1', 'p2', 'k3'];

    // Check if ALL keys exist and are not empty
    bool hasAutoProfile = requiredKeys.every((key) {
      final val = prefs.getString('auto_calib_$key');
      return val != null && val.trim().isNotEmpty;
    });

    if (!mounted) return;

    if (hasAutoProfile) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Xác nhận ghi đè"),
          content: const Text(
              "Đã tồn tại hồ sơ hiệu chỉnh tự động trước đó. Bạn có muốn thực hiện lại và ghi đè không?"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
            FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _startCalibrationProcess();
                },
                child: const Text("Ghi đè & Bắt đầu")),
          ],
        ),
      );
    } else {
      _startCalibrationProcess();
    }
  }

  void _startCalibrationProcess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Bắt đầu quy trình hiệu chỉnh... (TODO)")),
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
