import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../../core/services/print/print_requests.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync_pdf;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/scene3d.dart';
import '../../core/platform/app_files.dart';
import '../../core/services/document_manager.dart';
import '../../core/services/preferences_service.dart';
import '../docmind/docmind_sheet.dart';
import '../forms/xfa_view.dart';
import '../../core/l10n/l10n.dart';

/// PDF viewer with two engines:
///  • Standard engine (Syncfusion) — fast reading, search, night mode, DocMind.
///  • Forms engine (pdf.js, the engine inside Firefox) — Adobe XFA and
///    scripted government forms that other readers show as "Please wait…".
/// XFA documents switch to the Forms engine automatically; any document can
/// be toggled from the toolbar.
class ViewerScreen extends StatefulWidget {
  final String filePath;
  /// The file's bytes when they are already in memory (skips reading [filePath] again).
  final Uint8List? bytes;
  const ViewerScreen({super.key, required this.filePath, this.bytes});
  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final GlobalKey<SfPdfViewerState> _viewerKey = GlobalKey();
  final PdfViewerController _controller = PdfViewerController();
  final GlobalKey<PopupMenuButtonState<String>> _menuKey = GlobalKey();
  Uint8List? _bytes;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _nightMode = false;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isXfa = false;
  bool _formsEngine = false;
  bool _isScanned = false;
  bool _dismissedBanner = false;
  bool _restoredPage = false;

