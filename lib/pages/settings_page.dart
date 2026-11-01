import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_version.dart';
import '../models/cost_item.dart';
import '../providers/app_state.dart';
import '../services/backup_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/update_flow.dart';
import '../widgets/version_dialog.dart';
import 'cost_page.dart';

/// 设置：成本一览、微信读书同步、价值口径、备份与恢复。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _apiKey = TextEditingController();
  final TextEditingController _updateUrl = TextEditingController();

  bool _keyLoaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _apiKey.dispose();
    _updateUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    if (!_keyLoaded) {
      _apiKey.text = state.settings.wereadApiKey;
      _updateUrl.text = state.settings.updateUrl;
      _keyLoaded = true;
    }
    final double totalCost =
        state.costs.fold(0.0, (double a, CostItem c) => a + c.amount);

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: <Widget>[
        const PageTitle('设置'),
        _costCard(state, totalCost),
        const SizedBox(height: 12),
        _wereadCard(state),
        const SizedBox(height: 12),
        _pricingScopeCard(state),
        const SizedBox(height: 12),
        _valueRuleCard(state),
        const SizedBox(height: 12),
        _backupCard(state),
        const SizedBox(height: 12),
        _dangerCard(state),
        const SizedBox(height: 12),
        _aboutCard(state),
      ],
    );
  }

  // ---------------- 关于 ----------------

  Widget _aboutCard(AppState state) {
    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('关于',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text(
            '本钱回笼记',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '版本 ${AppVersion.current}（构建 ${AppVersion.build}）',
            style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft),
          ),
          const SizedBox(height: 4),
          const Text(
            '统计已读书籍价值与阅读成本，看阅读器有没有回本。',
            style: TextStyle(fontSize: 12, color: AppTheme.inkSoft),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: () => showVersionDialog(
                  context,
                  log: AppVersion.latest,
                  title: '更新日志',
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '查看更新日志',
                  style: TextStyle(fontSize: 12, color: AppTheme.ink),
                ),
              ),
              const SizedBox(width: 18),
              TextButton(
                onPressed: _busy ? null : _checkUpdate,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _busy ? '检查中…' : '检查更新',
                  style: const TextStyle(fontSize: 12, color: AppTheme.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '更新源地址',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _updateUrl,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              hintText: '留空即用内置更新源，一般不用填',
              hintStyle: const TextStyle(fontSize: 11, color: AppTheme.inkFaint),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.line),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '留空就用内置更新源（Gitee / GitHub 依次尝试），不用自己填也能检查更新。',
            style: TextStyle(fontSize: 11, color: AppTheme.inkFaint),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: () async {
                  await state.setUpdateUrl(_updateUrl.text);
                  if (!mounted) return;
                  _toast('更新源地址已保存');
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '保存地址',
                  style: TextStyle(fontSize: 12, color: AppTheme.ink),
                ),
              ),
              const SizedBox(width: 14),
              TextButton(
                onPressed: () async {
                  _updateUrl.clear();
                  await state.setUpdateUrl('');
                  if (!mounted) return;
                  _toast('已恢复为内置更新源');
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '用内置源',
                  style: TextStyle(fontSize: 12, color: AppTheme.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppTheme.line),
          const SizedBox(height: 16),
          // 项目水印。
          Center(
            child: Transform.rotate(
              angle: -0.05,
              child: Text(
                'linlinlin',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 5,
                  color: AppTheme.ink.withOpacity(0.08),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ---------------- 成本一览 ----------------

  Widget _costCard(AppState state, double totalCost) {
    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('成本一览',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CostPage()),
                ),
                child: const Text('管理', style: TextStyle(color: AppTheme.ink)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (state.costs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '还没有成本条目，点「管理」添加阅读器、会员费、配件',
                style: TextStyle(fontSize: 12, color: AppTheme.inkSoft),
              ),
            )
          else ...<Widget>[
            ...state.costs.take(4).map(
                  (CostItem c) => KVRow(
                    label: '${c.name} · ${c.category}',
                    value: money(c.amount),
                  ),
                ),
            if (state.costs.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '还有 ${state.costs.length - 4} 条…',
                  style: const TextStyle(fontSize: 12, color: AppTheme.inkFaint),
                ),
              ),
            const Divider(height: 20),
            KVRow(label: '合计', value: money(totalCost), emphasize: true),
          ],
        ],
      ),
    );
  }

  // ---------------- 微信读书 ----------------

  Widget _wereadCard(AppState state) {
    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('微信读书',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            '在微信读书官网扫码获取 API Key（免费），填进来就能同步书架和阅读时长。',
            style: TextStyle(fontSize: 12, color: AppTheme.inkSoft),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKey,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'wrk-xxxxxxxx',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              OutlinedButton(
                onPressed: () async {
                  await state.saveApiKey(_apiKey.text);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API Key 已保存')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.ink,
                  side: const BorderSide(color: AppTheme.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text('保存 Key'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _busy ? null : _sync,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(_busy ? '同步中…' : '立即同步'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state.settings.autoSyncOnStart,
            onChanged: (bool v) => state.setAutoSyncOnStart(v),
            title: const Text('启动时自动同步', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              '每次打开 App 自动拉一次书架和阅读进度',
              style: TextStyle(fontSize: 11, color: AppTheme.inkFaint),
            ),
          ),
          if (state.settings.lastSyncAt.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              '上次同步：${state.settings.lastSyncAt}',
              style: const TextStyle(fontSize: 12, color: AppTheme.inkFaint),
            ),
          ],
          if (state.syncMessage.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              state.syncMessage,
              style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- 定价记录范围 ----------------

  Widget _pricingScopeCard(AppState state) {
    final bool onlyPaid = state.settings.onlyPaidPricing;
    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('定价记录范围',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          PillTabs(
            labels: const <String>['只记付费书', '全部记录'],
            activeIndex: onlyPaid ? 0 : 1,
            onChanged: (int i) => state.setOnlyPaidPricing(i == 0),
          ),
          const SizedBox(height: 10),
          Text(
            onlyPaid
                ? '付费书只算微信读书里标着「付费会员可读」的书，按它的定价计入。'
                    '体验卡可读、按章购买、免费阅读的书在书值列表里显示'
                    '「免费阅读」，不计入金额，平均书价也不会被它们拉低。'
                : '所有书都按定价显示（没有定价的显示 ¥0.00），'
                    '平均书价按全部书算。',
            style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft),
          ),
        ],
      ),
    );
  }

  // ---------------- 价值口径 ----------------

  Widget _valueRuleCard(AppState state) {
    final bool byProgress = state.settings.valueByProgress;
    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('已读价值怎么算',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          PillTabs(
            labels: const <String>['按进度折算', '读完才算全价'],
            activeIndex: byProgress ? 0 : 1,
            onChanged: (int i) => state.setValueByProgress(i == 0),
          ),
          const SizedBox(height: 10),
          Text(
            byProgress
                ? '读了一半就算一半价值，回本进度更平滑。'
                : '只有进度 100% 的书才计入已读价值，口径更严格。',
            style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft),
          ),
        ],
      ),
    );
  }

  // ---------------- 备份 ----------------

  Widget _backupCard(AppState state) {
    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('数据备份',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            '数据存在本机，卸载 App 会一起清掉。开启自动备份后，每次改动都会导出一份 JSON。',
            style: TextStyle(fontSize: 12, color: AppTheme.inkSoft),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state.settings.autoBackup,
            onChanged: (bool v) => state.setAutoBackup(v),
            title: const Text('自动备份', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              '上次备份：${BackupService.describeTime(state.settings.lastBackupAt)}',
              style: const TextStyle(fontSize: 11, color: AppTheme.inkFaint),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _export,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.ink,
                    side: const BorderSide(color: AppTheme.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('导出备份'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _import,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.ink,
                    side: const BorderSide(color: AppTheme.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('导入恢复'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '导出后建议存到网盘或电脑上，换手机时导入这个文件即可恢复全部数据。',
            style: TextStyle(fontSize: 11, color: AppTheme.inkFaint),
          ),
        ],
      ),
    );
  }

  // ---------------- 危险操作 ----------------

  Widget _dangerCard(AppState state) {
    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('清空数据',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            '删掉全部书籍、成本和阅读时长。建议先导出备份。',
            style: TextStyle(fontSize: 12, color: AppTheme.inkSoft),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _confirmClear,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.ink,
              side: const BorderSide(color: AppTheme.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('清空所有数据'),
          ),
        ],
      ),
    );
  }

  // ---------------- 动作 ----------------

  Future<void> _sync() async {
    final AppState state = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final String msg = await state.syncFromWeRead();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步失败：${cleanError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final AppState state = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final String path = await state.exportBackup();
      await Share.shareXFiles(
        <XFile>[XFile(path)],
        text: '阅读回本统计备份',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：${cleanError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final AppState state = context.read<AppState>();
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final String? path = picked.files.single.path;
    if (path == null) return;

    setState(() => _busy = true);
    try {
      final String text = await BackupService.readFile(path);
      final String msg = await state.importBackupText(text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：${cleanError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmClear() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('确定清空全部数据？'),
        content: const Text('书籍、成本和阅读时长都会被删除，且无法撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: AppTheme.inkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空', style: TextStyle(color: AppTheme.ink)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    await context.read<AppState>().clearAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清空')),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  /// 检查更新：拉更新源比对构建号，有新版本就在 App 内下载并调起安装。
  Future<void> _checkUpdate() async {
    setState(() => _busy = true);
    await runUpdateFlow(context, url: _updateUrl.text);
    if (mounted) setState(() => _busy = false);
  }
}
