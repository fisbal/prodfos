import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import '../../core/platform/app_files.dart';
import '../../core/theme/app_theme.dart';
import 'forms_server.dart';

/// Native Forms engine view (Android WebView / Windows WebView2).
class XfaView extends StatefulWidget {
  final Uint8List bytes;
  final String name;

  /// Called with the saved file path after the user taps Save.
  final ValueChanged<String>? onSaved;

  const XfaView({super.key, required this.bytes, required this.name, this.onSaved});

  @override
  State<XfaView> createState() => _XfaViewState();
}

class _XfaViewState extends State<XfaView> {
  Uri? _uri;
  String? _error;
  WebViewController? _android;
  win.WebviewController? _windows;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final uri = await FormsServer.register(bytes: widget.bytes, name: widget.name, onSave: _save);
      if (Platform.isAndroid) {
        _android = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(AppTheme.voidBlack)
          ..loadRequest(uri);
      } else if (Platform.isWindows) {
        // WebView2 ships with Windows 10/11. If it is missing we fall back to the browser.
        final version = await win.WebviewController.getWebViewVersion();
        if (version != null) {
          final c = win.WebviewController();
          await c.initialize();
          await c.setBackgroundColor(AppTheme.voidBlack);
          await c.setPopupWindowPolicy(win.WebviewPopupWindowPolicy.deny);
          await c.loadUrl(uri.toString());
          _windows = c;
        }
      }
      if (mounted) setState(() => _uri = uri);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Filled form → new file next to the other ProDFOS outputs. Original untouched.
  Future<String> _save(Uint8List data) async {
    final dir = await AppFiles.outputDir();
    final base = widget.name
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^\w\-]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final name = '${base}_filled_$stamp.pdf';
    final path = AppFiles.join(dir, name);
    await AppFiles.writeBytes(path, data);
    if (mounted) widget.onSaved?.call(path);
    return name;
  }

  @override
  void dispose() {
    FormsServer.unregister(_uri);
    _windows?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _message(Icons.error_outline_rounded, 'Forms engine could not start', _error!);
    }
    if (_uri == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.brandGold));
    }
    if (_android != null) return WebViewWidget(controller: _android!);
    if (_windows != null) return win.Webview(_windows!);

    // No embedded browser available → open the same engine in the default browser.
    return _message(
      Icons.open_in_browser_rounded,
      'Open this form in your browser',
      'The built-in viewer needs Microsoft Edge WebView2. ProDFOS can still open the form '
          'in your browser with the same engine — Save still lands in your ProDFOS folder.',
      action: FilledButton.icon(
        onPressed: () => launchUrl(_uri!, mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: const Text('Open in browser'),
      ),
    );
  }

  Widget _message(IconData icon, String title, String text, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: AppTheme.brandGold),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: AppTheme.display(22)),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center,
              style: AppTheme.body(14, color: AppTheme.creamMuted, height: 1.5)),
          if (action != null) ...[const SizedBox(height: 22), action],
        ]),
      ),
    );
  }
}
