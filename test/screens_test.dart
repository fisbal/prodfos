// Every page of ProDFOS must fit phones, tablets, PCs and Macs, upright and sideways:
// Flutter reports any row or column that does not fit ("overflowed by N pixels") as an
// error, which fails this test. Runs in CI on every pull request.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:prodfos/app.dart';
import 'package:prodfos/core/services/ai_service.dart';
import 'package:prodfos/core/services/document_manager.dart';
import 'package:prodfos/core/services/pdf_service.dart';
import 'package:prodfos/core/services/preferences_service.dart';
import 'package:prodfos/core/services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sizes = <String, Size>{
  'phone': Size(390, 844),
  'phone-landscape': Size(844, 390),
  'tablet': Size(820, 1180),
  'tablet-landscape': Size(1180, 820),
  'pc': Size(1366, 768),
  'mac': Size(1440, 900),
};

const pages = <String>[
  '/',
  '/tools',
  '/tools/merge',
  '/tools/split',
  '/tools/extract-text',
  '/tools/images-to-pdf',
  '/tools/text-to-pdf',
  '/tools/scan',
  '/settings',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late PreferencesService prefs;

  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('prodfos_test').path);
    await Hive.openBox('documents');
    await Hive.openBox('settings');
    SharedPreferences.setMockInitialValues({});
    prefs = PreferencesService();
    await prefs.init();
  });

  for (final size in sizes.entries) {
    for (final page in pages) {
      testWidgets('$page fits a ${size.key} (${size.value.width.toInt()}x${size.value.height.toInt()})', (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        // Collect layout errors with their full description (which widget, how much too big).
        final errors = <FlutterErrorDetails>[];
        final reportError = FlutterError.onError;
        FlutterError.onError = errors.add;
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: prefs),
            ChangeNotifierProvider(create: (_) => DocumentManager()),
            ChangeNotifierProvider(create: (_) => PdfService()),
            ChangeNotifierProvider(create: (_) => AiService()),
            ChangeNotifierProvider(create: (_) => UpdateService()),
          ],
          child: ProDFOSApp(key: UniqueKey(), initialLocation: page),
        ));
        // Let entrance animations settle without waiting on endless ones.
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        FlutterError.onError = reportError;
        expect(errors, isEmpty, reason: errors.map((e) => e.toString()).join('\n'));
      });
    }
  }
}
