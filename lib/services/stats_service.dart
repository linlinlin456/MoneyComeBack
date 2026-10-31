import '../models/book.dart';
import '../models/cost_item.dart';

/// 回本统计结果。
class RoiStats {
  final double totalCost;
  final double readValue;
  final double avgBookPrice;
  final int bookCount;
  final int finishedCount;
  final Map<String, double> costByCategory;

  RoiStats({
    required this.totalCost,
    required this.readValue,
    required this.avgBookPrice,
    required this.bookCount,
    required this.finishedCount,
    required this.costByCategory,
  });

  /// 回本进度 0.0 ~ 1.0。
  double get progress {
    if (totalCost <= 0) return 0;
    return (readValue / totalCost).clamp(0.0, 1.0);
  }

  bool get isPaidBack => totalCost > 0 && readValue >= totalCost;

  /// 距离回本还差多少钱。
  double get gap {
    final double g = totalCost - readValue;
    return g > 0 ? g : 0;
  }

  /// 按平均书价估算，还需读多少本。
  int get booksToGo {
    if (avgBookPrice <= 0 || gap <= 0) return 0;
    return (gap / avgBookPrice).ceil();
  }

  static RoiStats compute({
    required List<Book> books,
    required List<CostItem> costs,
    required bool byProgress,
    bool onlyPaidPricing = true,
  }) {
    double totalCost = 0;
    final Map<String, double> byCategory = <String, double>{};
    for (final CostItem c in costs) {
      totalCost += c.amount;
      byCategory[c.category] = (byCategory[c.category] ?? 0) + c.amount;
    }

    double readValue = 0;
    double priceSum = 0;
    int counted = 0;      // 计入统计的书（不含已排除的）
    int pricedCount = 0;  // 其中属于「付费会员书」的书
    int finished = 0;
    for (final Book b in books) {
      if (b.excluded) continue;
      counted++;
      // 「付费书」只认微信读书里「付费会员可读」的书；
      // 体验卡可读、按章购买、免费阅读的一律不计入。
      if (b.isPaidBook) {
        pricedCount++;
        if (b.price > 0) priceSum += b.price;
      }
      if (b.finished) finished++;
      readValue += b.value(byProgress: byProgress);
    }
    // 平均书价的分母：只记付费书时用「付费会员书的本数」，否则用全部书数。
    final int avgBase = onlyPaidPricing ? pricedCount : counted;

    return RoiStats(
      totalCost: totalCost,
      readValue: readValue,
      avgBookPrice: avgBase > 0 ? priceSum / avgBase : 0,
      bookCount: counted,
      finishedCount: finished,
      costByCategory: byCategory,
    );
  }
}
