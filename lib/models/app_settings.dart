import 'package:shared_preferences/shared_preferences.dart';

/// 应用设置，存在 shared_preferences 里。
class AppSettings {
  String wereadApiKey;
  bool valueByProgress;
  bool autoBackup;
  int lastBackupAt;
  String lastSyncAt;

  /// 已经看过更新说明的最高构建号。启动时用它判断要不要弹「本次更新」。
  int lastSeenVersion;

  /// 更新源地址：一份 version.json 的网址。
  /// 留空就用代码里内置的更新源（Gitee / GitHub 依次尝试）。
  String updateUrl;

  /// 启动 App 时自动同步一次微信读书。
  bool autoSyncOnStart;

  /// 定价记录范围。
  ///
  /// true  = 只记付费书：只统计、只展示「需要付费会员才能读」的书，
  ///         免费阅读 / 体验卡可读的书会被隐藏，平均书价也按付费书算。
  /// false = 全部记录：所有书都展示，免费书显示「免费阅读」，
  ///         平均书价按全部书算。
  bool onlyPaidPricing;

  AppSettings({
    this.wereadApiKey = '',
    this.valueByProgress = true,
    this.autoBackup = true,
    this.lastBackupAt = 0,
    this.lastSyncAt = '',
    this.lastSeenVersion = 0,
    this.updateUrl = '',
    this.autoSyncOnStart = true,
    this.onlyPaidPricing = true,
  });

  static const String _kApiKey = 'weread_api_key';
  static const String _kValueByProgress = 'value_by_progress';
  static const String _kAutoBackup = 'auto_backup';
  static const String _kLastBackupAt = 'last_backup_at';
  static const String _kLastSyncAt = 'last_sync_at';
  static const String _kLastSeenVersion = 'last_seen_version';
  static const String _kUpdateUrl = 'update_url';
  static const String _kOnlyPaidPricing = 'only_paid_pricing';
  static const String _kAutoSyncOnStart = 'auto_sync_on_start';

  static Future<AppSettings> load() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    return AppSettings(
      wereadApiKey: sp.getString(_kApiKey) ?? '',
      valueByProgress: sp.getBool(_kValueByProgress) ?? true,
      autoBackup: sp.getBool(_kAutoBackup) ?? true,
      lastBackupAt: sp.getInt(_kLastBackupAt) ?? 0,
      lastSyncAt: sp.getString(_kLastSyncAt) ?? '',
      lastSeenVersion: sp.getInt(_kLastSeenVersion) ?? 0,
      updateUrl: sp.getString(_kUpdateUrl) ?? '',
      autoSyncOnStart: sp.getBool(_kAutoSyncOnStart) ?? true,
      onlyPaidPricing: sp.getBool(_kOnlyPaidPricing) ?? true,
    );
  }

  Future<void> save() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setString(_kApiKey, wereadApiKey);
    await sp.setBool(_kValueByProgress, valueByProgress);
    await sp.setBool(_kAutoBackup, autoBackup);
    await sp.setInt(_kLastBackupAt, lastBackupAt);
    await sp.setString(_kLastSyncAt, lastSyncAt);
    await sp.setInt(_kLastSeenVersion, lastSeenVersion);
    await sp.setString(_kUpdateUrl, updateUrl);
    await sp.setBool(_kAutoSyncOnStart, autoSyncOnStart);
    await sp.setBool(_kOnlyPaidPricing, onlyPaidPricing);
  }

  /// 记下「第 build 版的更新说明已经看过」，避免每次启动都弹。
  Future<void> markVersionSeen(int build) async {
    if (build <= lastSeenVersion) return;
    lastSeenVersion = build;
    await save();
  }
}
