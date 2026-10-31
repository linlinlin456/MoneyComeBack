import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/book.dart';
import '../models/cost_item.dart';
import '../models/reading_summary.dart';

/// 备份文件解析后的结果。
class BackupData {
  final List<Book> books;
  final List<CostItem> costs;
  final ReadingSummary summary;

  BackupData({
    required this.books,
    required this.costs,
    required this.summary,
  });
}

/// JSON 备份：把全部数据导出成一个文件。
/// App 卸载后本地数据库会一起消失，重装后导入这个文件即可恢复。
class BackupService {
  static const int formatVersion = 1;
  static const String fileName = 'book_roi_backup.json';

  static String encode({
    required List<Book> books,
    required List<CostItem> costs,
    required ReadingSummary summary,
  }) {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'app': 'book_roi',
      'format_version': formatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'books': books.map((Book e) => e.toMap()).toList(),
      'costs': costs.map((CostItem e) => e.toMap()).toList(),
      'reading_summary': summary.toMap(),
    });
  }

  static BackupData decode(String text) {
    final dynamic decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('备份文件格式不正确');
    }
    final Map<String, dynamic> root = Map<String, dynamic>.from(decoded);
    final List<Book> books = <Book>[];
    final List<CostItem> costs = <CostItem>[];

    final dynamic rawBooks = root['books'];
    if (rawBooks is List) {
      for (final dynamic item in rawBooks) {
        if (item is Map) books.add(Book.fromMap(Map<String, Object?>.from(item)));
      }
    }
    final dynamic rawCosts = root['costs'];
    if (rawCosts is List) {
      for (final dynamic item in rawCosts) {
        if (item is Map) {
          costs.add(CostItem.fromMap(Map<String, Object?>.from(item)));
        }
      }
    }
    ReadingSummary summary = ReadingSummary();
    final dynamic rawSummary = root['reading_summary'];
    if (rawSummary is Map) {
      summary = ReadingSummary.fromMap(Map<String, Object?>.from(rawSummary));
    }
    return BackupData(books: books, costs: costs, summary: summary);
  }

  /// 写入 App 文档目录，返回完整路径。
  static Future<String> writeToAppDir(String json) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/$fileName');
    await file.writeAsString(json);
    return file.path;
  }

  static Future<String> readFile(String path) async {
    return File(path).readAsString();
  }

  /// 供界面展示的「上次备份」文案。
  static String describeTime(int millis) {
    if (millis <= 0) return '从未备份';
    final DateTime t = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int v) => v < 10 ? '0$v' : '$v';
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}
