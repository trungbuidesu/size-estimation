import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:size_estimation/constants/index.dart';

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn phương pháp ước lượng'),
        centerTitle: true,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isCheckingSupport
                              ? 'Đang kiểm tra thiết bị có hỗ trợ ARCore...'
                              : _isArSupported
                                  ? 'Thiết bị hỗ trợ ARCore. Bạn có thể dùng đo trực tiếp.'
                                  : 'Thiết bị không hỗ trợ ARCore. Vui lòng dùng phương pháp ảnh.',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Kiểm tra lại',
                        onPressed: _isCheckingSupport ? null : _detectArSupport,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GestureDetector(
                            onLongPress: _showArInfoSheet,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.view_in_ar, size: 24),
                              onPressed: (_isArSupported && !_isCheckingSupport)
                                  ? _onSelectArCore
                                  : null,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(72),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                              label: Text(
                                _isCheckingSupport
                                    ? 'Đang kiểm tra ARCore...'
                                    : _isArSupported
                                        ? 'Ước lượng bằng ARCore'
                                        : 'ARCore không khả dụng',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onLongPress: _showMultiImageInfoSheet,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.photo_library_outlined,
                                  size: 24),
                              onPressed: _onSelectMultiImage,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(72),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                              label: const Text('Ước lượng bằng nhiều ảnh'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

