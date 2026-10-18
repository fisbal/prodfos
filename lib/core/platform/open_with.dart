import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_files.dart';

/// "Open with ProDFOS" — PDFs double-clicked in Windows Explorer or opened
/// from Android's Files / Gmail / Drive land directly in the viewer.
class OpenWith {
  OpenWith._();

  static const _channel = MethodChannel('prodfos/open_file');

  /// The PDF that launched the app, if any.
  /// Windows: passed as a command-line argument. Android: the VIEW intent.
  static Future<String?> initialFile(List<String> args) async {
    if (kIsWeb) return null;
    for (final a in args) {
      if (a.toLowerCase().endsWith('.pdf')) {
        try {
          if (await AppFiles.exists(a)) return a;
        } catch (_) {}
      }
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        return await _channel.invokeMethod<String>('getInitialFile');
      } catch (_) {}
    }
    return null;
  }

  /// PDFs opened while ProDFOS is already running (second double-click on
  /// Windows, a new "Open with" on Android).
  static void listen(void Function(String path) onOpen) {
    if (kIsWeb) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openFile' && call.arguments is String) {
        onOpen(call.arguments as String);
      }
      return null;
    });
  }
}
