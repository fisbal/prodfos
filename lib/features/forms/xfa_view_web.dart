import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../core/platform/app_files.dart';

/// Web Forms engine view — pdf.js runs in an <iframe> on the same site.
class XfaView extends StatefulWidget {
  final Uint8List bytes;
  final String name;

  /// Called with the saved file path after the user taps Save.
  final ValueChanged<String>? onSaved;

  const XfaView({super.key, required this.bytes, required this.name, this.onSaved});

  @override
  State<XfaView> createState() => _XfaViewState();
}

class _XfaViewState extends State<XfaView> {
  static int _seq = 0;
  late final String _viewType = 'prodfos-forms-${_seq++}';
  web.HTMLIFrameElement? _frame;
  JSFunction? _listener;

  @override
  void initState() {
    super.initState();
    final name = Uri.encodeQueryComponent(widget.name);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final f = web.document.createElement('iframe') as web.HTMLIFrameElement;
      f.src = 'assets/assets/pdfjs/xfa_viewer.html?mode=embed&name=$name';
      f.style
        ..border = 'none'
        ..width = '100%'
        ..height = '100%';
      _frame = f;
      return f;
    });
    _listener = ((web.MessageEvent e) => _onMessage(e)).toJS;
    web.window.addEventListener('message', _listener);
  }

  void _onMessage(web.MessageEvent e) {
    final d = e.data;
    if (d == null || !d.isA<JSObject>()) return;
    final o = d as JSObject;
    if ((o['source'] as JSString?)?.toDart != 'prodfos-forms') return;
    final type = (o['type'] as JSString?)?.toDart;

    if (type == 'ready') {
      final msg = JSObject();
      msg['type'] = 'open'.toJS;
      msg['name'] = widget.name.toJS;
      msg['data'] = widget.bytes.toJS;
      _frame?.contentWindow?.postMessage(msg, '*'.toJS);
    } else if (type == 'saved') {
      final data = o['data'];
      if (data == null) return;
      _save((data as JSUint8Array).toDart);
    }
  }

  Future<void> _save(Uint8List data) async {
    final base = widget.name
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^\w\-]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final name = '${base}_filled_$stamp.pdf';
    final path = AppFiles.join(await AppFiles.outputDir(), name);
    await AppFiles.writeBytes(path, data);
    AppFiles.downloadBytes(data, name);
    if (mounted) widget.onSaved?.call(path);
  }

  @override
  void dispose() {
    if (_listener != null) web.window.removeEventListener('message', _listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
