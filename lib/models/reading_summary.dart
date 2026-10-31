/// 从微信读书拉回来的阅读统计汇总。
///
/// 官方接口只提供「累计 / 本周 / 本月 / 今年」四个口径，没有每日明细，
/// 所以首页不做每日柱状图。
class ReadingSummary {
  int totalSeconds;
  int weekSeconds;
  int monthSeconds;
  int yearSeconds;
  int readDays;
  int updatedAt;

  ReadingSummary({
    this.totalSeconds = 0,
    this.weekSeconds = 0,
    this.monthSeconds = 0,
    this.yearSeconds = 0,
    this.readDays = 0,
    this.updatedAt = 0,
  });

  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0分钟';
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    if (h > 0) return m > 0 ? '$h小时$m分' : '$h小时';
    return '$m分钟';
  }

  String get totalText => formatDuration(totalSeconds);
  String get weekText => formatDuration(weekSeconds);
  String get monthText => formatDuration(monthSeconds);
  String get yearText => formatDuration(yearSeconds);

  /// 每小时价值：给定金额除以累计小时数。
  static String perHour(double amount, int seconds) {
    if (seconds <= 0) return '--';
    final double hours = seconds / 3600.0;
    if (hours <= 0) return '--';
    return '¥${(amount / hours).toStringAsFixed(2)}/小时';
  }

  factory ReadingSummary.fromMap(Map<String, Object?> m) {
    return ReadingSummary(
      totalSeconds: (m['total_seconds'] as int?) ?? 0,
      weekSeconds: (m['week_seconds'] as int?) ?? 0,
      monthSeconds: (m['month_seconds'] as int?) ?? 0,
      yearSeconds: (m['year_seconds'] as int?) ?? 0,
      readDays: (m['read_days'] as int?) ?? 0,
      updatedAt: (m['updated_at'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'total_seconds': totalSeconds,
      'week_seconds': weekSeconds,
      'month_seconds': monthSeconds,
      'year_seconds': yearSeconds,
      'read_days': readDays,
      'updated_at': updatedAt,
    };
  }
}