  @override
  void initState() {
    super.initState();
    _nightMode = context.read<PreferencesService>().nightMode;
    printRequests.addListener(_onPrintRequest);
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = widget.bytes ?? await AppFiles.readBytes(widget.filePath);
      final xfa = _containsAscii(bytes, '/XFA') || _looksLikeXfaPlaceholder(bytes);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _isXfa = xfa;
        _formsEngine = xfa;
        if (xfa) _isLoading = false;
      });
      if (!xfa) _checkScanned(bytes);
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = tr('Could not open this file:\n{e}', {'e': e}); });
    }
  }

  /// Fast byte search — no string conversion of the whole file.
  static bool _containsAscii(Uint8List bytes, String needle) {
    final n = needle.codeUnits;
    final last = bytes.length - n.length;
    outer:
    for (int i = 0; i <= last; i++) {
      if (bytes[i] != n[0]) continue;
      for (int j = 1; j < n.length; j++) {
        if (bytes[i + j] != n[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  /// XFA hidden inside compressed object streams: page 1 only says "Please wait".
  static bool _looksLikeXfaPlaceholder(Uint8List bytes) {
    try {
      final doc = sync_pdf.PdfDocument(inputBytes: bytes);
      try {
        if (doc.pages.count == 0) return false;
        final text = sync_pdf.PdfTextExtractor(doc).extractText(startPageIndex: 0, endPageIndex: 0);
        return text.contains(tr('Please wait')) && text.contains('Adobe');
      } finally {
        doc.dispose();
      }
    } catch (_) {
      return false;
    }
  }

  void _checkScanned(Uint8List bytes) {
    try {
      final doc = sync_pdf.PdfDocument(inputBytes: bytes);
      final extractor = sync_pdf.PdfTextExtractor(doc);
      final pages = doc.pages.count.clamp(0, 3);
      bool hasText = false;
      for (int i = 0; i < pages; i++) {
        if (extractor.extractText(startPageIndex: i, endPageIndex: i).trim().isNotEmpty) {
          hasText = true;
          break;
        }
      }
      doc.dispose();
      if (!hasText && pages > 0 && mounted) setState(() => _isScanned = true);
    } catch (_) {}
  }

  @override
  void dispose() { printRequests.removeListener(_onPrintRequest); _controller.dispose(); super.dispose(); }

  String get _fileName => fileNameOf(widget.filePath);

  /// Prints the PDF itself (never a picture of the screen) with the system print dialog.
  Future<void> _print() async {
    final bytes = _bytes;
    if (bytes == null) return;
    try {
      if (insideOfficeIn1) {
        // Inside Office In 1 the browser cannot print a PDF from a frame: Office In 1 prints the pages itself.
        final pngs = <Uint8List>[];
        await for (final r in Printing.raster(bytes, dpi: 150)) {
          pngs.add(await r.toPng());
        }
        sendPagesToPrint(_fileName, pngs);
        return;
      }
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: _fileName);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Printing failed: {e}', {'e': e}))));
    }
  }

  void _onPrintRequest() => _print();

  void _saveProgress() {
    if (!_formsEngine) {
      context.read<DocumentManager>().saveReadingProgress(widget.filePath, _currentPage);
    }
  }

  void _onFormSaved(String path) {
    context.read<DocumentManager>().addToRecent(path, fileNameOf(path));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppFiles.isWeb
          ? tr('Filled form downloaded · also in Tools → Created files')
          : tr('Filled form saved · {name}', {'name': fileNameOf(path)})),
      action: AppFiles.isWeb ? null : SnackBarAction(
        label: tr('Share'), textColor: AppTheme.brandGold,
        onPressed: () => AppFiles.share(path)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();

    // Ctrl+P (⌘P on Mac) prints, like in every PDF reader.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): _print,
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true): _print,
      },
      child: Focus(autofocus: true, child: Scaffold(
      backgroundColor: _nightMode && !_formsEngine ? Colors.black : AppTheme.voidBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildToolbar(),

            if (_formsEngine && _isXfa && !_dismissedBanner) _formsBanner(),

            if (!_formsEngine && _isScanned && !_dismissedBanner)
              _banner(Icons.document_scanner_rounded, Colors.blue,
                  tr('Scanned document — text search and DocMind™ won\'t work.')),

            Expanded(child: _buildBody(prefs)),

            if (!_formsEngine && _totalPages > 0 && prefs.showPageCount) _buildPageBar(),
          ],
        ),
      ),
    )));
  }

  Widget _buildBody(PreferencesService prefs) {
    if (_errorMessage != null) return _errorView();
    final bytes = _bytes;
    if (bytes == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.brandGold));
    }
    if (_formsEngine) {
      return XfaView(
        key: ValueKey('forms_${widget.filePath}'),
        bytes: bytes, name: _fileName, onSaved: _onFormSaved);
    }
    return Stack(children: [
      ColorFiltered(
        colorFilter: _nightMode
            ? const ColorFilter.matrix([-1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0])
            : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
        child: SfPdfViewer.memory(bytes,
          key: _viewerKey, controller: _controller,
          canShowScrollHead: prefs.showScrollHead,
          enableTextSelection: true, pageSpacing: prefs.pageSpacing,
          maxZoomLevel: 5, enableDoubleTapZooming: true, // pinch and double-tap zoom, required in every app
          onDocumentLoaded: _onLoaded, onPageChanged: _onPageChanged, onDocumentLoadFailed: _onFailed,
        ),
      ),
      if (_isLoading)
        const Center(child: CircularProgressIndicator(color: AppTheme.brandGold)),
    ]);
  }

  Widget _errorView() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text(_errorMessage!, textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
        const SizedBox(height: 20),
        Wrap(spacing: 12, runSpacing: 8, alignment: WrapAlignment.center, children: [
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('Go Back'))),
          if (_bytes != null)
            FilledButton.icon(
              onPressed: () => setState(() { _errorMessage = null; _formsEngine = true; }),
              icon: const Icon(Icons.dynamic_form_rounded, size: 18),
              label: Text(tr('Try the Forms engine')),
            ),
        ]),
      ]),
    ));
  }

  Widget _formsBanner() => _banner(
        Icons.verified_rounded, AppTheme.brandGold,
        tr('Adobe XFA form — opened with the ProDFOS Forms engine (same as Firefox). Fill it in, then tap Save.'));

  Widget _banner(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: color.withValues(alpha: 0.10),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white70))),
        IconButton(icon: const Icon(Icons.close, size: 16), padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => setState(() => _dismissedBanner = true)),
      ]),
    );
  }

  // ── Toolbar ──────────────────────────────────────────────
  Widget _buildToolbar() {
    void toggleEngine() => setState(() {
          _formsEngine = !_formsEngine;
          _errorMessage = null;
          _isLoading = !_formsEngine;
          _totalPages = 0;
        });
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF17171E), Color(0xFF0C0C11)],
        ),
        border: Border(bottom: BorderSide(color: AppTheme.brandGold.withValues(alpha: 0.18))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Key3D(icon: Icons.arrow_back_rounded, size: 38, tooltip: tr('Back'),
          onTap: () { _saveProgress(); Navigator.of(context).pop(); }),
        const SizedBox(width: 12),
        Expanded(child: Text(_fileName, overflow: TextOverflow.ellipsis,
          style: AppTheme.body(14, weight: FontWeight.w600))),
        const SizedBox(width: 6),
        Key3D(icon: Icons.dynamic_form_rounded, size: 36, active: _formsEngine,
          tooltip: _formsEngine ? tr('Switch to standard viewer') : tr('Open with Forms engine (XFA)'),
          onTap: _bytes == null ? null : toggleEngine),
        if (!_formsEngine) ...[
          const SizedBox(width: 6),
          Key3D(icon: _nightMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 36,
            active: _nightMode, tooltip: tr('Night mode'),
            onTap: () => setState(() => _nightMode = !_nightMode)),
        ],
        const SizedBox(width: 4),
        Tooltip(
          message: tr('DocMind™ AI'),
          child: AiOrb(size: 44, onTap: () => DocMindSheet.show(context, widget.filePath)),
        ),
        if (!_formsEngine) ...[
          const SizedBox(width: 4),
          Key3D(icon: Icons.edit_note_rounded, size: 36, gold: true, tooltip: tr('Edit PDF'),
            onTap: () {
              _saveProgress();
              context.push('/editor?path=${Uri.encodeComponent(widget.filePath)}');
            }),
        ],
        // Narrow phones keep Print in the ⋮ menu (and Ctrl+P), so the file name keeps its room.
        if (MediaQuery.sizeOf(context).width >= 420) ...[
          const SizedBox(width: 4),
          Key3D(icon: Icons.print_rounded, size: 36, tooltip: tr('Print (Ctrl+P)'),
            onTap: _bytes == null ? null : _print),
        ],
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          key: _menuKey,
          tooltip: tr('More'),
          onSelected: (action) {
            switch (action) {
              case 'first': _controller.jumpToPage(1);
              case 'last': if (_totalPages > 0) _controller.jumpToPage(_totalPages);
              case 'bookmark': _viewerKey.currentState?.openBookmarkView();
              case 'share': AppFiles.share(widget.filePath);
              case 'print': _print();
            }
          },
          itemBuilder: (_) => [
            if (!_formsEngine) ...[
              PopupMenuItem(value: 'first', child: Text(tr('Go to First Page'))),
              PopupMenuItem(value: 'last', child: Text(tr('Go to Last Page'))),
              PopupMenuDivider(),
              PopupMenuItem(value: 'bookmark', child: Text(tr('Bookmarks'))),
            ],
            PopupMenuItem(value: 'print', child: Text(tr('Print (Ctrl+P)'))),
            PopupMenuItem(value: 'share', child: Text(AppFiles.isWeb ? tr('Download') : tr('Share'))),
          ],
          child: Key3D(icon: Icons.more_vert_rounded, size: 36,
              onTap: () => _menuKey.currentState?.showButtonMenu()),
        ),
      ]),
    );
  }

  Widget _buildPageBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(top: BorderSide(color: AppTheme.darkBorder.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.chevron_left, size: 20),
          onPressed: _currentPage > 1 ? () => _controller.previousPage() : null),
        Expanded(child: SliderTheme(
          data: SliderThemeData(activeTrackColor: AppTheme.brandGold, inactiveTrackColor: AppTheme.darkBorder,
            thumbColor: AppTheme.brandGold, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), trackHeight: 3),
          child: Slider(value: _currentPage.clamp(1, _totalPages < 1 ? 1 : _totalPages).toDouble(),
            min: 1,
            max: (_totalPages < 1 ? 1 : _totalPages).toDouble(),
            onChanged: (v) => _controller.jumpToPage(v.toInt())),
        )),
        IconButton(icon: const Icon(Icons.chevron_right, size: 20),
          onPressed: _currentPage < _totalPages ? () => _controller.nextPage() : null),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(8)),
          child: Text('$_currentPage / $_totalPages',
            style: const TextStyle(color: AppTheme.brandGold, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ]),
    );
  }

  void _onLoaded(PdfDocumentLoadedDetails d) {
    setState(() { _totalPages = d.document.pages.count; _currentPage = _controller.pageNumber; _isLoading = false; });
    // Restore reading position once
    if (!_restoredPage) {
      _restoredPage = true;
      final lastPage = context.read<DocumentManager>().getLastPage(widget.filePath);
      if (lastPage > 1 && lastPage <= _totalPages) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _controller.jumpToPage(lastPage));
      }
    }
  }
  void _onPageChanged(PdfPageChangedDetails d) {
    setState(() => _currentPage = d.newPageNumber); _saveProgress();
  }
  void _onFailed(PdfDocumentLoadFailedDetails d) {
    setState(() { _isLoading = false; _errorMessage = tr('Failed to load PDF:\n{e}', {'e': d.description}); });
  }
}
