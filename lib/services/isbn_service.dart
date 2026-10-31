import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/book.dart';

/// 用 ISBN 反查书名 / 作者。
///
/// 国内没有免费且稳定的中文图书定价接口，所以这里的策略是：
/// 先通过开放图书库拿到书名和作者，价格能拿到就用、拿不到留空由用户手填。
/// 后续还可以用书名去微信读书书城搜索来补价格。
class IsbnService {
  static Future<Book?> lookup(String rawIsbn) async {
    final String isbn = rawIsbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
    if (isbn.length < 10) return null;

    Book? book = await _fromGoogleBooks(isbn);
    book ??= await _fromOpenLibrary(isbn);
    if (book == null) {
      return Book(isbn: isbn, source: 'ISBN 查询');
    }
    return book;
  }

  static Future<Book?> _fromGoogleBooks(String isbn) async {
    try {
      final http.Response resp = await http
          .get(Uri.parse(
            'https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn',
          ))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final dynamic decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is! Map) return null;
      final List<dynamic>? items = decoded['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;
      final dynamic volumeInfo = (items.first as Map)['volumeInfo'];
      if (volumeInfo is! Map) return null;
      final Map<String, dynamic> info = Map<String, dynamic>.from(volumeInfo);
      final String title = (info['title'] as String?) ?? '';
      if (title.isEmpty) return null;
      final List<dynamic>? authors = info['authors'] as List<dynamic>?;
      return Book(
        title: title,
        author: authors == null ? '' : authors.join('、'),
        isbn: isbn,
        source: 'ISBN 查询',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Book?> _fromOpenLibrary(String isbn) async {
    try {
      final http.Response resp = await http
          .get(Uri.parse(
            'https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data',
          ))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final dynamic decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is! Map) return null;
      final dynamic entry = decoded['ISBN:$isbn'];
      if (entry is! Map) return null;
      final Map<String, dynamic> info = Map<String, dynamic>.from(entry);
      final String title = (info['title'] as String?) ?? '';
      if (title.isEmpty) return null;
      String author = '';
      final List<dynamic>? authors = info['authors'] as List<dynamic>?;
      if (authors != null && authors.isNotEmpty) {
        author = authors
            .map((e) => (e is Map ? (e['name'] ?? '') : '').toString())
            .where((e) => e.isNotEmpty)
            .join('、');
      }
      return Book(
        title: title,
        author: author,
        isbn: isbn,
        source: 'ISBN 查询',
      );
    } catch (_) {
      return null;
    }
  }
}
