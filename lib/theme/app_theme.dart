import 'package:flutter/material.dart';

/// 全局黑白极简主题：白底卡片 + 黑色文字与描边，不做彩色点缀。
class AppTheme {
  const AppTheme._();

  static const Color bg = Color(0xFFF5F5F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF111111);
  static const Color inkSoft = Color(0xFF767676);
  static const Color inkFaint = Color(0xFFAAAAAA);
  static const Color line = Color(0xFFE4E4E4);
  static const Color track = Color(0xFFEDEDED);

  static ThemeData build() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: ink,
        secondary: ink,
        surface: card,
        onPrimary: Colors.white,
        onSurface: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: card,
        selectedItemColor: ink,
        unselectedItemColor: inkFaint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
    );
  }

  /// 统一卡片：白底 + 细描边 + 圆角。
  static BoxDecoration cardBox({
    double radius = 16,
    Color? border,
    double borderWidth = 1,
  }) =>
      BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: border ?? line,
          width: border == null ? 1 : borderWidth,
        ),
      );

  /// 胶囊标签：选中为黑底白字，未选中为白底灰边。
  static BoxDecoration pill({required bool active}) => BoxDecoration(
        color: active ? ink : card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? ink : line),
      );
}
