import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/book.dart';
import '../services/isbn_service.dart';

/// 扫描书背条码，用 ISBN 反查书名和作者。查到后通过 Navigator.pop 返回 Book。
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _busy = false;

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

    setState(() => _busy = true);
    final Book? book = await IsbnService.lookup(raw);
    if (!mounted) return;

    if (book == null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这个条码不像 ISBN，换个角度再试')),
      );
      return;
    }
    Navigator.of(context).pop(book);
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
          MobileScanner(controller: _controller, onDetect: _onDetect),
          IgnorePointer(
            child: Container(
              width: 250,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: Column(
              children: <Widget>[
                Text(
                  _busy ? '正在查询书价…' : '把书背的条形码对准框内',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  '查到书名后会带回上一页，价格可以自己补',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
