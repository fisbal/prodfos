/// Window controls for the gold MartinB bar (minimize, full screen, close).
///
/// Android → real actions through the "prodfos/window" channel + immersive mode.
/// Windows → the native title bar keeps its own buttons (dark, gold title).
/// Web     → full screen and "back to the hub"; browsers cannot minimize a page.
library;

export 'window_actions_io.dart' if (dart.library.js_interop) 'window_actions_web.dart';
