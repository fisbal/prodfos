import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Detects Adobe XFA forms (government forms that other readers show as
/// "Please wait…" or "requires Adobe Reader 8 or higher").
///
/// Three layers, cheapest first:
///  1. Plain markers in the file: /XFA or /NeedsRendering (dynamic XFA).
///  2. The same markers hidden inside compressed object streams (/ObjStm) —
///     common in recent government PDFs (e.g. CF 742, IMM forms).
///  3. (in the viewer) the English placeholder text on page 1.
class XfaDetector {
  XfaDetector._();

  static bool isXfa(Uint8List bytes) {
    if (_has(bytes, '/XFA') || _has(bytes, '/NeedsRendering')) return true;
    return _inObjectStreams(bytes);
  }

  /// Placeholder text Adobe puts on page 1 of dynamic XFA forms. Always
  /// English inside the PDF, whatever language ProDFOS is shown in.
  static bool isPlaceholderText(String text) {
    final t = text.toLowerCase();
    return (t.contains('please wait') && t.contains('adobe')) ||
        t.contains('requires adobe reader') ||
        t.contains('adobe reader 8') ||
        t.contains('pdf_forms_configure');
  }

  static bool _inObjectStreams(Uint8List bytes) {
    final s = latin1.decode(bytes, allowInvalid: true);
    final objStm = RegExp(r'/Type\s*/ObjStm');
    var checked = 0;
    for (final m in objStm.allMatches(s)) {
      if (++checked > 400) break;
      final kw = s.indexOf('stream', m.end);
      if (kw < 0) continue;
      var start = kw + 6;
      if (start < s.length && s.codeUnitAt(start) == 13) start++;
      if (start < s.length && s.codeUnitAt(start) == 10) start++;
      var end = s.indexOf('endstream', start);
      if (end <= start) continue;
      while (end > start && (s.codeUnitAt(end - 1) == 10 || s.codeUnitAt(end - 1) == 13)) {
        end--;
      }
      try {
        final data = ZLibDecoder().decodeBytes(bytes.sublist(start, end));
        final u = data is Uint8List ? data : Uint8List.fromList(data);
        if (_has(u, '/XFA') || _has(u, '/NeedsRendering')) return true;
      } catch (_) {
        // Not Flate-compressed or damaged — skip this stream.
      }
    }
    return false;
  }

  /// Fast byte search — no string conversion.
  static bool _has(Uint8List bytes, String needle) {
    final n = needle.codeUnits;
    final last = bytes.length - n.length;
    outer:
    for (int i = 0; i <= last; i++) {
      if (bytes[i] != n[0]) continue;
      for (int j = 1; j < n.length; j++) {
        if (bytes[i + j] != n[j]) continue outer;
      }
      return true;
    }
    return false;
  }
}
