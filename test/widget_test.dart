// 应用冒烟测试：确认能构建出根组件。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_roi/app.dart';

void main() {
  testWidgets('App 能正常构建', (WidgetTester tester) async {
    await tester.pumpWidget(const BookRoiApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
