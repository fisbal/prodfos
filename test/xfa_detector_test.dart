import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodfos/core/services/xfa_detector.dart';

/// Government XFA forms (e.g. CF 742) hide /XFA inside compressed object
/// streams; ProDFOS must still open them in the Forms engine.
void main() {
  test('finds /XFA hidden inside a compressed object stream', () {
    final bytes = File('test/fixtures/xfa_in_object_stream.pdf').readAsBytesSync();
    expect(XfaDetector.isXfa(bytes), isTrue);
  });

  test('a plain PDF is not taken for an XFA form', () {
    final bytes = File('test/fixtures/plain.pdf').readAsBytesSync();
    expect(XfaDetector.isXfa(bytes), isFalse);
  });

  test("Adobe's placeholder pages are recognised whatever the app language", () {
    expect(XfaDetector.isPlaceholderText(
        'The document you are trying to load requires Adobe Reader 8 or higher.'), isTrue);
    expect(XfaDetector.isPlaceholderText(
        'Please wait... If this message is not eventually replaced by the proper contents '
        'of the document, your PDF viewer may not be able to display this type of document. '
        'Adobe Reader'), isTrue);
    expect(XfaDetector.isPlaceholderText('Emergency Contact(s) Notification'), isFalse);
  });
}
