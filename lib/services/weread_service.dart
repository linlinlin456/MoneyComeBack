import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/book.dart';
import '../models/reading_summary.dart';

/// 微信读书官方 Skill 网关客户端。
///
/// API Key 在 https://weread.qq.com/r/weread-skills 扫码获取（免费）。
/// 官方仓库：https://github.com/tencent/wechatreading
///
/// 字段口径（依官方文档）：
/// 1. `/readdata/detail` 的 `totalReadTime` 单位是**秒**，禁止当分钟/小时；
///    `readTimes` / `dailyReadTimes` 只是分桶明细，不能当总量口径。
/// 2. `/shelf/sync` 的 `books[]` 只有书名、作者、分类等，**不含阅读进度、不含售价**；
///    进度要另调 `/book/getprogress`（`book.progress` 为 0-100 整数，100 才算读完）。
/// 3. 官方 Skill 网关会对回包做**字段裁剪**，`/store/search` 的 `price` 被裁掉了；
///    定价改从**网页版公开接口** `/web/search/global` 取（无需登录、单位是元）。
class WeReadService {
  static const String gateway = 'https://i.weread.qq.com/api/agent/gateway';
  static const String skillVersion = '1.0.4';

  /// 网页版公开搜索接口：无需登录，回包带 `bookInfo.price`（**单位是元**）。
  /// 这是目前唯一能自动拿到书籍定价的入口 —— 官方网关那份回包没有价格字段。
  static const String webSearchApi = 'https://weread.qq.com/web/search/global';

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final String apiKey;

  WeReadService(this.apiKey);

