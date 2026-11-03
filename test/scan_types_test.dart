// The scanner's kinds of document, used like a person would: pick Book, see its settings; pick
// ID card, see the watermark box; pick Whiteboard. Nothing may overflow on a phone, upright or sideways,
// or on a PC (an overflow is a Flutter error, which fails the test by itself).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:prodfos/core/services/pdf_service.dart';
import 'package:prodfos/features/tools/scan_to_pdf_screen.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final size in const [Size(390, 844), Size(844, 390), Size(1366, 768)]) {
    testWidgets('scan types work on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => PdfService(),
        child: MaterialApp(theme: ThemeData.dark(), home: const ScanToPdfScreen()),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('scan-types')), findsOneWidget);

      Future<void> pick(String id) async {
        final chip = find.byKey(ValueKey('scan-type-$id'));
        final list = find.descendant(of: find.byKey(const ValueKey('scan-types')), matching: find.byType(Scrollable)).first;
        final pos = tester.state<ScrollableState>(list).position;
        pos.jumpTo(0);
        await tester.pump();
        for (var i = 0; i < 60 && (chip.evaluate().isEmpty || tester.getRect(chip).right > size.width - 8); i++) {
          pos.jumpTo((pos.pixels + 120).clamp(0, pos.maxScrollExtent));
          await tester.pump();
        }
        await tester.tap(chip);
        await tester.pump(const Duration(milliseconds: 400));
      }

      await pick('book');
      expect(find.text('Split double pages'), findsOneWidget);
      expect(find.text('Right to left (Arabic, manga)'), findsOneWidget);
      expect(find.textContaining('Open the book flat'), findsOneWidget);

      await pick('idcard');
      expect(find.byKey(const ValueKey('scan-mark')), findsOneWidget);
      expect(find.textContaining('Scan the front, then the back'), findsOneWidget);

      await pick('whiteboard');
      expect(find.textContaining('Stand in front of the board'), findsOneWidget);
      expect(find.byKey(const ValueKey('scan-mark')), findsNothing);

      await pick('drawing');
      expect(find.textContaining('kept as it is'), findsOneWidget);
    });
  }
}
