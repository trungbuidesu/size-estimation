// file: continue_button.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// 💡 Cần phải import GoRouter để sử dụng context.go()
import 'package:go_router/go_router.dart'; 

class ContinueButton extends StatelessWidget {
  final ValueListenable<bool> isEnabledNotifier;
  final String nextRoute;
  // 💡 NHÃN MỚI: Text khi nút được kích hoạt (đã cấp quyền)
  final String enabledLabel; 
  // 💡 NHÃN MỚI: Text khi nút bị vô hiệu hóa (chưa cấp quyền)
  final String disabledLabel; 

  const ContinueButton({
    super.key,
    required this.isEnabledNotifier,
    this.nextRoute = '/home',
    // Gán nhãn mặc định (bạn nên truyền vào từ widget cha)
    this.enabledLabel = 'TIẾP TỤC', 
    this.disabledLabel = 'KIỂM TRA QUYỀN', 
  });

  void _navigateToNext(BuildContext context) {
    // 🚀 SỬ DỤNG GOROUTER: Chuyển hướng đến route được định nghĩa
    context.go(nextRoute); 
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isEnabledNotifier,
      builder: (context, isEnabled, child) {
        
        // 💡 Dynamic Text: Chọn nhãn dựa trên trạng thái isEnabled
        final String buttonText = isEnabled ? enabledLabel : disabledLabel;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
          child: ElevatedButton.icon(
            // Nút chỉ được bấm khi isEnabled là true
            onPressed: isEnabled ? () => _navigateToNext(context) : null,
            
            // Icon vẫn giữ nguyên là mũi tên tiến
            icon: const Icon(Icons.arrow_forward), 
            
            // Dùng nhãn động
            label: Text(buttonText), 
            
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: isEnabled 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
              foregroundColor: isEnabled 
                ? Theme.of(context).colorScheme.onPrimary 
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
            ),
          ),
        );
      },
    );
  }
}