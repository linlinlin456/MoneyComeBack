import 'package:flutter/foundation.dart';

import '../data/db_helper.dart';
import '../models/app_settings.dart';
import '../models/book.dart';
import '../models/cost_item.dart';
import '../models/reading_summary.dart';
import '../services/backup_service.dart';
import '../services/stats_service.dart';
import '../services/weread_service.dart';

/// 全局状态：数据、设置、同步与备份。
class AppState extends ChangeNotifier {
  final DbHelper _db = DbHelper.instance;

  AppSettings settings = AppSettings();
  List<Book> books = <Book>[];
  List<CostItem> costs = <CostItem>[];
  ReadingSummary summary = ReadingSummary();

  bool loading = true;
  bool syncing = false;
  String syncMessage = '';

  RoiStats get stats => RoiStats.compute(
        books: books,
        costs: costs,
        byProgress: settings.valueByProgress,
        onlyPaidPricing: settings.onlyPaidPricing,
      );

  Future<void> init() async {
    settings = await AppSettings.load();
    await reload();
    loading = false;
    notifyListeners();
  }

  Future<void> reload() async {
    books = await _db.allBooks();
    costs = await _db.allCosts();
    summary = await _db.readingSummary();
    notifyListeners();
  }

  // ---------------- 书籍 ----------------

  Future<void> addBook(Book book) async {
    await _db.insertBook(book);
    await reload();
    await autoBackup();
  }

  Future<void> updateBook(Book book) async {
    await _db.updateBook(book);
    await reload();
    await autoBackup();
  }

  Future<void> deleteBook(int id) async {
    await _db.deleteBook(id);
    await reload();
    await autoBackup();
  }

  /// 批量删除（一次事务 + 一次备份，不是循环单删）。
  Future<int> deleteBooks(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final int n = await _db.deleteBooks(ids);
    await reload();
    await autoBackup();
    return n;
  }

  /// 解除某本书的手动保护，让它重新跟随微信读书同步。
  Future<void> resetManual(Book book) async {
    await _db.updateBook(book.clearManual());
    await reload();
    await autoBackup();
  }

  Future<void> toggleExcluded(Book book) async {
    await _db.updateBook(book.copyWith(excluded: !book.excluded));
    await reload();
    await autoBackup();
  }

  // ---------------- 成本 ----------------

  Future<void> addCost(CostItem item) async {
    await _db.insertCost(item);
    await reload();
    await autoBackup();
  }

  Future<void> updateCost(CostItem item) async {
    await _db.updateCost(item);
    await reload();
    await autoBackup();
  }

  Future<void> deleteCost(int id) async {
    await _db.deleteCost(id);
    await reload();
    await autoBackup();
  }

  // ---------------- 设置 ----------------

  Future<void> setValueByProgress(bool byProgress) async {
    settings.valueByProgress = byProgress;
    await settings.save();
    notifyListeners();
  }

  /// 定价记录范围：true = 只记付费书，false = 全部记录。
  Future<void> setOnlyPaidPricing(bool onlyPaid) async {
    settings.onlyPaidPricing = onlyPaid;
    await settings.save();
    notifyListeners();
  }

  /// 保存更新源地址。
  Future<void> setUpdateUrl(String url) async {
    settings.updateUrl = url.trim();
    await settings.save();
    notifyListeners();
  }

  Future<void> setAutoBackup(bool enabled) async {
    settings.autoBackup = enabled;
    await settings.save();
    notifyListeners();
  }

  Future<void> saveApiKey(String key) async {
    settings.wereadApiKey = key.trim();
    await settings.save();
    notifyListeners();
  }

  // ---------------- 微信读书同步 ----------------

  static String _keyOf(Book b) =>
      '${b.title.trim()}::${b.author.trim()}'.toLowerCase();

