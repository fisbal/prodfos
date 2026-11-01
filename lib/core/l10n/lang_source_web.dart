// On the web, Office In 1 opens ProDFOS with ?lang=xx and sends {type: 'oi1-lang', lang: 'xx'} when it changes.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

String? hostLanguage() => Uri.base.queryParameters['lang'];

void listenHostLanguage(void Function(String code) onChange) {
  web.window.addEventListener('message', ((web.MessageEvent e) {
    final data = e.data;
    if (data == null || !data.isA<JSObject>()) return;
    final obj = data as JSObject;
    final type = obj.getProperty<JSAny?>('type'.toJS);
    final lang = obj.getProperty<JSAny?>('lang'.toJS);
    if (type.isA<JSString>() && (type as JSString).toDart == 'oi1-lang' && lang.isA<JSString>()) onChange((lang as JSString).toDart);
  }).toJS);
}
