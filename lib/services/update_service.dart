import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
  /// 内置更新源：按顺序尝试，任意一个能拉到就用它。
  ///
  /// 设置页的「更新源地址」留空时就用这几个，所以正常情况下什么都不用填。
  /// 两个仓库（Gitee / GitHub）任意一个放了 version.json 都能生效。
  static const List<String> builtInSources = <String>[
    'https://gitee.com/Linlinlin4567/money-come-back/raw/master/version.json',
    'https://raw.githubusercontent.com/linlinlin456/MoneyComeBack/master/version.json',
  ];

  /// 依次尝试多个更新源，返回第一个成功拉到的版本信息。
  static Future<UpdateInfo> fetchFirst(List<String> urls) async {
    final List<String> tried = <String>[];
    Object? lastError;
    for (final String u in urls) {
      final String one = u.trim();
      if (one.isEmpty) continue;
      tried.add(one);
      try {
        return await fetch(one);
      } catch (e) {
        lastError = e;
      }
    }
    if (tried.isEmpty) {
      throw Exception('没有可用的更新源');
    }
    throw Exception('更新源都拉取失败：${lastError ?? '未知原因'}');
  }

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

  /// 把新版本 APK 下载到本机，返回落地文件路径。
  ///
  /// [onProgress] 回调 (已下载字节, 总字节)；总字节为 -1 表示服务端没给长度。
  static Future<String> downloadApk(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    final Uri uri = Uri.parse(url.trim());
    if (!uri.hasScheme) {
      throw Exception('下载地址要以 http:// 或 https:// 开头');
    }
    final http.Client client = http.Client();
    try {
      final http.StreamedResponse resp = await client
          .send(http.Request('GET', uri))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        throw Exception('下载失败：服务器返回 ${resp.statusCode}');
      }
      final int total = resp.contentLength ?? -1;
      final Directory dir = await getApplicationSupportDirectory();
      final File file = File('${dir.path}/benqian-new.apk');
      if (await file.exists()) {
        await file.delete();
      }
      final IOSink sink = file.openWrite();
      int received = 0;
      await for (final List<int> chunk in resp.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      return file.path;
    } finally {
      client.close();
    }
  }

  /// 调起系统安装器，安装已经下载好的 APK。
  static Future<void> installApk(String path) async {
    const MethodChannel channel = MethodChannel('com.example.book_roi/install');
    await channel.invokeMethod<bool>(
      'installApk',
      <String, dynamic>{'path': path},
    );
  }
}
