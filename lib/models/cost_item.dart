/// 一条阅读成本，例如阅读器、会员费、保护壳。
class CostItem {
  int? id;
  String name;
  String category; // 设备 / 会员费 / 电子书配件 / 其他
  double amount;
  int date;
  String note;
  int createdAt;

  CostItem({
    this.id,
    this.name = '',
    this.category = '设备',
    this.amount = 0,
    this.date = 0,
    this.note = '',
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  static const List<String> categories = <String>['设备', '会员费', '电子书配件', '其他'];

  CostItem copyWith({
    int? id,
    String? name,
    String? category,
    double? amount,
    int? date,
    String? note,
    int? createdAt,
  }) {
    return CostItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory CostItem.fromMap(Map<String, Object?> m) {
    return CostItem(
      id: m['id'] as int?,
      name: (m['name'] as String?) ?? '',
      category: (m['category'] as String?) ?? '设备',
      amount: (m['amount'] as num?)?.toDouble() ?? 0,
      date: (m['date'] as int?) ?? 0,
      note: (m['note'] as String?) ?? '',
      createdAt: (m['created_at'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'amount': amount,
      'date': date,
      'note': note,
      'created_at': createdAt,
    };
  }
}