  /// 拉取微信读书书架与阅读统计，与本地数据合并。
  ///
  /// 注意：`/shelf/sync` 只返回书名/作者等基础信息，**不含阅读进度、不含售价**。
  /// 因此这里会逐本调 `/book/getprogress` 补齐进度（并发 6，避免请求过多）；
  /// 价格官方接口拿不到，保留你手动填写的值。
  Future<String> syncFromWeRead() async {
    if (settings.wereadApiKey.trim().isEmpty) {
      throw Exception('请先在设置里填入微信读书 API Key');
    }
    syncing = true;
    syncMessage = '正在拉取书架…';
    notifyListeners();
    try {
      final WeReadService service = WeReadService(settings.wereadApiKey.trim());
      final List<Book> remote = await service.fetchShelf();
      final ReadingSummary remoteSummary = await service.fetchSummary();

      // 书架接口不带阅读进度，逐本补齐（进度为 -1 表示尚未取到）。
      final List<Book> filled = await _fillProgress(service, remote);

      final Map<String, Book> localMap = <String, Book>{};
      for (final Book b in books) {
        localMap[_keyOf(b)] = b;
      }

      int added = 0;
      int updated = 0;
      int keptManual = 0;
      for (final Book r in filled) {
        final Book? old = localMap[_keyOf(r)];
        if (old == null) {
          // 新书：进度没取到（-1）时按 0 入库，避免负数落库。
          await _db.insertBook(r.progress < 0 ? r.copyWith(progress: 0) : r);
          added++;
        } else {
          // 增量合并：你手动改过的字段一律保留本地值，
          // 没动过的字段才用微信读书的数据刷新。
          // 这样反复点同步不会把你改的内容冲掉。
          final bool mTitle = old.isManual('title');
          final bool mAuthor = old.isManual('author');
          final bool mIsbn = old.isManual('isbn');
          final bool mPrice = old.isManual('price');
          final bool mProgress = old.isManual('progress');

          // 进度：接口取到了才更新，没取到（-1）保留本地值。
          final double fetched =
              r.progress >= 0 ? r.progress : old.progress;

          final Book merged = old.copyWith(
            title: mTitle ? old.title : r.title,
            author: mAuthor ? old.author : r.author,
            isbn: mIsbn ? old.isbn : (old.isbn.isEmpty ? r.isbn : old.isbn),
            price: mPrice ? old.price : r.price,
            source: mPrice ? old.source : r.source,
            progress: mProgress ? old.progress : fetched,
            wereadId: r.wereadId.isEmpty ? old.wereadId : r.wereadId,
            finishedAt: mProgress
                ? old.finishedAt
                : (fetched >= 1.0
                    ? (old.finishedAt > 0
                        ? old.finishedAt
                        : DateTime.now().millisecondsSinceEpoch)
                    : 0),
          );
          await _db.updateBook(merged);
          if (mTitle || mAuthor || mIsbn || mPrice || mProgress) keptManual++;
          updated++;
        }
      }
      await _db.saveReadingSummary(remoteSummary);

      settings.lastSyncAt = BackupService.describeTime(
        DateTime.now().millisecondsSinceEpoch,
      );
      await settings.save();
      await reload();

      syncMessage = '同步完成：新增 $added，更新 $updated'
          '${keptManual > 0 ? '，其中 $keptManual 本保留了你手动改过的字段' : ''}';
      return syncMessage;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// 逐本补齐阅读进度与定价。
  ///
  /// - 进度：书架接口不返回，只能一本一本调 `/book/getprogress`；
  /// - 定价：书架接口与详情接口都不返回，只能通过 `/store/search`
  ///   按书名搜索、再用 bookId 精确匹配，取其中的价格。
  ///
  /// 定价口径：有价格（> 0）即为付费/会员可读，记入价格；
  /// 免费书价格记 0，但进度照常同步。
  Future<List<Book>> _fillProgress(
    WeReadService service,
    List<Book> books,
  ) async {
    if (books.isEmpty) return books;
    const int batch = 3;
    final List<Book> out = <Book>[];
    for (int i = 0; i < books.length; i += batch) {
      final int end = (i + batch) > books.length ? books.length : i + batch;
      final List<Book> slice = books.sublist(i, end);
      final List<Book> done = await Future.wait(
        slice.map((Book b) => _enrichOne(service, b)),
      );
      out.addAll(done);
      syncMessage = '正在同步进度与定价 ${out.length}/${books.length}';
      notifyListeners();
    }
    return out;
  }

  /// 补齐单本书的进度与价格。
  Future<Book> _enrichOne(WeReadService service, Book book) async {
    Book result = book;

    // 进度：书架只给了「是否读完」，其余要单独查。
    if (result.progress < 0) {
      final double? p = await service.fetchProgress(result.wereadId);
      if (p != null) result = result.copyWith(progress: p);
    }

    // 定价：搜索接口取价，bookId 不匹配则视为拿不到。
    final WeReadPrice? info = await service.fetchPrice(
      result.wereadId,
      result.title,
    );
    final double price = info?.price ?? 0.0;
    final int payType = info?.payType ?? 0;
    // 来源标记跟着「可读类型」走，方便你在列表里核对：
    //   付费会员可读 → 微信读书（有定价）/ 微信读书·待填价（没定价）
    //   按章购买 → 微信读书·按章购买
    //   体验卡可读 → 微信读书·体验卡
    //   免费阅读 → 微信读书·免费
    final String source;
    if (payType != 0 && (payType & 0x100000) != 0) {
      source = price > 0 ? '微信读书' : '微信读书·待填价';
    } else if (payType != 0 && (payType & 0x200000) != 0) {
      source = '微信读书·按章购买';
    } else if (payType != 0 && (payType & 0x1000) != 0) {
      source = '微信读书·体验卡';
    } else if (payType != 0) {
      source = '微信读书·免费';
    } else {
      source = price > 0 ? '微信读书' : '微信读书·免费';
    }
    return result.copyWith(price: price, payType: payType, source: source);
  }

  /// 只同步阅读统计，不动书架。
  Future<void> syncSummaryOnly() async {
    if (settings.wereadApiKey.trim().isEmpty) {
      throw Exception('请先在设置里填入微信读书 API Key');
    }
    final WeReadService service = WeReadService(settings.wereadApiKey.trim());
    final ReadingSummary remoteSummary = await service.fetchSummary();
    await _db.saveReadingSummary(remoteSummary);
    await reload();
  }

  // ---------------- 备份 ----------------

  Future<void> autoBackup() async {
    if (!settings.autoBackup) return;
    try {
      await exportBackup();
    } catch (_) {
      // 备份失败不影响主流程
    }
  }

  /// 导出备份到 App 文档目录，返回文件路径。
  Future<String> exportBackup() async {
    final String json = BackupService.encode(
      books: books,
      costs: costs,
      summary: summary,
    );
    final String path = await BackupService.writeToAppDir(json);
    settings.lastBackupAt = DateTime.now().millisecondsSinceEpoch;
    await settings.save();
    notifyListeners();
    return path;
  }

  /// 从备份文件内容恢复。
  Future<String> importBackupText(String text) async {
    final BackupData data = BackupService.decode(text);
    await _db.replaceAllBooks(data.books);
    await _db.replaceAllCosts(data.costs);
    await _db.saveReadingSummary(data.summary);
    await reload();
    return '已恢复 ${data.books.length} 本书、${data.costs.length} 条成本';
  }

  Future<void> clearAll() async {
    await _db.clearBooks();
    await _db.clearCosts();
    await _db.clearSummary();
    await reload();
  }
}
