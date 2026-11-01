// ProDFOS in 5 languages, like Office In 1 (Martin, 2026-11-01: "permettre d'avoir Office ProDFos en multilangue").
// Every text of the app is written in English in the code and goes through tr(): the English text is the key, its
// French, Spanish, Portuguese and German come from strings.dart. The language is the person's choice in Settings,
// otherwise the device's language. Inside Office In 1 the ProDFOS tab follows Office In 1's language
// (?lang=xx in the address, then a message each time it changes).
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'strings.dart';
import 'lang_source.dart';

const supportedLangs = ['en', 'fr', 'es', 'pt', 'de'];
const langNames = {'en': 'English', 'fr': 'Français', 'es': 'Español', 'pt': 'Português', 'de': 'Deutsch'};

/// The language shown now ('en', 'fr', 'es', 'pt' or 'de').
final ValueNotifier<String> appLang = ValueNotifier<String>('en');

/// The person's own choice, or '' to follow the device (or Office In 1).
String savedLangChoice() {
  try {
    return (Hive.box('settings').get('lang') as String?) ?? '';
  } catch (_) {
    return '';
  }
}

String _pick(String? code) {
  final c = (code ?? '').toLowerCase().split(RegExp('[-_]')).first;
  return supportedLangs.contains(c) ? c : '';
}

/// Picks the language at start: the person's choice, then Office In 1's (address), then the device's.
void initLanguage() {
  final saved = _pick(savedLangChoice());
  final host = _pick(hostLanguage());
  final device = _pick(WidgetsBinding.instance.platformDispatcher.locale.languageCode);
  appLang.value = saved.isNotEmpty ? saved : host.isNotEmpty ? host : device.isNotEmpty ? device : 'en';
  // Office In 1 tells its tab when its language changes; the person's own choice in Settings still wins.
  listenHostLanguage((code) {
    final c = _pick(code);
    if (c.isNotEmpty && _pick(savedLangChoice()).isEmpty) appLang.value = c;
  });
}

/// Saves the person's choice ('' follows the device or Office In 1) and shows it at once.
void setLanguage(String code) {
  try {
    Hive.box('settings').put('lang', code);
  } catch (_) {}
  final c = _pick(code);
  appLang.value = c.isNotEmpty ? c : (_pick(hostLanguage()).isNotEmpty ? _pick(hostLanguage()) : (_pick(WidgetsBinding.instance.platformDispatcher.locale.languageCode).isNotEmpty ? _pick(WidgetsBinding.instance.platformDispatcher.locale.languageCode) : 'en'));
}

/// The text in the language shown. `args` fill {name} places, like tr('Page {n}', {'n': 3}).
String tr(String en, [Map<String, Object?> args = const {}]) {
  // A key can carry a note after '§' when one English text needs two translations (like a headline in two words).
  var s = en.contains('§') ? en.split('§').first : en;
  final i = supportedLangs.indexOf(appLang.value);
  if (i > 0) {
    final row = strings[en];
    if (row != null && row.length >= i && row[i - 1].isNotEmpty) s = row[i - 1];
  }
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// The language's name in English, for the AI ("Answer in French").
String langEnglishName() => const {'en': 'English', 'fr': 'French', 'es': 'Spanish', 'pt': 'Portuguese', 'de': 'German'}[appLang.value] ?? 'English';

/// Redraws every screen after a language change (texts are read when built).
void rebuildAll(BuildContext context) {
  void walk(Element e) {
    e.markNeedsBuild();
    e.visitChildren(walk);
  }
  (context as Element).visitChildren(walk);
}
