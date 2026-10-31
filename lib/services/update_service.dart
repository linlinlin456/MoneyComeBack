import 'dart:convert';

import 'package:http/http.dart' as http;

/// 更新源返回的版本信息。
class UpdateInfo {
  final String version;
  final int build;
  final String apkUrl;
  final String notes;

  const UpdateInfo({
    required this.version,
    required this.build,
    required this.apkUrl,
    this.notes = '',
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> m) {
    return UpdateInfo(
      version: (m['version'] ?? '').toString(),
      build: int.tryParse('${m['build'] ?? 0}') ?? 0,
      apkUrl: (m['apkUrl'] ?? m['apk_url'] ?? m['url'] ?? '').toString(),
      notes: (m['notes'] ?? m['changelog'] ?? '').toString(),
    );
  }
}

/// 检查更新：从更新源拉一份 version.json，和本机构建号比对。
///
/// 更新源就是一份放在公网上的 JSON，形如：
/// ```json
/// {
///   "version": "1.2.0",
///   "build": 10,
///   "apkUrl": "https://你的地址/本钱回笼记.apk",
///   "notes": "本次更新：……"
/// }
/// ```
class UpdateService {
  static Future<UpdateInfo> fetch(String url) async {
    final Uri uri = Uri.parse(url.trim());
    if (!uri.hasScheme) {
      throw Exception('更新源地址要以 http:// 或 https:// 开头');
    }
    final http.Response resp = await http.get(
      uri,
      headers: <String, String>{'Cache-Control': 'no-cache'},
    ).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw Exception('更新源返回 ${resp.statusCode}');
    }
    final dynamic decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    if (decoded is! Map) {
      throw Exception('更新源返回的不是一份 JSON 对象');
    }
    return UpdateInfo.fromJson(Map<String, dynamic>.from(decoded));
  }
}
