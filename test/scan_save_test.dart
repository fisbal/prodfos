// Saving a scan like Adobe Scan: the person names the file and sees where it is (Martin, 2026-11-04).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodfos/features/tools/scan_to_pdf_screen.dart';
import 'package:prodfos/core/platform/app_files.dart';
import 'package:prodfos/core/services/pdf_service.dart';

void main() {
  test('the proposed name has the date and time', () {
    expect(PdfService.defaultScanName(DateTime(2026, 11, 4, 17, 38)), 'ProDFOS Scan 2026-11-04 17h38');
  });

  test('a typed name is made safe and ends in .pdf', () {
    expect(PdfService.cleanPdfName('Facture Hydro: nov/2026'), 'Facture Hydro nov 2026.pdf');
    expect(PdfService.cleanPdfName('  Bail.PDF '), 'Bail.pdf');
    expect(PdfService.cleanPdfName('   '), 'Scan.pdf');
    expect(PdfService.cleanPdfName('Reçu d’épicerie'), 'Reçu d’épicerie.pdf');
  });

  test('an existing file is never overwritten', () async {
    final dir = Directory.systemTemp.createTempSync('prodfos_scan').path;
    expect(await PdfService.freeName(dir, 'Bail.pdf'), 'Bail.pdf');
    File(AppFiles.join(dir, 'Bail.pdf')).writeAsStringSync('x');
    expect(await PdfService.freeName(dir, 'Bail.pdf'), 'Bail (2).pdf');
    File(AppFiles.join(dir, 'Bail (2).pdf')).writeAsStringSync('x');
    expect(await PdfService.freeName(dir, 'Bail.pdf'), 'Bail (3).pdf');
  });

  test('the place is said in words', () {
    final sep = Platform.pathSeparator;
    expect(AppFiles.placeOf(['', 'home', 'me', 'Documents', 'ProDFOS', 'a.pdf'].join(sep)), 'Documents › ProDFOS');
  });

  // Like a person: type a name, choose "elsewhere", save. Phones, tablets and PCs, upright and sideways.
  for (final size in const [Size(390, 844), Size(844, 390), Size(820, 1180), Size(1366, 768)]) {
    testWidgets('the save dialog works and fits at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ({String name, bool elsewhere})? got;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
        body: Center(child: ElevatedButton(onPressed: () async { got = await askScanNameAndPlace(context, 'Downloads › ProDFOS'); }, child: const Text('go'))),
      ))));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Downloads › ProDFOS'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('scan-name'))).controller!.text, startsWith('ProDFOS Scan '));
      await tester.enterText(find.byKey(const Key('scan-name')), 'Bail appartement');
      await tester.ensureVisible(find.byKey(const Key('scan-place-other')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scan-place-other')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scan-save')));
      await tester.pumpAndSettle();
      expect(got?.name, 'Bail appartement');
      expect(got?.elsewhere, isTrue);
    });
  }
}
