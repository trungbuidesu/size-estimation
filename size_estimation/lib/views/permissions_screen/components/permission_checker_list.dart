import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:size_estimation/constants/index.dart';
import 'package:size_estimation/views/permissions_screen/components/index.dart';

class PermissionCheckerList extends StatefulWidget {
  // Callback/Notifier để thông báo trạng thái kích hoạt cho nút Tiếp tục
  final ValueNotifier<bool> allGrantedNotifier;

  const PermissionCheckerList({
    super.key,
    required this.allGrantedNotifier,
  });

  @override
  State<PermissionCheckerList> createState() => _PermissionCheckerListState();
}

class _PermissionCheckerListState extends State<PermissionCheckerList> {
  final Map<Permission, PermissionStatus?> _statuses = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    for (var item in requiredPermissions) {
      _statuses[item.permission] = null;
    }
    _refreshStatuses();
  }

  // --- Logic Kiểm tra và Cập nhật Trạng thái ---

  bool get _allPermissionsGranted {
    if (_statuses.containsValue(null)) {
      return false; // Đang kiểm tra
    }
    // Chỉ cần tất cả đều là granted HOẶC limited
    return _statuses.values.every((status) =>
        status == PermissionStatus.granted ||
        status == PermissionStatus.limited);
  }

  Future<void> _refreshStatuses() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    final newStatuses = <Permission, PermissionStatus>{};
    for (var item in requiredPermissions) {
      newStatuses[item.permission] = await item.permission.status;
    }

    if (mounted) {
      setState(() {
        _statuses.addAll(newStatuses);
        _loading = false;
      });
      // 💡 CẬP NHẬT NOTIFIER: Thông báo trạng thái mới ra bên ngoài
      widget.allGrantedNotifier.value = _allPermissionsGranted;
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    final current = await permission.status;
    if (current.isPermanentlyDenied) {
      _showSettingsSnackBar();
      await openAppSettings();
      _refreshStatuses();
      return;
    }

    final status = await permission.request();
    if (mounted) {
      setState(() {
        _statuses[permission] = status;
      });
      // 💡 CẬP NHẬT NOTIFIER sau khi yêu cầu
      widget.allGrantedNotifier.value = _allPermissionsGranted;
    }

    if (status.isPermanentlyDenied) {
      _showSettingsSnackBar();
    }
  }

  // --- Helper Functions cho UI (Giữ nguyên) ---

  Color _statusColor(PermissionStatus? status, BuildContext context) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return Theme.of(context).colorScheme.primary.withOpacity(0.20);
      case PermissionStatus.denied:
        return Colors.orange.withOpacity(0.10);
      case PermissionStatus.restricted:
      case PermissionStatus.permanentlyDenied:
        return Colors.red.withOpacity(0.10);
      default:
        return Colors.grey.withOpacity(0.08);
    }
  }

  String _statusLabel(PermissionStatus? status) {
    switch (status) {
      case PermissionStatus.granted:
        return "Đã cho phép";
      case PermissionStatus.limited:
        return "Chỉ cho phép giới hạn";
      case PermissionStatus.denied:
        return "Bị từ chối";
      case PermissionStatus.restricted:
        return "Bị giới hạn";
      case PermissionStatus.permanentlyDenied:
        return "Từ chối vĩnh viễn";
      default:
        return "Không xác định";
    }
  }

  String _buttonLabel(PermissionStatus? status) {
    switch (status) {
      case PermissionStatus.granted:
        return "Xong";
      case PermissionStatus.limited:
        return "Xem lại";
      case PermissionStatus.denied:
      case PermissionStatus.restricted:
        return "Yêu cầu quyền";
      case PermissionStatus.permanentlyDenied:
        return "Mở cài đặt";
      default:
        return "Yêu cầu quyền";
    }
  }

  void _showSettingsSnackBar() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: const Text(
            "Bạn cần vào Cài đặt để cấp quyền thủ công cho ứng dụng."),
        action: SnackBarAction(
          label: "Mở cài đặt",
          onPressed: () => openAppSettings(),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // --- Build UI ---

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshStatuses,
      child: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.only(
                top: 16, bottom: 100), // Dành không gian cho nút
            itemCount: requiredPermissions.length,
            itemBuilder: (context, index) {
              final item = requiredPermissions[index];
              final status = _statuses[item.permission];

              return PermissionTile(
                item: item,
                status: status,
                statusColor: _statusColor(status, context),
                statusLabel: _statusLabel(status),
                buttonLabel: _buttonLabel(status),
                onRequest: () {
                  if (status == PermissionStatus.permanentlyDenied) {
                    openAppSettings(); // Không cần setState ngay, sẽ gọi _refreshStatuses sau
                  } else if (status != PermissionStatus.granted) {
                    _requestPermission(item.permission);
                  }
                },
              );
            },
          ),
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.05),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
