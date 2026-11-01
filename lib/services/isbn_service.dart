import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/book.dart';

/// 用 ISBN 反查书名 / 作者 / 定价。
///
/// 取数顺序（都是国内能直连的源，单源超时 6 秒，失败快速切下一个）：
///   1. 豆瓣读书网页版 —— 免费、无需登录，能拿到书名 / 作者 / 出版社 / 定价；
///   2. 微信读书网页版公开搜索 —— 无需登录，补书名和作者（不含价格）；
///   3. 都拿不到就只回填 ISBN，其余字段由用户手填。
///
/// 为什么不再用 Google Books / Open Library：
/// 这两个接口数据全、也免注册，但**国内直连不通**；串行等两个 15 秒超时
/// 会把「扫完到出结果」拖到 30 秒，最后还是什么都拿不到。
class IsbnService {
  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// 单个数据源的超时。宁可快速失败换下一个，也不让用户干等。
  static const Duration _timeout = Duration(seconds: 6);

  /// 内存缓存：同一个 ISBN 第二次扫直接命中，不再打网络。
  static final Map<String, Book> _cache = <String, Book>{};

  /// 查一本书；返回 null 表示这串码根本不像 ISBN（长度不够）。
  ///
  /// 拿不到书名时返回的 Book 只带 isbn，由上层决定怎么处理。
  static Future<Book?> lookup(String rawIsbn) async {
    final String isbn = rawIsbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
    if (isbn.length < 10) return null;

    final Book? hit = _cache[isbn];
    if (hit != null) return hit;

    Book? book = await _fromDouban(isbn);
    if (book == null || book.title.isEmpty) {
      book = await _fromWeread(isbn) ?? book;
    }
    book ??= Book(isbn: isbn, source: 'ISBN 查询');
    if (book.title.isNotEmpty) _cache[isbn] = book;
    return book;
  }

  // ---------------- 豆瓣读书 ----------------

  /// 豆瓣的 ISBN 直达地址会 301 跳到书籍详情页（http 会自动跟随重定向）。
  static Future<Book?> _fromDouban(String isbn) async {
    try {
      final http.Response resp = await http.get(
        Uri.parse('https://book.douban.com/isbn/$isbn/'),
        headers: <String, String>{
          'User-Agent': _ua,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9',
          'Referer': 'https://book.douban.com/',
        },
      ).timeout(_timeout);
      if (resp.statusCode != 200) return null;

      final String html = utf8.decode(resp.bodyBytes, allowMalformed: true);
      final String title = _doubanTitle(html);
      if (title.isEmpty) return null;

      return Book(
        title: title,
        author: _field(html, '作者', isLink: true),
        isbn: isbn,
        price: _parsePrice(_field(html, '定价')),
        source: 'ISBN 查询',
      );
    } catch (_) {
      return null;
    }
  }

  /// 书名：`<title>三体 (豆瓣)</title>` → `三体`。
  static String _doubanTitle(String html) {
    final Match? m = RegExp(r'<title>\s*([\s\S]*?)\s*\(豆瓣\)').firstMatch(html);
    if (m == null) return '';
    return _unescape(m.group(1) ?? '').trim();
  }

  /// 从 `#info` 区块按字段名取值。
  ///
  /// 豆瓣的写法：
  ///   `<span class="pl">出版社:</span> 重庆出版社`
  ///   `<span class="pl"> 作者</span>: <a href="…">刘慈欣</a>`
  static String _field(String html, String label, {bool isLink = false}) {
    final String head = r'<span class="pl">\s*' + label + r'\s*[:：]?\s*</span>';
    final String tail = isLink
        ? r'\s*:?\s*<a[^>]*>\s*([^<]{1,80}?)\s*</a>'
        : r'\s*([^<]{1,80})';
    final Match? m = RegExp(head + tail).firstMatch(html);
    if (m == null) return '';
    return _unescape(m.group(1) ?? '').trim();
  }

  /// 「23.00元」→ 23.0；取不到数字返回 0。
  static double _parsePrice(String raw) {
    final Match? m = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(raw);
    if (m == null) return 0;
    return double.tryParse(m.group(1)!) ?? 0;
  }

  // ---------------- 微信读书（兜底补书名 / 作者） ----------------

  /// 网页版公开搜索，无需登录。回包里挖 `bookInfo` 取书名和作者。
  static Future<Book?> _fromWeread(String isbn) async {
    try {
      final Uri uri = Uri.parse('https://weread.qq.com/web/search/global')
          .replace(queryParameters: <String, String>{
        'keyword': isbn,
        'maxIdx': '0',
        'count': '10',
      });
      final http.Response resp = await http.get(uri, headers: <String, String>{
        'User-Agent': _ua,
        'Referer': 'https://weread.qq.com/',
      }).timeout(_timeout);
      if (resp.statusCode != 200) return null;

      final dynamic decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is! Map) return null;

      for (final Map<String, dynamic> info
          in _collectBookInfos(Map<String, dynamic>.from(decoded))) {
        final String title =
            (info['title'] ?? info['bookName'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        final String author = (info['author'] ?? '').toString().trim();
        return Book(
          title: title,
          author: author,
          isbn: isbn,
          source: 'ISBN 查询',
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 递归挖出回包里所有 `bookInfo` 节点（接口层级不固定）。
  static List<Map<String, dynamic>> _collectBookInfos(
    dynamic node, [
    int depth = 0,
  ]) {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    if (depth > 6) return out;
    if (node is Map) {
      final Map<String, dynamic> m = Map<String, dynamic>.from(node);
      final dynamic bi = m['bookInfo'];
      if (bi is Map) out.add(Map<String, dynamic>.from(bi));
      for (final dynamic v in m.values) {
        out.addAll(_collectBookInfos(v, depth + 1));
      }
    } else if (node is List) {
      for (final dynamic v in node) {
        out.addAll(_collectBookInfos(v, depth + 1));
      }
    }
    return out;
  }

  /// 还原 HTML 实体，避免书名里残留 `&amp;` 这类写法。
  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');
}
