import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 白底描边卡片。
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: AppTheme.cardBox(),
      child: child,
    );
  }
}

/// 黑色进度条。
class InkProgressBar extends StatelessWidget {
  final double value;
  final double height;

  const InkProgressBar({super.key, required this.value, this.height = 10});

  @override
  Widget build(BuildContext context) {
    final double v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: AppTheme.track,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            child: Container(color: AppTheme.ink),
          ),
        ),
      ),
    );
  }
}

/// 胶囊筛选按钮组。
class PillTabs extends StatelessWidget {
  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  const PillTabs({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(labels.length, (int i) {
        final bool active = i == activeIndex;
        // 用 Material + InkWell + Ink：命中区域覆盖整个胶囊，
        // 且点击有涟漪反馈，避免 GestureDetector 命中不稳的问题。
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: AppTheme.pill(active: active),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 13,
                  color: active ? Colors.white : AppTheme.inkSoft,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 页面大标题，左侧粗体，右侧可放一个附加信息。
class PageTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const PageTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            text,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 一行「标签 —— 数值」。
class KVRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const KVRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.inkSoft),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 15 : 13,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// 空状态占位。
class EmptyHint extends StatelessWidget {
  final String text;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyHint({
    super.key,
    required this.text,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.inkSoft),
            ),
            if (actionText != null) ...<Widget>[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.ink,
                  side: const BorderSide(color: AppTheme.ink),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 金额格式化。
String money(double value) => '¥${value.toStringAsFixed(2)}';
