import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:size_estimation/models/index.dart'; 

class PermissionTile extends StatelessWidget {
  final PermissionItem item;
  final PermissionStatus? status;
  final Color statusColor;
  final String statusLabel;
  final String buttonLabel;
  final VoidCallback onRequest;

  const PermissionTile({
    super.key,
    required this.item,
    required this.status,
    required this.statusColor,
    required this.statusLabel,
    required this.buttonLabel,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    // Chỉ Granted mới được coi là đã cấp. 
    // Nếu bạn muốn cả limited cũng coi là granted, hãy thêm:
    // final bool granted = status == PermissionStatus.granted || status == PermissionStatus.limited;
    final bool granted = status == PermissionStatus.granted || status == PermissionStatus.limited;


    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(item.icon, size: 30, color: statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                // Nút bị disable nếu đã granted hoặc limited
                onPressed: granted ? null : onRequest, 
                icon: Icon(granted ? Icons.check : Icons.settings),
                label: Text(buttonLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: granted ? Colors.grey : statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}