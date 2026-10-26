import 'package:web/web.dart' as web;

/// Web side of [WindowActions] (see window_actions.dart).
class WindowActions {
  WindowActions._();

  /// Hidden when ProDFOS is already shown inside the hub's web window
  /// (fisbal.github.io/w/prodfos/), which draws the same bar itself.
  static bool get showBar => web.window.frameElement == null;

  /// Browsers do not let a page minimize itself.
  static bool get canMinimize => false;
  static bool get canFullScreen => true;
  static bool get isFullScreen => web.document.fullscreenElement != null;

  static Future<void> minimize() async {}

  static Future<bool> toggleFullScreen() async {
    if (web.document.fullscreenElement != null) {
      web.document.exitFullscreen();
      return false;
    }
    web.document.documentElement?.requestFullscreen();
    return true;
  }

  /// A page cannot close a tab it did not open: go back to the MartinB hub.
  static Future<void> close() async {
    web.window.location.href = '/';
  }
}
