import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 新增 / 编辑一本书。保存时通过 Navigator.pop 把 Book 返回给上一页。
class BookEditPage extends StatefulWidget {
  final Book? book;

  const BookEditPage({super.key, this.book});

  @override
  State<BookEditPage> createState() => _BookEditPageState();
}

class _BookEditPageState extends State<BookEditPage> {
  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _isbn;
  late final TextEditingController _price;
  late double _progress;
  late bool _excluded;
  bool _manualCleared = false;

  bool get _isNew => widget.book == null;

  @override
  void initState() {
    super.initState();
    final Book b = widget.book ?? Book();
    _title = TextEditingController(text: b.title);
    _author = TextEditingController(text: b.author);
    _isbn = TextEditingController(text: b.isbn);
    _price = TextEditingController(text: b.price > 0 ? b.price.toStringAsFixed(2) : '');
    _progress = b.progress;
    _excluded = b.excluded;
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _isbn.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Book base = widget.book ?? Book();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(_isNew ? '添加书籍' : '编辑书籍'),
        actions: <Widget>[
          if (!_isNew)
            IconButton(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          SectionCard(
            child: Column(
              children: <Widget>[
                _field('书名', _title, hint: '必填'),
                _field('作者', _author),
                _field('ISBN', _isbn, keyboard: TextInputType.number),
                _field('定价（元）', _price, keyboard: const TextInputType.numberWithOptions(decimal: true)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text('阅读进度',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(
                      '${(_progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Slider(
                  value: _progress,
                  activeColor: AppTheme.ink,
                  inactiveColor: AppTheme.track,
                  onChanged: (double v) => setState(() => _progress = v),
                ),
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: () => setState(() => _progress = 0),
                      child: const Text('未读', style: TextStyle(color: AppTheme.inkSoft)),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _progress = 1),
                      child: const Text('已读完', style: TextStyle(color: AppTheme.ink)),
                    ),
                  ],
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _excluded,
                  onChanged: (bool v) => setState(() => _excluded = v),
                  title: const Text('不计入统计', style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    '比如借来的书、免费书，勾选后不影响回本计算',
                    style: TextStyle(fontSize: 11, color: AppTheme.inkSoft),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                KVRow(label: '价值来源', value: base.source, emphasize: false),
                if (base.manualFields.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  const Text(
                    '这本书的部分内容是你手动改过的，同步时会保留你的值，不被微信读书覆盖。',
                    style: TextStyle(fontSize: 11, color: AppTheme.inkSoft),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => setState(() {
                      // 清掉手动标记，之后完全跟随同步。
                      _manualCleared = true;
                    }),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: Text(
                      _manualCleared ? '已恢复自动同步' : '恢复自动同步',
                      style: const TextStyle(fontSize: 12, color: AppTheme.ink),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('保存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.inkSoft)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(color: AppTheme.inkFaint, fontSize: 14),
              ),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('书名不能为空')),
      );
      return;
    }
    final double price = double.tryParse(_price.text.trim()) ?? 0;
    final double safePrice = price < 0 ? 0 : price;
    final String author = _author.text.trim();
    final String isbn = _isbn.text.trim();
    final Book base = widget.book ?? Book();

    // 找出这次真正被你改动的字段，标记为「手动」，同步时就不会被覆盖。
    final List<String> changed = <String>[];
    if (!_isNew) {
      if (title != base.title) changed.add('title');
      if (author != base.author) changed.add('author');
      if (isbn != base.isbn) changed.add('isbn');
      if (safePrice != base.price) changed.add('price');
      if (_progress != base.progress) changed.add('progress');
    }

    Book result = base.copyWith(
      title: title,
      author: author,
      isbn: isbn,
      price: safePrice,
      progress: _progress,
      excluded: _excluded,
      source: base.source.isEmpty ? '手动录入' : base.source,
      finishedAt: _progress >= 1.0 ? DateTime.now().millisecondsSinceEpoch : 0,
    );
    if (_manualCleared) {
      result = result.clearManual();
    } else if (changed.isNotEmpty) {
      result = result.markManual(changed);
    }
    Navigator.of(context).pop(result);
  }

  Future<void> _confirmDelete() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('删除这本书？'),
        content: const Text('删除后无法恢复，但备份文件里仍保留着历史记录。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: AppTheme.inkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: AppTheme.ink)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    Navigator.of(context).pop(widget.book?.copyWith(price: -1));
  }
}
