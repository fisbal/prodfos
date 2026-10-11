import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'core/services/document_manager.dart';
import 'core/services/preferences_service.dart';
import 'core/services/pdf_service.dart';
import 'core/services/ai_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('documents');
  await Hive.openBox('settings');

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
      child: const ProDFOSApp(),
    ),
  );
}
