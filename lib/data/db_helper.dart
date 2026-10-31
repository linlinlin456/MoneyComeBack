import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/book.dart';
import '../models/cost_item.dart';
import '../models/reading_summary.dart';

/// 本地 SQLite 数据库。卸载 App 会连库一起删掉，所以另有备份服务负责导出 JSON。
class DbHelper {
  DbHelper._();

  static final DbHelper instance = DbHelper._();

  static const String _dbName = 'book_roi.db';
  static const int _dbVersion = 3;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final String dir = await getDatabasesPath();
    final String path = p.join(dir, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL DEFAULT '',
        author TEXT NOT NULL DEFAULT '',
        isbn TEXT NOT NULL DEFAULT '',
        price REAL NOT NULL DEFAULT 0,
        progress REAL NOT NULL DEFAULT 0,
        source TEXT NOT NULL DEFAULT '手动录入',
        weread_id TEXT NOT NULL DEFAULT '',
        read_seconds INTEGER NOT NULL DEFAULT 0,
        finished_at INTEGER NOT NULL DEFAULT 0,
        excluded INTEGER NOT NULL DEFAULT 0,
        pay_type INTEGER NOT NULL DEFAULT 0,
        manual_fields TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE cost_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT '设备',
        amount REAL NOT NULL DEFAULT 0,
        date INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE reading_summary(
        id INTEGER PRIMARY KEY CHECK (id = 1),
        total_seconds INTEGER NOT NULL DEFAULT 0,
        week_seconds INTEGER NOT NULL DEFAULT 0,
        month_seconds INTEGER NOT NULL DEFAULT 0,
        year_seconds INTEGER NOT NULL DEFAULT 0,
        read_days INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.insert('reading_summary', <String, Object?>{'id': 1});
  }

  /// 升级：
  ///   v1 → v2 补上 manual_fields 列（老数据默认空，即「没手动改过」）；
  ///   v2 → v3 补上 pay_type 列（老数据为 0，重新同步后会自动补上类型）。
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE books ADD COLUMN manual_fields TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE books ADD COLUMN pay_type INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  // ---------------- 书籍 ----------------

  Future<List<Book>> allBooks() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows =
        await db.query('books', orderBy: 'price DESC, id DESC');
    return rows.map(Book.fromMap).toList();
  }

  Future<int> insertBook(Book book) async {
    final Database db = await database;
    return db.insert('books', book.toMap());
  }

  Future<void> updateBook(Book book) async {
    final Database db = await database;
    final Map<String, Object?> map = book.toMap();
    map.remove('id');
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await db.update('books', map, where: 'id = ?', whereArgs: <Object?>[book.id]);
  }

  Future<void> deleteBook(int id) async {
    final Database db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// 批量删除。一次事务内完成，避免逐条删除时的中间态。
  Future<int> deleteBooks(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final Database db = await database;
    final String marks = List<String>.filled(ids.length, '?').join(',');
    return db.delete('books', where: 'id IN ($marks)', whereArgs: ids);
  }

  /// 用导入的数据整体替换书籍表。
  Future<void> replaceAllBooks(List<Book> books) async {
    final Database db = await database;
    await db.transaction((Transaction txn) async {
      await txn.delete('books');
      for (final Book b in books) {
        final Map<String, Object?> map = b.toMap();
        map.remove('id');
        await txn.insert('books', map);
      }
    });
  }

  // ---------------- 成本 ----------------

  Future<List<CostItem>> allCosts() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows =
        await db.query('cost_items', orderBy: 'date DESC, id DESC');
    return rows.map(CostItem.fromMap).toList();
  }

  Future<int> insertCost(CostItem item) async {
    final Database db = await database;
    return db.insert('cost_items', item.toMap());
  }

  Future<void> updateCost(CostItem item) async {
    final Database db = await database;
    final Map<String, Object?> map = item.toMap();
    map.remove('id');
    await db.update('cost_items', map, where: 'id = ?', whereArgs: <Object?>[item.id]);
  }

  Future<void> deleteCost(int id) async {
    final Database db = await database;
    await db.delete('cost_items', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> replaceAllCosts(List<CostItem> items) async {
    final Database db = await database;
    await db.transaction((Transaction txn) async {
      await txn.delete('cost_items');
      for (final CostItem c in items) {
        final Map<String, Object?> map = c.toMap();
        map.remove('id');
        await txn.insert('cost_items', map);
      }
    });
  }

  // ---------------- 阅读统计 ----------------

  Future<ReadingSummary> readingSummary() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows =
        await db.query('reading_summary', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return ReadingSummary();
    return ReadingSummary.fromMap(rows.first);
  }

  Future<void> saveReadingSummary(ReadingSummary summary) async {
    final Database db = await database;
    final Map<String, Object?> map = summary.toMap();
    map['id'] = 1;
    await db.insert('reading_summary', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------- 维护 ----------------

  Future<void> clearBooks() async {
    final Database db = await database;
    await db.delete('books');
  }

  Future<void> clearCosts() async {
    final Database db = await database;
    await db.delete('cost_items');
  }

  Future<void> clearSummary() async {
    final Database db = await database;
    await db.delete('reading_summary');
    await db.insert('reading_summary', <String, Object?>{'id': 1});
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
