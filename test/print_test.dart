// Ctrl+P (Martin, 2026-11-03: "Ctrl+P ne fonctionne pas sur ProDFos pour imprimer"): in the PDF viewer, Ctrl+P,
// ⌘P, and a request from Office In 1 all open the system print dialog with the PDF itself.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:prodfos/core/services/document_manager.dart';
import 'package:prodfos/core/services/preferences_service.dart';
import 'package:prodfos/core/services/print/print_requests.dart';
import 'package:prodfos/features/viewer/viewer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync_pdf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late PreferencesService prefs;
  late String pdfPath;
  late Uint8List pdfBytes;
  final printed = <String>[];

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('prodfos_print');
    Hive.init(dir.path);
    await Hive.openBox('documents');
    await Hive.openBox('settings');
    SharedPreferences.setMockInitialValues({});
    prefs = PreferencesService();
    await prefs.init();
    final doc = sync_pdf.PdfDocument()..pages.add();
    pdfPath = '${dir.path}/facture.pdf';
    pdfBytes = Uint8List.fromList(await doc.save());
    File(pdfPath).writeAsBytesSync(pdfBytes);
    doc.dispose();
    // The printing plugin: record each print job instead of opening a dialog.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('net.nfet.printing'), (call) async {
        if (call.method == 'printPdf') { printed.add('${call.arguments['name']}'); return true; }
        if (call.method == 'printingInfo') return {'canPrint': true, 'directPrint': false, 'dynamicLayout': true, 'canShare': true, 'canRaster': true, 'canListPrinters': false};
        return null;
      });
    // The PDF viewer's own plugin: not needed to print.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('syncfusion_flutter_pdfviewer'), (call) async => null);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) { await tester.pump(const Duration(milliseconds: 50)); }
  }
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: prefs),
      ChangeNotifierProvider(create: (_) => DocumentManager()),
    ], child: MaterialApp(home: ViewerScreen(filePath: pdfPath, bytes: pdfBytes))));
    await settle(tester);
  }

  testWidgets('Ctrl+P and ⌘P print the open PDF', (tester) async {
    printed.clear();
    await open(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    final first = [...printed];
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await settle(tester);
    await close(tester);
    expect(first, ['facture.pdf']);
    expect(printed.length, 2);
  });

  testWidgets('the Print key and a print request from Office In 1 print too', (tester) async {
    printed.clear();
    await open(tester);
    await tester.tap(find.byTooltip('Print (Ctrl+P)'));
    await settle(tester);
    final byKey = printed.length;
    printRequests.value++;
    await settle(tester);
    await close(tester);
    expect(byKey, 1);
    expect(printed.length, 2);
  });
}
