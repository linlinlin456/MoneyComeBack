/// 应用版本与更新日志。
///
/// 发新版时只改这一个文件里的 [current] / [build] / [logs]，
/// 同时把 pubspec.yaml 的 version 改成 `<current>+<build>`。
class AppVersion {
  /// 当前版本号（展示用）。
  static const String current = '1.2.1';

  /// 构建号，必须严格递增；用来判断「这一版是不是第一次打开」。
  static const int build = 11;

  /// 更新日志，最新的放最前面。
  static const List<VersionLog> logs = <VersionLog>[
    VersionLog(
      version: '1.2.0',
      build: 10,
      date: '2026-11-01',
      items: <String>[
        '修正书籍分类：以前按「有没有定价」分，导致《平面国》这类'
            '体验卡可读的书也被算成付费会员书。现在改成按微信读书的'
            '书籍类型分，和 App 里「体验卡可读 / 付费会员可读」的标识一致。',
        '「只记付费书」时，只有付费会员可读的书显示定价，'
            '体验卡可读、按章购买、免费阅读的书显示「免费阅读」，'
            '不再把它们隐藏起来。',
        '「全部记录」时所有书都按定价显示。',
        '书籍卡片上的类型标签改为：付费会员可读 / 体验卡可读 / 按章购买 / 免费阅读。',
        '「关于」里新增「检查更新」和更新源地址，配上更新源后可以直接在 App 里'
            '发现新版本并跳去下载。',
      ],
    ),
    VersionLog(
      version: '1.1.0',
      build: 9,
      date: '2026-11-01',
      items: <String>[
        '「只记付费书」现在会真的筛选：书值列表里只留需要付费会员才能读的书，'
            '免费阅读和体验卡可读的书会被隐藏，顶部会提示隐藏了几本。',
        '书籍卡片新增类型标签：付费会员书 / 仅会员可读 / 免费阅读。',
        '设置页底部新增「关于」模块，显示项目名称、版本号，'
            '以及 linlinlin 水印。',
        '打开新版本时会自动弹出本版的更新说明。',
      ],
    ),
    VersionLog(
      version: '1.0.0',
      build: 1,
      date: '2026-10-31',
      items: <String>[
        '「付费书」口径改为「需要付费会员才能读」，体验卡可读和免费阅读的书不计入。',
        '设置页新增「定价记录范围」：只记付费书 / 全部记录。',
      ],
    ),
  ];

  /// 取某个构建号对应的更新日志；找不到返回 null。
  static VersionLog? logOf(int b) {
    for (final VersionLog l in logs) {
      if (l.build == b) return l;
    }
    return null;
  }

  /// 最新一版的更新日志。
  static VersionLog get latest => logs.first;
}

/// 一个版本的更新说明。
class VersionLog {
  final String version;
  final int build;
  final String date;
  final List<String> items;

  const VersionLog({
    required this.version,
    required this.build,
    required this.date,
    required this.items,
  });
}
