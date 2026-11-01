import 'package:flutter/material.dart';

import '../models/app_version.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// 「检查更新」的完整流程：
/// 拉更新源 → 比对构建号 → 弹窗 → App 内下载 APK → 调起系统安装器。
///
/// [silent] 为 true 时用于启动自动检查：没有新版、或拉取失败都安静结束，
/// 只有真的发现新版本才打扰用户。
Future<void> runUpdateFlow(
  BuildContext context, {
  required String url,
  bool silent = false,
}) async {
  final String source = url.trim();
  if (source.isEmpty) {
    if (!silent) {
      _toast(context, '先在「更新源地址」里填一份 version.json 的网址，再点检查更新');
    }
    return;
  }
  if (source.endsWith('.apk') || source.endsWith('.apk/')) {
    if (!silent) {
      _toast(context, '这里要填 version.json 的网址，不是 APK 下载链接');
    }
    return;
  }

  final UpdateInfo info;
  try {
    info = await UpdateService.fetch(source);
  } catch (e) {
    if (!silent) _toast(context, '检查更新失败：${cleanError(e)}');
    return;
  }
  if (!context.mounted) return;

  if (info.build <= AppVersion.build) {
    if (!silent) _toast(context, '已是最新版本 v${AppVersion.current}');
    return;
  }

  final bool go = await _askUpdate(context, info);
  if (!context.mounted || !go) return;
  await _downloadAndInstall(context, info.apkUrl);
}

/// 发现新版本时的确认框。返回 true 表示用户点了「立即更新」。
Future<bool> _askUpdate(BuildContext context, UpdateInfo info) async {
  final bool? go = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        '发现新版本 v${info.version}',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Text(
          info.notes.isEmpty ? '有新版本可以更新。' : info.notes,
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('稍后', style: TextStyle(color: AppTheme.inkSoft)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('立即更新', style: TextStyle(color: AppTheme.ink)),
        ),
      ],
    ),
  );
  return go ?? false;
}

/// 在 App 内下载 APK，下载完直接调起系统安装器。
Future<void> _downloadAndInstall(BuildContext context, String apkUrl) async {
  if (apkUrl.isEmpty) {
    _toast(context, '更新源里没写 APK 下载地址，请联系发布者');
    return;
  }
  if (!apkUrl.startsWith('http://') && !apkUrl.startsWith('https://')) {
    _toast(context, 'APK 下载地址要以 http:// 或 https:// 开头');
    return;
  }

  final ValueNotifier<double> progress = ValueNotifier<double>(-1);
  bool dialogOpen = true;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        '正在下载新版本',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (BuildContext c, double v, Widget? child) {
          final bool known = v >= 0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LinearProgressIndicator(
                value: known ? v : null,
                color: AppTheme.ink,
                backgroundColor: AppTheme.line,
              ),
              const SizedBox(height: 10),
              Text(
                known ? '已下载 ${(v * 100).toStringAsFixed(0)}%' : '正在下载…',
                style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft),
              ),
            ],
          );
        },
      ),
    ),
  );
  // 等一帧，保证进度框已经挂上去，后面才 pop 得掉。
  await Future<void>.delayed(const Duration(milliseconds: 80));

  void closeDialog() {
    if (!dialogOpen) return;
    dialogOpen = false;
    final NavigatorState? nav = Navigator.maybeOf(context, rootNavigator: true);
    if (nav != null && nav.canPop()) nav.pop();
  }

  try {
    final String path = await UpdateService.downloadApk(
      apkUrl,
      onProgress: (int received, int total) {
        progress.value = total > 0 ? received / total : -1;
      },
    );
    closeDialog();
    if (!context.mounted) return;
    await UpdateService.installApk(path);
    _toast(context, '已开始安装；若提示「未知来源」，请允许本应用安装应用');
  } catch (e) {
    closeDialog();
    if (!context.mounted) return;
    _toast(context, '下载失败：${cleanError(e)}');
  }
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
  );
}

/// 去掉异常自带的 `Exception: ` 前缀，提示读起来干净些。
String cleanError(Object e) =>
    e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
