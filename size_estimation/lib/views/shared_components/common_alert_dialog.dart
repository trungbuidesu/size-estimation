import 'package:flutter/material.dart';

class CommonAlertDialog extends StatelessWidget {
  final String title;
  final Widget? content;
  final String? contentText;
  final List<Widget>? actions;
  final IconData? icon;
  final Color? iconColor;

  const CommonAlertDialog({
    super.key,
    required this.title,
    this.content,
    this.contentText,
    this.actions,
    this.icon,
    this.iconColor,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    Widget? content,
    String? contentText,
    List<Widget>? actions,
    IconData? icon,
    Color? iconColor,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => CommonAlertDialog(
        title: title,
        content: content,
        contentText: contentText,
        actions: actions,
        icon: icon,
        iconColor: iconColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Padding is often specific to the dialog layout choice, keeping here for now or could move to Theme if supported.
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: iconColor ?? Theme.of(context).primaryColor,
              size: 28,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Text(title),
          ),
        ],
      ),
      content: content ?? (contentText != null ? Text(contentText!) : null),
      actions: actions,
    );
  }
}
