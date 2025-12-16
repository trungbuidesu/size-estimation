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
    final bool granted = status == PermissionStatus.granted ||
        status == PermissionStatus.limited;

    return Card(
      // AppTheme default margin is vertical: 8, horizontal: 0.
      // We want some horizontal margin for the list items usually, or the listview provides it.
      // Looking at permissions_screen, ListView has no horizontal padding.
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: granted ? null : onRequest,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(item.icon, size: 24, color: statusColor),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        if (granted) ...[
                          const SizedBox(height: 2),
                          Text(
                            statusLabel,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  if (!granted)
                    OutlinedButton(
                      onPressed: onRequest,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: statusColor,
                        side: BorderSide(color: statusColor.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(buttonLabel),
                    )
                  else
                    Icon(Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary, size: 24),
                ],
              ),
              if (!granted) ...[
                const SizedBox(height: 12),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