  Future<Map<String, dynamic>> _call(
    String apiName, [
    Map<String, dynamic>? extra,
  ]) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'api_name': apiName,
      'skill_version': skillVersion,
    };
    if (extra != null) body.addAll(extra);

    final http.Response resp = await http
        .post(
          Uri.parse(gateway),
          headers: <String, String>{
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));

    if (resp.statusCode == 401) {
      throw Exception('API Key 无效或已过期，请回微信读书重新获取');
    }
    if (resp.statusCode != 200) {
      throw Exception('微信读书接口返回 ${resp.statusCode}');
    }
    final dynamic decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    if (decoded is! Map) {
      throw Exception('微信读书接口返回格式异常');
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// 业务数据层：网关可能把结果包在 `data` 里。
  static Map<String, dynamic> _payload(Map<String, dynamic> raw) {
    final dynamic d = raw['data'];
    if (d is Map) return Map<String, dynamic>.from(d);
    return raw;
  }

  // ---------------- 书架 ----------------

  /// 拉取书架（电子书）。进度先按 `finishReading` 判定，
  /// 其余由 [fetchProgress] 逐本补齐；价格留空等用户填。
  Future<List<Book>> fetchShelf() async {
    final Map<String, dynamic> data = _payload(await _call('/shelf/sync'));
    final List<dynamic> raw =
        _findList(data, const <String>['books']) ??
            _deepFindList(data, const <String>['books']) ??
            <dynamic>[];
    final List<Book> result = <Book>[];
    for (final dynamic item in raw) {
      if (item is! Map) continue;
      final Book book = _parseShelfItem(Map<String, dynamic>.from(item));
      if (book.title.isNotEmpty) result.add(book);
    }
    return result;
  }

  Book _parseShelfItem(Map<String, dynamic> m) {
    final String title = _firstString(m, const <String>['title', 'bookName', 'name']);
    final String author = _firstString(m, const <String>['author', 'authorName']);
    final String bookId = _firstString(m, const <String>['bookId', 'book_id', 'id']);
    final int finished = _firstInt(m, const <String>['finishReading']) ?? 0;

    return Book(
      title: title,
      author: author,
      isbn: '',
      price: 0,
      // -1 表示「接口未给进度，待 getprogress 补齐」
      progress: finished == 1 ? 1.0 : -1.0,
      source: '微信读书',
      wereadId: bookId,
    );
  }

  /// 单本书的阅读进度，返回 0.0~1.0；取不到时返回 null。
  ///
  /// 官方口径：`book.progress` 是 0-100 的整数，1 表示 1%，100 才是读完。
  Future<double?> fetchProgress(String bookId) async {
    if (bookId.isEmpty) return null;
    try {
      final Map<String, dynamic> data = _payload(
        await _call('/book/getprogress', <String, dynamic>{'bookId': bookId}),
      );
      int? pct;
      final dynamic book = data['book'];
      if (book is Map) {
        pct = _firstInt(Map<String, dynamic>.from(book), const <String>['progress']);
      }
      pct ??= _firstInt(data, const <String>['progress']);
      if (pct == null) return null;
      return (pct / 100.0).clamp(0.0, 1.0);
    } catch (_) {
      return null;
    }
  }

  // ---------------- 阅读统计 ----------------

  /// 拉取四个周期的阅读统计。任一周期失败按 0 处理，不影响其余。
  Future<ReadingSummary> fetchSummary() async {
    final Map<String, dynamic> overall = await _readRaw('overall');
    final Map<String, dynamic> weekly = await _readRaw('weekly');
    final Map<String, dynamic> monthly = await _readRaw('monthly');
    final Map<String, dynamic> annually = await _readRaw('annually');

    return ReadingSummary(
      totalSeconds: _totalReadTime(overall),
      weekSeconds: _totalReadTime(weekly),
      monthSeconds: _totalReadTime(monthly),
      yearSeconds: _totalReadTime(annually),
      readDays: _firstInt(overall, const <String>['readDays']) ?? 0,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<Map<String, dynamic>> _readRaw(String mode) async {
    try {
      return _payload(
        await _call('/readdata/detail', <String, dynamic>{'mode': mode}),
      );
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// 该周期总阅读时长（秒）。
  ///
  /// 只认 `totalReadTime`；`readTimes` / `dailyReadTimes` 是分桶明细，
  /// 数值形态是"时间戳→秒数"的对象，不能拿来当总量。
  static int _totalReadTime(Map<String, dynamic> data) {
    final int? direct = _firstInt(data, const <String>['totalReadTime']);
    if (direct != null) return direct;
    return _deepFindInt(data, const <String>['totalReadTime']) ?? 0;
  }

  // ---------------- 搜书（用于 ISBN / 书名补全） ----------------

  /// 在微信读书书城搜索，返回候选书籍（用于补作者、ISBN，不含价格）。
  Future<List<Book>> search(String keyword) async {
    try {
      final Map<String, dynamic> raw = await _call(
        '/store/search',
        <String, dynamic>{'keyword': keyword, 'scope': 10, 'count': 10},
      );
      final Map<String, dynamic> data = _payload(raw);
      final List<dynamic> list =
          _findList(data, const <String>['books', 'items', 'list']) ??
              _deepFindList(data, const <String>['books', 'items', 'list']) ??
              <dynamic>[];
      final List<Book> result = <Book>[];
      for (final dynamic item in list) {
        if (item is! Map) continue;
        final Map<String, dynamic> m = Map<String, dynamic>.from(item);
        final Map<String, dynamic> info = (m['bookInfo'] is Map)
            ? Map<String, dynamic>.from(m['bookInfo'] as Map)
            : m;
        final Book book = _parseShelfItem(info);
        if (book.title.isNotEmpty) result.add(book);
      }
      return result;
    } catch (_) {
      return <Book>[];
    }
  }

  // ---------------- 付费信息 ----------------

  /// 单本书的付费信息：先按 bookId 精确匹配搜索结果的定价；
  /// 匹配不上时，退回用章节接口判断这本书有没有标价。
  ///
  /// 来源：
  /// 1. `/store/search` 的 `results[].books[].bookInfo` —— 有 `price`（单位分）
  ///    和 `payType`；
  /// 2. `/book/chapterinfo` 的 `chapters[].price` —— 0 表示该章免费。
  ///
  /// 两个接口都不保证覆盖所有书，取不到就是取不到，不猜。
  Future<WeReadPrice?> fetchPrice(String bookId, String title) async {
    // 1) 网页版公开接口 —— 唯一能拿到真实定价的入口，优先。
    final WeReadPrice? byWeb = await _webSearchPrice(bookId, title);
    if (byWeb != null && (byWeb.price != 0 || byWeb.isFreeRead)) return byWeb;

    // 2) 官方网关搜索（价格常被裁剪，但能拿到 payType / ispub）
    final WeReadPrice? bySearch = await _searchPrice(bookId, title);
    if (bySearch != null && bySearch.price != 0) return bySearch;

    // 3) 章节接口兜底
    final WeReadPrice? byChapter = await fetchChapterPrice(bookId);
    if (byChapter != null && byChapter.price != 0) return byChapter;

    // 都没价：保留 payType / ispub，让上层按「付费会员书」判定，
    // 而不是一律当成免费书。
    final WeReadPrice? first = byWeb ?? bySearch ?? byChapter;
    return WeReadPrice(
      payType: first?.payType ?? 0,
      ispub: first?.ispub ?? 0,
      price: 0,
    );
  }

  /// 网页版公开搜索取价（无需登录）。
  ///
  /// 回包结构：`{"books":[{"bookInfo":{"bookId":"…","title":"…","price":44,…}}]}`
  /// —— `price` 单位是**元**（实测《猎魔人（卷八）》为 44）。
  ///
  /// 匹配规则：先按 bookId 精确比对，其次按书名完全相等；都不中返回 null，
  /// 绝不拿同名书的价格顶替。
  Future<WeReadPrice?> _webSearchPrice(String bookId, String title) async {
    final String kw = title.trim().isNotEmpty ? title.trim() : bookId.trim();
    if (kw.isEmpty) return null;
    try {
      final Uri uri = Uri.parse(webSearchApi).replace(
        queryParameters: <String, String>{
          'keyword': kw,
          'maxIdx': '0',
          'count': '10',
        },
      );
      final http.Response resp = await http
          .get(uri, headers: <String, String>{
            'User-Agent': _ua,
            'Referer': 'https://weread.qq.com/',
          })
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return null;
      final dynamic decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is! Map) return null;

      final List<Map<String, dynamic>> cands =
          _collectBookInfos(Map<String, dynamic>.from(decoded));
      if (cands.isEmpty) return null;

      final String want = bookId.trim();
      if (want.isNotEmpty) {
        for (final Map<String, dynamic> m in cands) {
          if (_strOf(m, const <String>['bookId', 'book_id', 'id']) == want) {
            return _webPriceOf(m);
          }
        }
      }
      final String t = title.trim();
      if (t.isNotEmpty) {
        for (final Map<String, dynamic> m in cands) {
          if (_strOf(m, const <String>['title', 'bookName', 'name']) == t) {
            return _webPriceOf(m);
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 网页版回包的取价：`price` 单位已经是元，不再除以 100。
  static WeReadPrice _webPriceOf(Map<String, dynamic> m) {
    num? v = _firstNum(m, const <String>['price', 'salePrice', 'originalPrice']);
    v ??= _deepFindNum(m, const <String>['price']);
    return WeReadPrice(
      payType: _firstInt(m, const <String>['payType']) ??
          _deepFindInt(m, const <String>['payType']) ??
          0,
      ispub: _firstInt(m, const <String>['ispub']) ??
          _deepFindInt(m, const <String>['ispub']) ??
          0,
      price: v == null ? 0 : v.toDouble(),
    );
  }

  /// 走书城搜索取价。找不到精确匹配就返回 null（绝不拿同名书的价格顶替）。
  Future<WeReadPrice?> _searchPrice(String bookId, String title) async {
    if (title.isEmpty && bookId.isEmpty) return null;
    try {
      final Map<String, dynamic> data = _payload(
        await _call('/store/search', <String, dynamic>{
          'keyword': title.isEmpty ? bookId : title,
          'scope': 10,
          'count': 10,
        }),
      );
      final List<Map<String, dynamic>> candidates = _collectBookInfos(data);
      if (candidates.isEmpty) return null;

      final String want = bookId.trim();
      if (want.isNotEmpty) {
        for (final Map<String, dynamic> m in candidates) {
          // 两侧都按字符串比较：接口可能一处给字符串、一处给数字，
          // 直接比类型会全部匹配失败（这就是之前「全是免费」的原因）。
          if (_strOf(m, const <String>['bookId', 'book_id', 'id']) == want) {
            return _priceOf(m);
          }
        }
        return null;
      }

      // 没有 bookId 时退化为书名精确匹配。
      for (final Map<String, dynamic> m in candidates) {
        if (_strOf(m, const <String>['title', 'bookName', 'name']) == title) {
          return _priceOf(m);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 用章节列表判断有没有标价：任一章 price > 0 即视为付费书。
  Future<WeReadPrice?> fetchChapterPrice(String bookId) async {
    if (bookId.isEmpty) return null;
    try {
      final Map<String, dynamic> data = _payload(
        await _call('/book/chapterinfo', <String, dynamic>{'bookId': bookId}),
      );
      final List<dynamic>? list = _findList(data, const <String>['chapters']) ??
          _deepFindList(data, const <String>['chapters']);
      if (list == null) return null;
      for (final dynamic c in list) {
        if (c is! Map) continue;
        final Map<String, dynamic> m = Map<String, dynamic>.from(c);
        final num? v = _firstNum(m, const <String>['price']);
        if (v != null && v > 0) {
          return WeReadPrice(
            payType: _firstInt(m, const <String>['payType']) ?? 0,
            ispub: _firstInt(m, const <String>['ispub']) ?? 0,
            price: _numToYuan(v),
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 从搜索回包里捞出所有 `bookInfo`（结构不固定，逐层兜底）。
  static List<Map<String, dynamic>> _collectBookInfos(
    Map<String, dynamic> data,
  ) {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    final List<dynamic> groups =
        _findList(data, const <String>['results', 'books', 'items', 'list']) ??
            _deepFindList(data, const <String>['results']) ??
            <dynamic>[];

    // 把 bookInfo 的字段并进外层元素：价格有时挂在内层、有时挂在外层，
    // 合并后任意一层有都能取到。
    void take(dynamic node) {
      if (node is! Map) return;
      final Map<String, dynamic> merged = Map<String, dynamic>.from(node);
      final dynamic info = node['bookInfo'];
      if (info is Map) {
        for (final MapEntry<dynamic, dynamic> e in info.entries) {
          merged.putIfAbsent(e.key, () => e.value);
        }
      }
      if (merged.containsKey('bookId') ||
          merged.containsKey('title') ||
          merged.containsKey('payType')) {
        out.add(merged);
      }
    }

    for (final dynamic g in groups) {
      if (g is Map) {
        final dynamic books = g['books'];
        if (books is List) {
          for (final dynamic b in books) {
            take(b);
          }
          continue;
        }
      }
      take(g);
    }

    // 兜底：整包深搜 bookInfo。
    if (out.isEmpty) {
      void walk(dynamic node) {
        if (node is Map) {
          final dynamic info = node['bookInfo'];
          if (info is Map) out.add(Map<String, dynamic>.from(info));
          for (final dynamic v in node.values) {
            walk(v);
          }
        } else if (node is List) {
          for (final dynamic v in node) {
            walk(v);
          }
        }
      }

      walk(data);
    }
    return out;
  }

  /// 从一本书的候选数据里取价与付费类型。
  ///
  /// 价格字段的位置并不固定（可能在 bookInfo 内、也可能在外层，字段名也不止
  /// 一个），所以先按常见字段名找，找不到就在整棵子树里递归找 `price`。
  static WeReadPrice _priceOf(Map<String, dynamic> m) {
    num? v = _firstNum(m, const <String>[
      'price',
      'salePrice',
      'priceCent',
      'bookPrice',
      'originalPrice',
      'payPrice',
    ]);
    v ??= _deepFindNum(m, const <String>['price', 'salePrice', 'priceCent']);

    return WeReadPrice(
      payType: _firstInt(m, const <String>['payType']) ??
          _deepFindInt(m, const <String>['payType']) ??
          0,
      ispub: _firstInt(m, const <String>['ispub']) ??
          _deepFindInt(m, const <String>['ispub']) ??
          0,
      // 负数（如 -1）表示「不单独售卖 / 仅付费会员可读」，不是价格，原样保留。
      price: v == null ? 0 : (v < 0 ? -1.0 : _numToYuan(v)),
    );
  }

  /// 在任意层级递归找数值字段（跳过 bookInfo 自身已被合并过的重复）。
  static num? _deepFindNum(dynamic node, List<String> keys) {
    if (node is Map) {
      for (final MapEntry<dynamic, dynamic> e in node.entries) {
        if (keys.contains(e.key.toString()) && e.value is num) {
          return e.value as num;
        }
      }
      for (final dynamic val in node.values) {
        final num? r = _deepFindNum(val, keys);
        if (r != null) return r;
      }
    } else if (node is List) {
      for (final dynamic item in node) {
        final num? r = _deepFindNum(item, keys);
        if (r != null) return r;
      }
    }
    return null;
  }

  /// 官方口径 price 单位是**分**；若接口返回带小数的值，说明它给的是元。
  static double _numToYuan(num v) {
    final double d = v.toDouble();
    if (v is double && d != d.roundToDouble()) return d;
    return d / 100.0;
  }

  static String _strOf(Map<String, dynamic> m, List<String> keys) {
    for (final String k in keys) {
      final dynamic v = m[k];
      if (v == null) continue;
      final String t = v.toString().trim();
      if (t.isNotEmpty && t != 'null') return t;
    }
    return '';
  }

  static num? _firstNum(Map<String, dynamic> m, List<String> keys) {
    for (final String k in keys) {
      final dynamic v = m[k];
      if (v is num) return v;
      if (v is String) {
        final num? parsed = num.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  // ---------------- 接口自检 ----------------

  /// 拉一遍关键接口，把**真实回包**摊开，用于排查同步取不到数据的原因。
  /// 只读，不改任何本地数据。
  Future<String> diagnose() async {
    final StringBuffer b = StringBuffer();
    const JsonEncoder pretty = JsonEncoder.withIndent('  ');

    String cut(Object? o, [int max = 2600]) {
      final String t = o == null ? 'null' : pretty.convert(o);
      return t.length <= max ? t : '${t.substring(0, max)}\n…（已截断）';
    }

    // 1) 书架
    String title = '';
    String bid = '';
    try {
      final Map<String, dynamic> shelf = _payload(await _call('/shelf/sync'));
      final List<dynamic> books =
          _findList(shelf, const <String>['books']) ??
              _deepFindList(shelf, const <String>['books']) ??
              <dynamic>[];
      b.writeln('【1. 书架 /shelf/sync】共 ${books.length} 本');
      if (books.isNotEmpty && books.first is Map) {
        final Map<String, dynamic> m =
            Map<String, dynamic>.from(books.first as Map);
        title = _strOf(m, const <String>['title', 'bookName']);
        bid = _strOf(m, const <String>['bookId', 'book_id', 'id']);
        b.writeln('第一本原始数据：');
        b.writeln(cut(m, 1200));
      }
      b.writeln('');
    } catch (e) {
      b.writeln('书架接口出错：$e\n');
    }

    if (title.isEmpty && bid.isEmpty) return b.toString();

    // 2) 搜索：把第一条候选的**完整原始 JSON** 打出来
    try {
      final Map<String, dynamic> data = _payload(
        await _call('/store/search', <String, dynamic>{
          'keyword': title.isEmpty ? bid : title,
          'scope': 10,
          'count': 10,
        }),
      );
      b.writeln('【2. 书城搜索 /store/search】');
      b.writeln('顶层字段：${data.keys.join(' , ')}');
      final dynamic results = data['results'];
      if (results is List) {
        for (int i = 0; i < results.length; i++) {
          final dynamic g = results[i];
          if (g is! Map) continue;
          final dynamic books = g['books'];
          b.writeln('results[$i] 字段：${g.keys.join(' , ')}'
              '${books is List ? '，books 长度 ${books.length}' : ''}');
        }
      }
      b.writeln('');
      b.writeln('—— 第一条候选的完整原始 JSON（重点看 price 在哪一层）——');
      final List<Map<String, dynamic>> raw = _collectBookInfos(data);
      if (raw.isNotEmpty) {
        b.writeln(cut(raw.first, 2600));
      } else {
        b.writeln('没解析出候选，回包前 2600 字符：');
        b.writeln(cut(data, 2600));
      }
      b.writeln('');
      b.writeln('解析出候选 ${raw.length} 条，各自的取价结果：');
      for (int i = 0; i < raw.length && i < 6; i++) {
        final WeReadPrice pr = _priceOf(raw[i]);
        b.writeln(
          '  [$i] bookId=${_strOf(raw[i], const <String>['bookId', 'book_id', 'id'])}'
          ' → price=${pr.price} payType=${pr.payType}'
          ' 判定=${pr.isPaid ? '付费' : '免费'}',
        );
      }
      b.writeln('书架上这本的 bookId = $bid');
      b.writeln('');

      // 网页版公开接口：能拿到网关裁剪掉的价格
      b.writeln('—— 网页版公开接口（/web/search/global，无需登录）——');
      try {
        final WeReadPrice? web = await _webSearchPrice(bid, title);
        if (web == null) {
          b.writeln('  没匹配到这本书');
        } else {
          b.writeln('  bookId=$bid → price=${web.price} 元'
              ' payType=${web.payType} 判定=${web.isPaid ? '付费' : '免费'}');
          if (web.price > 0) {
            b.writeln('  ✅ 拿到定价了，同步会用它折算书值');
          } else {
            b.writeln('  ⚠️ 接口也没给价，这本书需要手动填');
          }
        }
      } catch (e) {
        b.writeln('  网页版接口出错：$e');
      }
      b.writeln('');

      // 换几个 scope 再试，看哪个参数下回包才带 price。
      b.writeln('—— 不同 scope 下能否拿到价格 ——');
      for (final int sc in <int>[10, 16, 17]) {
        try {
          final Map<String, dynamic> d2 = _payload(
            await _call('/store/search', <String, dynamic>{
              'keyword': title,
              'scope': sc,
              'count': 10,
            }),
          );
          final List<Map<String, dynamic>> c2 = _collectBookInfos(d2);
          int withPrice = 0;
          num sample = 0;
          for (final Map<String, dynamic> m in c2) {
            final WeReadPrice pr = _priceOf(m);
            if (pr.price > 0) {
              withPrice++;
              sample = pr.price;
            }
          }
          b.writeln('  scope=$sc：候选 ${c2.length} 条，'
              '其中有价 $withPrice 条${withPrice > 0 ? '（例：$sample）' : ''}');
        } catch (e) {
          b.writeln('  scope=$sc：出错 $e');
        }
      }
      b.writeln('');
    } catch (e) {
      b.writeln('搜索接口出错：$e\n');
    }

    // 3) 章节：统计有多少章带价
    try {
      final Map<String, dynamic> ch = _payload(
        await _call('/book/chapterinfo', <String, dynamic>{'bookId': bid}),
      );
      final List<dynamic>? chapters =
          _findList(ch, const <String>['chapters']) ??
              _deepFindList(ch, const <String>['chapters']);
      int paid = 0;
      num maxPrice = 0;
      if (chapters != null) {
        for (final dynamic c in chapters) {
          if (c is! Map) continue;
          final num? v = _firstNum(Map<String, dynamic>.from(c), const <String>['price']);
          if (v != null && v > 0) {
            paid++;
            if (v > maxPrice) maxPrice = v;
          }
        }
      }
      b.writeln('【3. 章节 /book/chapterinfo】');
      b.writeln('章节数 ${chapters?.length ?? 0}，'
          '其中有价的 $paid 章，最高价 $maxPrice');
      if (chapters != null && chapters.isNotEmpty && chapters.first is Map) {
        b.writeln('第一章原始数据：');
        b.writeln(cut(Map<String, dynamic>.from(chapters.first as Map), 800));
      }
    } catch (e) {
      b.writeln('章节接口出错：$e');
    }

    return b.toString();
  }


  // ---------------- JSON 取值工具 ----------------

  /// 只在当前层找数组，避免误取到深层同名字段。
  static List<dynamic>? _findList(Map<String, dynamic> node, List<String> keys) {
    for (final String k in keys) {
      final dynamic v = node[k];
      if (v is List) return v;
    }
    return null;
  }

  static List<dynamic>? _deepFindList(dynamic node, List<String> keys) {
    if (node is Map) {
      for (final MapEntry<dynamic, dynamic> e in node.entries) {
        if (keys.contains(e.key.toString()) && e.value is List) {
          return e.value as List<dynamic>;
        }
      }
      for (final dynamic v in node.values) {
        final List<dynamic>? r = _deepFindList(v, keys);
        if (r != null) return r;
      }
    } else if (node is List) {
      for (final dynamic item in node) {
        final List<dynamic>? r = _deepFindList(item, keys);
        if (r != null) return r;
      }
    }
    return null;
  }

  static int? _deepFindInt(dynamic node, List<String> keys) {
    if (node is Map) {
      for (final MapEntry<dynamic, dynamic> e in node.entries) {
        if (keys.contains(e.key.toString()) && e.value is num) {
          return (e.value as num).toInt();
        }
      }
      for (final dynamic v in node.values) {
        final int? r = _deepFindInt(v, keys);
        if (r != null) return r;
      }
    } else if (node is List) {
      for (final dynamic item in node) {
        final int? r = _deepFindInt(item, keys);
        if (r != null) return r;
      }
    }
    return null;
  }

  static String _firstString(Map<String, dynamic> m, List<String> keys) {
    for (final String k in keys) {
      final dynamic v = m[k];
      if (v == null) continue;
      // 兼容接口把 bookId 等字段返回成数字的情况。
      final String t = v.toString().trim();
      if (t.isNotEmpty && t != 'null') return t;
    }
    return '';
  }

  static int? _firstInt(Map<String, dynamic> m, List<String> keys) {
    for (final String k in keys) {
      final dynamic v = m[k];
      if (v is num) return v.toInt();
      if (v is String) {
        final int? parsed = int.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}

/// 微信读书的付费信息。
///
/// [price] 单位是元。网页版接口直接给元；网关回包若给的是分，会先换算。
/// [payType] 是接口的付费类型原值，用于「是付费书但接口没给价」的兜底判定。
class WeReadPrice {
  final int payType;
  final double price;

  /// 1 = 出版书；2 = 网文 / 连载；0 = 未知。仅作 payType 缺失时的兜底判据。
  final int ispub;

  const WeReadPrice({this.payType = 0, this.price = 0, this.ispub = 0});

  /// 免费阅读（含体验卡可读）—— **不计入付费书**。
  ///
  /// 实测 163 本书的样本：`payType == 1`（0x1）的书 price 恒为 0，
  /// 属于完全免费 / 体验卡可读那一类。
  bool get isFreeRead => payType == 1 || (price == 0 && payType == 0);

  /// 付费会员可读（需要付费会员卡才能读全本）—— **计入付费书**。
  ///
  /// 实测判据：
  /// 1. `price > 0`：有单独定价的出版书（payType 常见 1048577 / 4097 / 34701313）；
  /// 2. `price < 0`（-1）：不单独售卖、只能会员读（网文 / 连载常见）；
  /// 3. `payType` 含 0x100000 或 0x1000 位：出版书；
  /// 4. `payType` 含 0x200000 位：网文 / 连载，同样要会员。
  bool get isMemberBook {
    if (isFreeRead) return false;
    if (price != 0) return true;
    if (payType != 0) {
      return (payType & 0x100000) != 0 ||
          (payType & 0x200000) != 0 ||
          (payType & 0x1000) != 0;
    }
    // payType 缺失时退到 ispub：1 = 出版书、2 = 网文，两类都要付费会员。
    return ispub == 1 || ispub == 2;
  }

  /// 兼容旧名。
  bool get isPaid => isMemberBook;

  /// 判定是付费会员书，但接口没给出单独定价 —— 需要你手动填。
  bool get needsManualPrice => isMemberBook && price == 0;
}
