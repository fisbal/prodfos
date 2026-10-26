import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android and Windows side of [WindowActions] (see window_actions.dart).
class WindowActions {
  WindowActions._();

  static const _channel = MethodChannel('prodfos/window');
  static bool _fullScreen = false;

  /// The gold bar is drawn on Android only: Windows already has its native
  /// title bar with minimize / maximize / close (coloured dark + gold).
  static bool get showBar => defaultTargetPlatform == TargetPlatform.android;

  static bool get canMinimize => true;
  static bool get canFullScreen => true;
  static bool get isFullScreen => _fullScreen;

  /// Sends the app to the background (like the Home button), keeping its state.
  static Future<void> minimize() async {
    try {
      await _channel.invokeMethod<void>('minimize');
    } catch (_) {}
  }

  /// Hides or shows Android's status and navigation bars. Returns the new state.
  static Future<bool> toggleFullScreen() async {
    _fullScreen = !_fullScreen;
    await SystemChrome.setEnabledSystemUIMode(
        _fullScreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    return _fullScreen;
  }

  /// Closes the app and removes it from the recent apps list.
  static Future<void> close() async {
    try {
      await _channel.invokeMethod<void>('close');
    } catch (_) {
      await SystemNavigator.pop();
    }
  }
}
