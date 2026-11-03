import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

bool _on = false;

/// Office In 1 shows ProDFOS in a frame and forwards Ctrl+P as a message {type: 'oi1-print'}.
void listen(void Function() onPrint) {
  if (_on) return;
  _on = true;
  web.window.addEventListener('message', ((web.MessageEvent e) {
    final d = e.data;
    if (d == null || !d.isA<JSObject>()) return;
    final type = (d as JSObject).getProperty<JSAny?>('type'.toJS);
    if (type != null && type.isA<JSString>() && (type as JSString).toDart == 'oi1-print') onPrint();
  }).toJS);
}

/// The web build shown in a frame of Office In 1 (fisbal.github.io/oi1, its Microsoft Store app, its PWA).
bool get insideOfficeIn1 {
  try {
    // Office In 1 opens ProDFOS with ?host=oi1; older Office In 1 builds are known by the page that opened the frame.
    return Uri.base.queryParameters['host'] == 'oi1' || (web.window.parent != web.window && web.document.referrer.contains('/oi1'));
  } catch (_) {
    return false;
  }
}

/// A PDF cannot be printed from a hidden frame inside Office In 1's frame (the browser's PDF viewer does not load
/// there, so the Print button did nothing; Martin, 2026-11-03). The pages go to Office In 1 as pictures instead,
/// and Office In 1 prints them from its own window, one page per sheet.
void sendPagesToPrint(String name, List<Uint8List> pngs) {
  final pages = pngs.map((b) => 'data:image/png;base64,${base64Encode(b)}'.toJS).toList().toJS;
  final msg = JSObject()
    ..setProperty('type'.toJS, 'prodfos-print-pages'.toJS)
    ..setProperty('name'.toJS, name.toJS)
    ..setProperty('pages'.toJS, pages);
  web.window.parent?.postMessage(msg, 'https://fisbal.github.io'.toJS);
}
