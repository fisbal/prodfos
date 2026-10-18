/// ProDFOS Forms Engine view — renders XFA / scripted forms with pdf.js
/// (Mozilla's engine, the one Firefox uses).
///
/// Android → in-app WebView, Windows → in-app WebView2,
/// Web → an <iframe> inside the page.
library;

export 'xfa_view_io.dart' if (dart.library.js_interop) 'xfa_view_web.dart';
