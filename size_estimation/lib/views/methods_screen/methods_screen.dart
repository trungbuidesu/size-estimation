import 'dart:io';

import 'package:flutter/material.dart';

class MethodsScreen extends StatefulWidget {
  const MethodsScreen({super.key});

  @override
  State<MethodsScreen> createState() => _MethodsScreenState();
}

class _MethodsScreenState extends State<MethodsScreen> {
  bool _isCheckingSupport = false;
  bool _isArSupported = false;

  @override
  void initState() {
    super.initState();
    _detectArSupport();
  }

  Future<void> _detectArSupport() async {
    setState(() => _isCheckingSupport = true);

    // TODO: Thay logic kiểm tra bằng SDK/platform channel khi tích hợp ARCore.
    // Hiện tại chỉ mô phỏng: ưu tiên Android, coi như có hỗ trợ.
    final simulatedSupport = Platform.isAndroid;
    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;
    setState(() {
      _isArSupported = simulatedSupport;
      _isCheckingSupport = false;
    });
  }

  void _showInfoSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, controller) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ListView(
                controller: controller,
                children: const [
                  Text(
                    'Thông tin phương pháp ước lượng',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '1) ARCore (đo trực tiếp):\n'
                    '- Sử dụng cảm biến và camera để dựng mặt phẳng.\n'
                    '- Cho phép đo kích thước vật thể ngay trong không gian thực.\n'
                    '- Cần thiết bị hỗ trợ ARCore và bật cảm biến chuyển động.',
                  ),
                  SizedBox(height: 12),
                  Text(
                    '2) Nhiều ảnh từ các góc độ:\n'
                    '- Chụp/tải nhiều ảnh của vật thể ở các góc khác nhau.\n'
                    '- Hệ thống xử lý ảnh để ước lượng kích thước/khối tích.\n'
                    '- Hoạt động trên hầu hết thiết bị, không yêu cầu AR.',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Mẹo nhanh:\n'
                    '- Đảm bảo ánh sáng đủ và không rung tay.\n'
                    '- Với ARCore: quét mặt phẳng trước khi đo.\n'
                    '- Với ảnh: chụp đủ 4-6 góc, có vật tham chiếu nếu được.',
                  ),
                  SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _onSelectArCore() {
    if (!_isArSupported) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bắt đầu ước lượng bằng ARCore')),
    );
    // TODO: Điều hướng tới flow ARCore thực tế.
  }

  void _onSelectMultiImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chọn phương pháp dùng nhiều ảnh')),
    );
    // TODO: Điều hướng tới flow chụp/tải nhiều ảnh.
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn phương pháp ước lượng'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Giới thiệu',
            icon: const Icon(Icons.help_outline),
            onPressed: _showInfoSheet,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hãy chọn cách bạn muốn ước lượng kích thước vật thể.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isCheckingSupport
                          ? 'Đang kiểm tra thiết bị có hỗ trợ ARCore...'
                          : _isArSupported
                              ? 'Thiết bị hỗ trợ ARCore. Bạn có thể dùng đo trực tiếp.'
                              : 'Thiết bị không hỗ trợ ARCore. Vui lòng dùng phương pháp ảnh.',
                      style: const TextStyle(fontSize: 14),
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
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.view_in_ar),
              onPressed: (_isArSupported && !_isCheckingSupport)
                  ? _onSelectArCore
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              label: Text(
                _isCheckingSupport
                    ? 'Đang kiểm tra ARCore...'
                    : _isArSupported
                        ? 'Ước lượng bằng ARCore'
                        : 'ARCore không khả dụng',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              onPressed: _onSelectMultiImage,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              label: const Text('Ước lượng bằng nhiều ảnh'),
            ),
          ],
        ),
      ),
    );
  }
}

