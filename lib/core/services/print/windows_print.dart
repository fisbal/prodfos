import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:printing/printing.dart';

/// ProDFOS prints by itself on Windows (windows/runner/print_channel.cpp), with
/// the printer's own settings — paper, quality, two-sided — chosen once in the
/// printer's preferences and kept for each printer.
class WindowsPrint {
  WindowsPrint._();

  static const _channel = MethodChannel('prodfos/print');
  static const _dpi = 300.0;

  static Box get _box => Hive.box('settings');

  /// The printer settings kept for [printer], or null (the printer's defaults).
  static Uint8List? savedSettings(String printer) {
    final v = _box.get('print.devmode.$printer');
    return v is Uint8List ? v : (v is List ? Uint8List.fromList(v.cast<int>()) : null);
  }

  static Future<void> forgetSettings(String printer) => _box.delete('print.devmode.$printer');

  /// Opens the printer's own preferences window (paper, quality, two-sided…).
  /// Returns true when the person confirmed; the settings are then kept.
  static Future<bool> editSettings(String printer) async {
    final result = await _channel.invokeMethod<Uint8List>(
        'preferences', {'printer': printer, 'devmode': savedSettings(printer)});
    if (result == null) return false;
    await _box.put('print.devmode.$printer', result);
    return true;
  }

  /// Prints [pdf] on [printer] at actual size, with the kept settings.
  static Future<void> printPdf({
    required String printer,
    required String name,
    required Uint8List pdf,
    void Function(int pagesDone)? onPage,
  }) async {
    var started = false;
    var done = 0;
    try {
      await for (final page in Printing.raster(pdf, dpi: _dpi)) {
        final w = page.width / _dpi * 72, h = page.height / _dpi * 72;
        if (!started) {
          await _channel.invokeMethod('begin', {
            'printer': printer,
            'devmode': savedSettings(printer),
            'name': name,
            'pageWidth': w,
            'pageHeight': h,
          });
          started = true;
        }
        await _channel.invokeMethod('page', {
          'pixels': page.pixels,
          'width': page.width,
          'height': page.height,
          'pageWidth': w,
          'pageHeight': h,
        });
        onPage?.call(++done);
      }
      if (started) await _channel.invokeMethod('end');
    } catch (_) {
      if (started) {
        try {
          await _channel.invokeMethod('abort');
        } catch (_) {}
      }
      rethrow;
    }
  }
}
