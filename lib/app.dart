import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/library/library_screen.dart';
import 'features/viewer/viewer_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/tools/tools_screen.dart';
import 'features/tools/merge_screen.dart';
import 'features/tools/split_screen.dart';
import 'features/tools/extract_text_screen.dart';
import 'features/tools/images_to_pdf_screen.dart';
import 'features/tools/text_to_pdf_screen.dart';
import 'features/tools/scan_to_pdf_screen.dart';
import 'features/editor/editor_screen.dart';

class ProDFOSApp extends StatelessWidget {
  const ProDFOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const LibraryScreen()),
        GoRoute(
          path: '/viewer',
          builder: (_, state) {
            final filePath = state.uri.queryParameters['path'] ?? '';
            return ViewerScreen(filePath: filePath);
          },
        ),
        GoRoute(
          path: '/editor',
          builder: (_, state) =>
              EditorScreen(filePath: state.uri.queryParameters['path'] ?? ''),
        ),
        GoRoute(path: '/tools', builder: (_, __) => const ToolsScreen()),
        GoRoute(path: '/tools/merge', builder: (_, __) => const MergeScreen()),
        GoRoute(path: '/tools/split', builder: (_, __) => const SplitScreen()),
        GoRoute(path: '/tools/extract-text', builder: (_, __) => const ExtractTextScreen()),
        GoRoute(path: '/tools/images-to-pdf', builder: (_, __) => const ImagesToPdfScreen()),
        GoRoute(path: '/tools/text-to-pdf', builder: (_, __) => const TextToPdfScreen()),
        GoRoute(path: '/tools/scan', builder: (_, __) => const ScanToPdfScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    );

    return MaterialApp.router(
      title: 'ProDFOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
