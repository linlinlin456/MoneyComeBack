/// 微信读书里的书籍可读类型。
///
/// 判据是网页版回包里的 `payType`，已逐本对照微信读书阅读页的官方标识验证：
///   含 0x100000 位 → 「会员卡可读」（付费会员可读）
///   只有 0x1000 位 → 「体验卡可读」
///   含 0x200000 位 → 「按章购买」（网文 / 连载）
///   payType == 1 → 免费阅读
enum BookAccess {
  /// 付费会员可读（需要付费会员卡）—— 唯一计入「付费书」的类型。
  memberCard,

  /// 体验卡可读（免费领的体验卡就能读）。
  experienceCard,

  /// 按章购买（网文 / 连载，不单独整本售卖）。
  perChapter,

  /// 免费阅读。
  free,
}

extension BookAccessLabel on BookAccess {
  /// 完整名称。
  String get label => switch (this) {
        BookAccess.memberCard => '付费会员可读',
        BookAccess.experienceCard => '体验卡可读',
        BookAccess.perChapter => '按章购买',
        BookAccess.free => '免费阅读',
      };

  /// 卡片右侧的短文字。
  String get shortLabel => switch (this) {
        BookAccess.memberCard => '会员可读',
        BookAccess.experienceCard => '体验卡可读',
        BookAccess.perChapter => '按章购买',
        BookAccess.free => '免费阅读',
      };

  /// 是否计入「付费书」。
  bool get countsAsPaid => this == BookAccess.memberCard;
}

/// 一本书。
///
/// [price] 存的是这本书的定价（封面标价），也是「已读价值」的计算基数。
class Book {
  int? id;
  String title;
  String author;
  String isbn;
  double price;
  double progress; // 0.0 ~ 1.0
  String source; // 价值来源：微信读书 / ISBN 查询 / 手动录入
  String wereadId;
  int readSeconds;
  int finishedAt;
  bool excluded;
  /// 微信读书的 payType 原始值（同步取价时写入，0 表示还没拿到）。
  int payType;
  /// 用户手动改过的字段名（逗号分隔，如 `price,title`）。
  ///
  /// 同步时这些字段不会被微信读书的数据覆盖 —— 这是「增量同步」的核心：
  /// 没动过的字段照常更新，动过的字段保留你自己的值。
  String manualFields;
  int createdAt;
  int updatedAt;

  Book({
    this.id,
    this.title = '',
    this.author = '',
    this.isbn = '',
    this.price = 0,
    this.progress = 0,
    this.source = '手动录入',
    this.wereadId = '',
    this.readSeconds = 0,
    this.finishedAt = 0,
    this.excluded = false,
    this.payType = 0,
    this.manualFields = '',
    int? createdAt,
    int? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  bool get finished => progress >= 1.0;

  /// 书籍可读类型。
  BookAccess get access {
    if (payType != 0) {
      if ((payType & 0x100000) != 0) return BookAccess.memberCard;
      if ((payType & 0x200000) != 0) return BookAccess.perChapter;
      if ((payType & 0x1000) != 0) return BookAccess.experienceCard;
      return BookAccess.free;
    }
    // 还没同步到 payType 的老数据：按定价兜底，有定价的先当付费会员书。
    return price != 0 ? BookAccess.memberCard : BookAccess.free;
  }

  /// 是否计入「付费书」—— 只有付费会员可读的书才算。
  bool get isPaidBook => access.countsAsPaid;

  /// 该字段是否被用户手动改过（同步时应跳过）。
  bool isManual(String field) =>
      manualFields.split(',').contains(field);

  /// 标记若干字段为「手动改过」。
  Book markManual(List<String> fields) {
    final Set<String> set = manualFields
        .split(',')
        .where((String f) => f.isNotEmpty)
        .toSet()
      ..addAll(fields);
    return copyWith(manualFields: set.join(','));
  }

  /// 清除所有手动标记，恢复为完全跟随同步。
  Book clearManual() => copyWith(manualFields: '');

  /// 这本书当前贡献的「已读价值」。
  ///
  /// [byProgress] 为 true 时按阅读进度折算；为 false 时只有读完才计全价。
  double value({required bool byProgress}) {
    if (excluded) return 0;
    // 负价表示「不单独售卖、仅付费会员可读」，没有可折算的定价，按 0 计。
    final double base = price > 0 ? price : 0;
    if (byProgress) {
      final double p = progress.clamp(0.0, 1.0);
      return base * p;
    }
    return finished ? base : 0;
  }

  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? isbn,
    double? price,
    double? progress,
    String? source,
    String? wereadId,
    int? readSeconds,
    int? finishedAt,
    bool? excluded,
    int? payType,
    String? manualFields,
    int? createdAt,
    int? updatedAt,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      isbn: isbn ?? this.isbn,
      price: price ?? this.price,
      progress: progress ?? this.progress,
      source: source ?? this.source,
      wereadId: wereadId ?? this.wereadId,
      readSeconds: readSeconds ?? this.readSeconds,
      finishedAt: finishedAt ?? this.finishedAt,
      excluded: excluded ?? this.excluded,
      payType: payType ?? this.payType,
      manualFields: manualFields ?? this.manualFields,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Book.fromMap(Map<String, Object?> m) {
    return Book(
      id: m['id'] as int?,
      title: (m['title'] as String?) ?? '',
      author: (m['author'] as String?) ?? '',
      isbn: (m['isbn'] as String?) ?? '',
      price: (m['price'] as num?)?.toDouble() ?? 0,
      progress: (m['progress'] as num?)?.toDouble() ?? 0,
      source: (m['source'] as String?) ?? '手动录入',
      wereadId: (m['weread_id'] as String?) ?? '',
      readSeconds: (m['read_seconds'] as int?) ?? 0,
      finishedAt: (m['finished_at'] as int?) ?? 0,
      excluded: ((m['excluded'] as int?) ?? 0) == 1,
      payType: (m['pay_type'] as int?) ?? 0,
      manualFields: (m['manual_fields'] as String?) ?? '',
      createdAt: (m['created_at'] as int?) ?? 0,
      updatedAt: (m['updated_at'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'title': title,
      'author': author,
      'isbn': isbn,
      'price': price,
      'progress': progress,
      'source': source,
      'weread_id': wereadId,
      'read_seconds': readSeconds,
      'finished_at': finishedAt,
      'excluded': excluded ? 1 : 0,
      'pay_type': payType,
      'manual_fields': manualFields,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
