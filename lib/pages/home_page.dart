import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reading_summary.dart';
import '../providers/app_state.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 首页：回本进度、已读价值 / 总成本、阅读时长、成本构成。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _rangeIndex = 0;

  static const List<String> _ranges = <String>['本周', '本月', '今年', '累计'];
  static const List<Color> _pieColors = <Color>[
    Color(0xFF111111),
    Color(0xFF4A4A4A),
    Color(0xFF8C8C8C),
    Color(0xFFC9C9C9),
    Color(0xFFE4E4E4),
  ];

  int _secondsOf(ReadingSummary s) {
    switch (_rangeIndex) {
      case 0:
        return s.weekSeconds;
      case 1:
        return s.monthSeconds;
      case 2:
        return s.yearSeconds;
      default:
        return s.totalSeconds;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final RoiStats stats = state.stats;

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: <Widget>[
        const PageTitle('本钱回笼记'),
        _progressCard(stats),
        const SizedBox(height: 12),
        _valueCards(stats),
        const SizedBox(height: 12),
        _timeCard(state.summary, stats),
        const SizedBox(height: 12),
        _breakdownCard(stats),
      ],
    );
  }

  Widget _progressCard(RoiStats stats) {
    final double pct = stats.progress * 100;
    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('回本进度',
                  style: TextStyle(fontSize: 14, color: AppTheme.inkSoft)),
              const Spacer(),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkProgressBar(value: stats.progress, height: 12),
          const SizedBox(height: 14),
          _progressHint(stats),
        ],
      ),
    );
  }

  Widget _progressHint(RoiStats stats) {
    if (stats.totalCost <= 0) {
      return const Text(
        '还没有录入成本，去「设置」里添加阅读器和会员费',
        style: TextStyle(fontSize: 13, color: AppTheme.inkSoft),
      );
    }
    if (stats.isPaidBack) {
      return Text(
        '已回本，超出 ${money(stats.readValue - stats.totalCost)}',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '还差 ${money(stats.gap)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          stats.avgBookPrice > 0
              ? '按平均书价 ${money(stats.avgBookPrice)}，再读约 ${stats.booksToGo} 本书回本'
              : '给书籍填上价格后，可以估算还需要读几本',
          style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft),
        ),
      ],
    );
  }

  Widget _valueCards(RoiStats stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: <Widget>[
          Expanded(child: _miniCard('已读价值', money(stats.readValue))),
          const SizedBox(width: 12),
          Expanded(child: _miniCard('总成本', money(stats.totalCost))),
        ],
      ),
    );
  }

  Widget _miniCard(String label, String value) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppTheme.inkSoft)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _timeCard(ReadingSummary summary, RoiStats stats) {
    final int seconds = _secondsOf(summary);
    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('阅读时长',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          PillTabs(
            labels: _ranges,
            activeIndex: _rangeIndex,
            onChanged: (int i) => setState(() => _rangeIndex = i),
          ),
          const SizedBox(height: 16),
          Text(
            ReadingSummary.formatDuration(seconds),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            summary.totalSeconds > 0
                ? '累计 ${summary.totalText} · 阅读 ${summary.readDays} 天'
                : '还没同步过阅读时长，去「设置」里填 API Key 后同步',
            style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft),
          ),
          if (seconds > 0 && stats.readValue > 0) ...<Widget>[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            KVRow(
              label: '价值 / 时间',
              value: ReadingSummary.perHour(stats.readValue, seconds),
            ),
          ],
        ],
      ),
    );
  }

  Widget _breakdownCard(RoiStats stats) {
    final Map<String, double> data = stats.costByCategory;
    return SectionCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('构成分析',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('成本占比',
              style: TextStyle(fontSize: 12, color: AppTheme.inkSoft)),
          const SizedBox(height: 16),
          if (data.isEmpty)
            const Text('还没有成本数据',
                style: TextStyle(fontSize: 13, color: AppTheme.inkSoft))
          else
            Row(
              children: <Widget>[
                SizedBox(width: 118, height: 118, child: _pie(data)),
                const SizedBox(width: 16),
                Expanded(child: _legend(data)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _pie(Map<String, double> data) {
    final List<String> keys = data.keys.toList();
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 28,
        sections: List<PieChartSectionData>.generate(keys.length, (int i) {
          return PieChartSectionData(
            value: data[keys[i]] ?? 0,
            color: _pieColors[i % _pieColors.length],
            radius: 22,
            showTitle: false,
          );
        }),
      ),
    );
  }

  Widget _legend(Map<String, double> data) {
    final double total =
        data.values.fold(0.0, (double a, double b) => a + b);
    final List<String> keys = data.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(keys.length, (int i) {
        final double v = data[keys[i]] ?? 0;
        final double pct = total > 0 ? v / total * 100 : 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                color: _pieColors[i % _pieColors.length],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(keys[i], style: const TextStyle(fontSize: 12)),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }),
    );
  }
}
