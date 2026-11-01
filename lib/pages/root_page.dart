import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_version.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/update_flow.dart';
import '../widgets/version_dialog.dart';
import 'books_page.dart';
import 'home_page.dart';
import 'settings_page.dart';

/// 底部三个标签：首页 / 书值 / 设置。
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;

  /// 启动后只检查一次「要不要弹更新说明」。
  bool _updateChecked = false;

  /// 启动后只自动检查一次更新源。
  bool _autoChecked = false;

  /// 启动后只自动同步一次微信读书。
  bool _autoSynced = false;

  static const List<String> _titles = <String>['首页', '书值', '设置'];

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    if (state.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.ink)),
      );
    }
    // 数据加载完之后再检查，避免弹窗比首屏还早出现。
    if (!_updateChecked) {
      _updateChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate(state));
    }
    if (!_autoChecked) {
      _autoChecked = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _autoCheckUpdate(state));
    }
    if (!_autoSynced) {
      _autoSynced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoSync(state));
    }
    final List<Widget> pages = <Widget>[
      const HomePage(),
      const BooksPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: _navBar(),
    );
  }

  /// 版本更新推送：换到新构建号后第一次打开时，弹出本版更新说明。
  Future<void> _checkUpdate(AppState state) async {
    if (!mounted) return;
    if (AppVersion.build <= state.settings.lastSeenVersion) return;
    final VersionLog? log = AppVersion.logOf(AppVersion.build);
    if (log == null) return;
    await showVersionDialog(
      context,
      log: log,
      title: '已更新到 v${log.version}',
    );
    await state.settings.markVersionSeen(AppVersion.build);
  }

  /// 启动时静默检查一次更新；没填地址就用内置更新源。
  /// 只有真的发现新版本才会弹窗。
  Future<void> _autoCheckUpdate(AppState state) async {
    if (!mounted) return;
    // 让首屏、自动同步和「本次更新」弹窗先出来，避免几个框叠在一起。
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    await runUpdateFlow(
      context,
      url: state.settings.updateUrl.trim(),
      silent: true,
    );
  }

  /// 启动时自动同步一次微信读书（可在设置里关掉）。
  ///
  /// 没填 API Key 就直接跳过；失败也不弹窗，免得每次开 App 都被打扰。
  Future<void> _autoSync(AppState state) async {
    if (!state.settings.autoSyncOnStart) return;
    if (state.settings.wereadApiKey.trim().isEmpty) return;
    if (state.syncing) return;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    try {
      await state.syncFromWeRead();
    } catch (_) {
      // 自动同步失败保持安静：设置页里能看到上次同步时间与结果。
    }
  }

  Widget _navBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.card,
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Row(
        children: List<Widget>.generate(_titles.length, (int i) {
          final bool active = i == _index;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _index = i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _titles[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? AppTheme.ink : AppTheme.inkFaint,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: active ? AppTheme.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
