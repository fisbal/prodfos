import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

bool _on = false;

/// The pages that may show ProDFOS inside Office In 1: the website and Microsoft Store app (fisbal.github.io), its
/// Windows, Mac and Android apps (Tauri) and the MartinB hub's Android app (local test pages too).
const _officeIn1Origins = {
  'https://fisbal.github.io',
  'http://tauri.localhost',
  'https://tauri.localhost',
  'tauri://localhost',
  'https://appassets.androidplatform.net',
};
bool _allowed(String origin) =>
    _officeIn1Origins.contains(origin) || RegExp(r'^http://(localhost|127\.0\.0\.1)(:\d+)?$').hasMatch(origin);

/// The origin of the Office In 1 page around ProDFOS, once it said hello; null before, or outside Office In 1.
String? _host;

/// True once Office In 1 said it saves files for ProDFOS (newer Office In 1 builds; Martin, 2026-11-16: the
/// scanner's PDF was lost in the Android app, because a download made inside its frame goes nowhere there).
bool _hostSaves = false;

String? _str(JSObject o, String key) {
  final v = o.getProperty<JSAny?>(key.toJS);
  return v != null && v.isA<JSString>() ? (v as JSString).toDart : null;
}

/// Office In 1 shows ProDFOS in a frame and forwards Ctrl+P as a message {type: 'oi1-print'}.
/// It also answers {type: 'prodfos-hello'} with {type: 'oi1-hello', save: true} (and sends it when the frame loads).
void listen(void Function() onPrint) {
  if (_on) return;
  _on = true;
  web.window.addEventListener('message', ((web.MessageEvent e) {
    final d = e.data;
    if (d == null || !d.isA<JSObject>()) return;
    final type = _str(d as JSObject, 'type');
    if (type == 'oi1-print') onPrint();
    if (type == 'oi1-hello' && web.window.parent != web.window && _allowed(e.origin)) {
      _host = e.origin;
      final save = d.getProperty<JSAny?>('save'.toJS);
      _hostSaves = save != null && save.isA<JSBoolean>() && (save as JSBoolean).toDart;
    }
  }).toJS);
  // Ask the page around for its hello: it may have loaded before this listener started.
  try {
    if (web.window.parent != web.window && insideOfficeIn1) {
      final hello = JSObject()..setProperty('type'.toJS, 'prodfos-hello'.toJS);
      web.window.parent?.postMessage(hello, '*'.toJS);
    }
  } catch (_) {}
}

/// Saves a file through Office In 1, which saves it with its own Save, as for its own files.
/// Returns false when ProDFOS is not inside an Office In 1 that does this: the browser downloads it as usual.
bool sendFileToSave(String name, String mime, Uint8List bytes) {
  final host = _host;
  if (host == null || !_hostSaves) return false;
  final msg = JSObject()
    ..setProperty('type'.toJS, 'prodfos-save'.toJS)
    ..setProperty('name'.toJS, name.toJS)
    ..setProperty('mime'.toJS, mime.toJS)
    ..setProperty('bytes'.toJS, bytes.toJS);
  web.window.parent?.postMessage(msg, host.toJS);
  return true;
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
  web.window.parent?.postMessage(msg, (_host ?? 'https://fisbal.github.io').toJS);
}
