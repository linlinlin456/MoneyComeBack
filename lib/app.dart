import 'package:flutter/material.dart';

import 'pages/root_page.dart';
import 'theme/app_theme.dart';

class BookRoiApp extends StatelessWidget {
  const BookRoiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '本钱回笼记',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const RootPage(),
    );
  }
}
