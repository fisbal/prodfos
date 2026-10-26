import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/platform/app_files.dart';
import 'core/platform/open_with.dart';
import 'core/services/document_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/window_bar.dart';
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

class ProDFOSApp extends StatefulWidget {
  /// A PDF the app was launched with ("Open with ProDFOS"), if any.
  final String? initialFile;
  const ProDFOSApp({super.key, this.initialFile});

  @override
  State<ProDFOSApp> createState() => _ProDFOSAppState();
}

class _ProDFOSAppState extends State<ProDFOSApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    // Safety net: anything that isn't an in-app page (e.g. a content:// or
    // file:// address handed over by Android/Windows) goes to the Library.
    redirect: (_, state) {
      final loc = state.uri.toString();
      return (loc.startsWith('/') && !loc.startsWith('//')) ? null : '/';
    },
    errorBuilder: (_, __) => const LibraryScreen(),
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

  @override
  void initState() {
    super.initState();
    final first = widget.initialFile;
    if (first != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openExternal(first));
    }
    OpenWith.listen(_openExternal);
  }

  /// Opens a PDF handed over by Windows Explorer / Android "Open with".
  void _openExternal(String path) {
    if (!mounted) return;
    context.read<DocumentManager>().addToRecent(path, fileNameOf(path));
    _router.push('/viewer?path=${Uri.encodeComponent(path)}');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ProDFOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      // Gold MartinB window bar (minimize / full screen / close) above every screen.
      builder: (context, child) => WindowFrame(child: child ?? const SizedBox.shrink()),
    );
  }
}
