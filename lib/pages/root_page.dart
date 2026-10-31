import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_version.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
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
