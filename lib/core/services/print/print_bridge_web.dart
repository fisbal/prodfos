import 'dart:js_interop';
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
