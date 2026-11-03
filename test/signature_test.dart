// Signatures (Martin, 2026-11-03): draw, type in 21 styles or import; several kept on the device; the signature,
// a signature line (name, title, date) or the initials.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:prodfos/features/editor/signature_pad_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('prodfos_sig').path);
    await Hive.openBox('settings');
  });

  test('initials and the 21 styles', () {
    expect(initialsOf('Martin Ballas'), 'MB');
    expect(initialsOf('jean-paul de la tour'), 'JPT');
    expect(initialsOf(''), '');
    expect(signatureFonts.length, greaterThanOrEqualTo(20));
    expect(signatureFonts.toSet().length, signatureFonts.length);
  });

  for (final size in const [Size(390, 844), Size(844, 390), Size(1366, 900)]) {
    testWidgets('the signature window fits a ${size.width.toInt()}×${size.height.toInt()} screen and asks to sign first', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
      await tester.runAsync(() => Hive.box('settings').put('saved_signatures', <dynamic>[]));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (c) => Center(
        child: TextButton(onPressed: () => SignaturePadSheet.show(c), child: const Text('open')))))));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // The whole window is on the screen.
      final sheet = tester.getRect(find.byType(SignaturePadSheet));
      expect(sheet.top, greaterThanOrEqualTo(0));
      expect(sheet.bottom, lessThanOrEqualTo(size.height + 0.5));
      expect(find.text('Draw'), findsOneWidget);
      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
      expect(find.text('Place my initials'), findsOneWidget);
      await tester.ensureVisible(find.text('Use this signature'));
      await tester.pump();
      await tester.tap(find.text('Use this signature'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Sign inside the box with your finger'), findsWidgets);
      // Initials with no name: a clear message.
      await tester.ensureVisible(find.text('Place my initials'));
      await tester.pump();
      await tester.tap(find.text('Place my initials'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Type your name first.'), findsOneWidget);
      // The photo mode shows its tip.
      await tester.ensureVisible(find.text('Import'));
      await tester.pump();
      await tester.tap(find.text('Import'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Choose a photo of my signature…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
