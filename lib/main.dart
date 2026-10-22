import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'core/platform/app_files.dart';
import 'core/platform/open_with.dart';
import 'core/services/document_manager.dart';
import 'core/services/preferences_service.dart';
import 'core/services/pdf_service.dart';
import 'core/services/ai_service.dart';
import 'app.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bundled Mozilla pdf.js (Forms engine) — shown in Settings → Open-source licenses
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/pdfjs/LICENSE-pdfjs.txt');
    yield LicenseEntryWithLineBreaks(const ['pdf.js (Mozilla)'], text);
  });
  final privateDir = await AppFiles.privateDataDir();
  if (privateDir != null) {
    Hive.init(privateDir); // Windows: AppData, not Documents
  } else {
    await Hive.initFlutter();
  }
  await Hive.openBox('documents');
  await Hive.openBox('settings');
  await AppFiles.init(); // browser file storage on web, no-op on Android/Windows

  // PDF double-clicked in Explorer / opened with ProDFOS on Android
  final initialFile = await OpenWith.initialFile(args);

  final prefs = PreferencesService();
  await prefs.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider(create: (_) => DocumentManager()),
        ChangeNotifierProvider(create: (_) => PdfService()),
        ChangeNotifierProvider(create: (_) => AiService()),
      ],
      child: ProDFOSApp(initialFile: initialFile),
    ),
  );
}
