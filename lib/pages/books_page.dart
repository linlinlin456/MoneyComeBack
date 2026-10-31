import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'book_edit_page.dart';
import 'scan_page.dart';

/// 书值页：所有书按价值 / 进度 / 定价排序展示。
class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  int _sortIndex = 0;
  bool _ascending = false; // false = 降序（默认从大到小）

  /// 多选模式下已选中的书籍 id。非空即表示处于多选模式。
  final Set<int> _selected = <int>{};
  bool get _selecting => _selected.isNotEmpty;

  static const List<String> _sortNames = <String>['价值', '进度', '定价'];

  /// 标签带方向箭头：只有当前生效的那一项才反映真实方向。
  List<String> get _sortLabels => List<String>.generate(
        _sortNames.length,
        (int i) =>
            '${_sortNames[i]} ${(_sortIndex == i && _ascending) ? '↑' : '↓'}',
      );

  /// 点同一项 → 切换升降序；点另一项 → 切过去并重置为降序。
  void _onSortChanged(int i) {
    setState(() {
      if (i == _sortIndex) {
        _ascending = !_ascending;
      } else {
        _sortIndex = i;
        _ascending = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final bool byProgress = state.settings.valueByProgress;
    final bool onlyPaidPricing = state.settings.onlyPaidPricing;

    // 两个模式都展示全部书，区别只在价格怎么显示：
    //   只记付费书 → 只有「付费会员可读」的书显示定价，其余显示可读类型；
    //   全部记录   → 所有书都按定价显示。
    final List<Book> list = List<Book>.from(state.books);
    list.sort((Book a, Book b) {
      int r;
      if (_sortIndex == 0) {
        r = b
            .value(byProgress: byProgress)
            .compareTo(a.value(byProgress: byProgress));
      } else if (_sortIndex == 1) {
        r = b.progress.compareTo(a.progress);
      } else {
        r = b.price.compareTo(a.price);
      }
      return _ascending ? -r : r;
    });

    final double totalValue = state.books.fold(
      0.0,
      (double sum, Book b) => sum + b.value(byProgress: byProgress),
    );

    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            if (_selecting)
              _selectionBar(state, list)
            else
              PageTitle(
                '书值',
                trailing: Text(
                  '总价值 ${money(totalValue)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
              ),
            if (!_selecting)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PillTabs(
                    labels: _sortLabels,
                    activeIndex: _sortIndex,
                    onChanged: _onSortChanged,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Expanded(
              child: list.isEmpty
                  ? EmptyHint(
                      text: '还没有书籍\n点右下角 + 手动添加，或扫码录入',
                      actionText: '扫码添加',
                      onAction: _openScan,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                      itemCount: list.length,
                      itemBuilder: (BuildContext ctx, int i) => KeyedSubtree(
                        key: ValueKey<String>(
                          '${list[i].id}-${list[i].title}',
                        ),
                        child: _bookCard(list[i], byProgress, onlyPaidPricing),
                      ),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            backgroundColor: AppTheme.ink,
            foregroundColor: Colors.white,
            onPressed: _showAddSheet,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  /// 书籍类型标签：付费会员可读 / 体验卡可读 / 按章购买 / 免费阅读。
  Widget _typeChip(Book book) {
    final String label = book.access.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.inkFaint.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppTheme.inkSoft),
      ),
    );
  }

  Widget _bookCard(Book book, bool byProgress, bool onlyPaidPricing) {
    final double pct = (book.progress * 100).clamp(0, 100);
    // 「只记付费书」时只有付费会员可读的书显示定价，
    // 体验卡可读 / 按章购买 / 免费阅读显示各自的类型文字；
    // 「全部记录」时所有书都显示定价。
    final BookAccess access = book.access;
    final bool showPrice = !onlyPaidPricing || access == BookAccess.memberCard;
    final bool checked = book.id != null && _selected.contains(book.id);
    return GestureDetector(
      onTap: () {
        if (_selecting) {
          _toggleSelect(book);
        } else {
          _openEdit(book);
        }
      },
      onLongPress: () => _toggleSelect(book),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardBox(
          border: checked ? AppTheme.ink : null,
          borderWidth: checked ? 2.0 : 1.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_selecting) ...<Widget>[
                  Icon(
                    checked
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: checked ? AppTheme.ink : AppTheme.inkFaint,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    book.title.isEmpty ? '（未命名）' : book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: book.excluded ? AppTheme.inkFaint : AppTheme.ink,
                      decoration: book.excluded ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  showPrice ? money(book.price) : access.shortLabel,
                  style: TextStyle(
                    fontSize: showPrice ? 15 : 13,
                    fontWeight: FontWeight.w700,
                    color: showPrice ? AppTheme.ink : AppTheme.inkSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    book.author.isEmpty ? '未知作者' : book.author,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft),
                  ),
                ),
                const SizedBox(width: 8),
                _typeChip(book),
              ],
            ),
            const SizedBox(height: 12),
            InkProgressBar(value: book.progress, height: 8),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    showPrice
                        ? '定价 ${money(book.price)} · 价值来源：${book.source}'
                        : '${access.label} · 价值来源：${book.source}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppTheme.inkFaint),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 多选与批量删除 ----------------

  void _toggleSelect(Book book) {
    final int? id = book.id;
    if (id == null) return;
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _selectAll(List<Book> list) {
    setState(() {
      if (_selected.length == list.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(list.map((Book b) => b.id).whereType<int>());
      }
    });
  }

  void _exitSelect() => setState(_selected.clear);

  Widget _selectionBar(AppState state, List<Book> list) {
    final bool allSelected =
        list.isNotEmpty && _selected.length == list.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: <Widget>[
          TextButton(
            onPressed: _exitSelect,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text('取消', style: TextStyle(color: AppTheme.inkSoft)),
          ),
          const SizedBox(width: 4),
          Text(
            '已选 ${_selected.length} 本',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _selectAll(list),
            child: Text(
              allSelected ? '取消全选' : '全选',
              style: const TextStyle(color: AppTheme.ink),
            ),
          ),
          TextButton(
            onPressed: () => _confirmBatchDelete(state),
            child: const Text(
              '删除',
              style: TextStyle(color: Color(0xFFC0392B), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBatchDelete(AppState state) async {
    final int n = _selected.length;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('删除选中的 $n 本书？'),
        content: const Text('删除后无法恢复。如果开着自动备份，备份文件里仍保留历史记录。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: AppTheme.inkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFC0392B))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final List<int> ids = _selected.toList();
    final int deleted = await state.deleteBooks(ids);
    if (!mounted) return;
    setState(_selected.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除 $deleted 本')),
    );
  }

  void _showAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppTheme.ink),
                title: const Text('手动添加'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openEdit(null);
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner, color: AppTheme.ink),
                title: const Text('扫码添加（ISBN）'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openScan();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEdit(Book? book) async {
    final AppState state = context.read<AppState>();
    final Book? result = await Navigator.of(context).push<Book>(
      MaterialPageRoute<Book>(builder: (_) => BookEditPage(book: book)),
    );
    if (result == null) return;
    if (result.price < 0 && book != null && book.id != null) {
      await state.deleteBook(book.id!);
      return;
    }
    if (book == null) {
      await state.addBook(result);
    } else {
      await state.updateBook(result);
    }
  }

  Future<void> _openScan() async {
    final AppState state = context.read<AppState>();
    final Book? scanned = await Navigator.of(context).push<Book>(
      MaterialPageRoute<Book>(builder: (_) => const ScanPage()),
    );
    if (scanned == null) return;
    await state.addBook(scanned);
  }
}
