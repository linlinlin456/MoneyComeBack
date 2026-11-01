import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/book.dart';
import '../services/isbn_service.dart';

/// 扫描书背条码，用 ISBN 反查书名 / 作者 / 定价。查到后通过 Navigator.pop 返回 Book。
///
/// 提速要点：
///   1. 只解码中间那个框（scanWindow），整幅图不再逐帧全图解码；
///   2. 只认书背的 EAN-13 条码，不试其它格式；
///   3. 识别档用 normal（noDuplicates 要连续多帧确认，明显更慢）；
///   4. 同一个码 8 秒内不重复查网络，避免反复等待。
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.ean13],
    detectionSpeed: DetectionSpeed.normal,
  );

  static const double _boxW = 260;
  static const double _boxH = 150;

  bool _busy = false;
  String _hint = '把书背的条形码对准框内';

  /// 查不到时暂存 ISBN，用来显示「只填 ISBN」按钮。
  String _missed = '';
  /// 上一次查询的码和时间，用于抑制同一本书的重复请求。
  String _lastIsbn = '';
  int _lastAt = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final List<Barcode> codes = capture.barcodes;
    if (codes.isEmpty) return;
    final String raw = codes.first.rawValue ?? '';
    if (raw.isEmpty) return;

    final String isbn = raw.replaceAll(RegExp(r'[^0-9Xx]'), '');
    if (isbn.length < 10) {
      setState(() => _hint = '这个条码不像 ISBN，换个角度再试');
      return;
    }

    // 刚查过又没查到的那本：短时间内别反复打网络。
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (_lastIsbn == isbn && now - _lastAt < 8000) return;
    _lastIsbn = isbn;
    _lastAt = now;

    setState(() {
      _busy = true;
      _missed = '';
      _hint = '正在查询书名和定价…';
    });

    final Book? book = await IsbnService.lookup(raw);
    if (!mounted) return;

    if (book != null && book.title.isNotEmpty) {
      Navigator.of(context).pop(book);
      return;
    }

    setState(() {
      _busy = false;
      _missed = isbn;
      _hint = '没查到这本书的信息，换个角度可以重扫';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('扫描书背条码'),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              // 只在中间这个框里解码，识别更快也更省电。
              final Rect window = Rect.fromCenter(
                center: Offset(c.maxWidth / 2, c.maxHeight / 2),
                width: _boxW,
                height: _boxH,
              );
              return MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                scanWindow: window,
              );
            },
          ),
          IgnorePointer(
            child: Container(
              width: _boxW,
              height: _boxH,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _missed.isEmpty ? Colors.white : Colors.orangeAccent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 44,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _hint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '查到书名和定价后会带回上一页，缺的可以自己补',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (_missed.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context)
                        .pop(Book(isbn: _missed, source: 'ISBN 查询')),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('只填 ISBN，其余手动补'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
