import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cost_item.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 成本一览：阅读器、会员费、配件等。
class CostPage extends StatefulWidget {
  const CostPage({super.key});

  @override
  State<CostPage> createState() => _CostPageState();
}

class _CostPageState extends State<CostPage> {
  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final List<CostItem> items = state.costs;
    final double total =
        items.fold(0.0, (double sum, CostItem c) => sum + c.amount);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('成本一览')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: <Widget>[
          SectionCard(
            child: Column(
              children: <Widget>[
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '还没有成本条目\n把阅读器、会员费、保护壳都记进来',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.inkSoft),
                    ),
                  )
                else
                  ...items.map((CostItem c) => _row(c)),
                const Divider(height: 24),
                Row(
                  children: <Widget>[
                    const Text('合计',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(
                      money(total),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => _openEditor(null),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.ink,
                side: const BorderSide(color: AppTheme.ink),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('+ 添加条目'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(CostItem c) {
    return InkWell(
      onTap: () => _openEditor(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    c.name.isEmpty ? '未命名' : c.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    c.category,
                    style: const TextStyle(fontSize: 11, color: AppTheme.inkFaint),
                  ),
                ],
              ),
            ),
            Text(
              money(c.amount),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(CostItem? item) async {
    final AppState state = context.read<AppState>();
    final CostItem? result = await showModalBottomSheet<CostItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => _CostEditor(item: item),
    );
    if (result == null) return;
    if (item == null) {
      await state.addCost(result);
    } else if (result.amount < 0) {
      await state.deleteCost(item.id!);
    } else {
      await state.updateCost(result);
    }
  }
}

/// 底部弹出的成本编辑表单。删除时返回 amount = -1 作为标记。
class _CostEditor extends StatefulWidget {
  final CostItem? item;

  const _CostEditor({this.item});

  @override
  State<_CostEditor> createState() => _CostEditorState();
}

class _CostEditorState extends State<_CostEditor> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late String _category;

  @override
  void initState() {
    super.initState();
    final CostItem c = widget.item ?? CostItem();
    _name = TextEditingController(text: c.name);
    _amount = TextEditingController(
      text: c.amount > 0 ? c.amount.toStringAsFixed(2) : '',
    );
    _category = c.category;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.item == null ? '添加成本' : '编辑成本',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '名称',
              hintText: '例如 掌阅 Neo3 Ultra',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '金额（元）'),
          ),
          const SizedBox(height: 16),
          const Text('分类', style: TextStyle(fontSize: 13, color: AppTheme.inkSoft)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: CostItem.categories.map((String c) {
              final bool active = c == _category;
              return GestureDetector(
                onTap: () => setState(() => _category = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: AppTheme.pill(active: active),
                  child: Text(
                    c,
                    style: TextStyle(
                      fontSize: 13,
                      color: active ? Colors.white : AppTheme.inkSoft,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              if (widget.item != null)
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    widget.item!.copyWith(amount: -1),
                  ),
                  child: const Text('删除', style: TextStyle(color: AppTheme.inkSoft)),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit() {
    final String name = _name.text.trim();
    final double amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名称不能为空')),
      );
      return;
    }
    final CostItem base = widget.item ?? CostItem();
    Navigator.pop(
      context,
      base.copyWith(
        name: name,
        amount: amount < 0 ? 0 : amount,
        category: _category,
        date: base.date == 0
            ? DateTime.now().millisecondsSinceEpoch
            : base.date,
      ),
    );
  }
}
