import 'package:flutter/material.dart';

import '../models/app_version.dart';
import '../theme/app_theme.dart';

/// 弹出「更新说明」对话框。
Future<void> showVersionDialog(
  BuildContext context, {
  required VersionLog log,
  String title = '本次更新',
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '版本 ${log.version} · ${log.date}',
              style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft),
            ),
            const SizedBox(height: 12),
            for (final String it in log.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppTheme.inkFaint,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        it,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('知道了', style: TextStyle(color: AppTheme.ink)),
        ),
      ],
    ),
  );
}
