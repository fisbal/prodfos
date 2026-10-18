import 'dart:typed_data';
import 'package:flutter/material.dart';
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

/// PDF viewer with two engines:
///  • Standard engine (Syncfusion) — fast reading, search, night mode, DocMind.
///  • Forms engine (pdf.js, the engine inside Firefox) — Adobe XFA and
///    scripted government forms that other readers show as "Please wait…".
/// XFA documents switch to the Forms engine automatically; any document can
/// be toggled from the toolbar.
class ViewerScreen extends StatefulWidget {
  final String filePath;
  const ViewerScreen({super.key, required this.filePath});
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
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await AppFiles.readBytes(widget.filePath);
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
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'Could not open this file:\n$e'; });
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
        return text.contains('Please wait') && text.contains('Adobe');
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
  void dispose() { _controller.dispose(); super.dispose(); }

  String get _fileName => fileNameOf(widget.filePath);

  void _saveProgress() {
    if (!_formsEngine) {
      context.read<DocumentManager>().saveReadingProgress(widget.filePath, _currentPage);
    }
  }

  void _onFormSaved(String path) {
    context.read<DocumentManager>().addToRecent(path, fileNameOf(path));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppFiles.isWeb
          ? 'Filled form downloaded · also in Tools → Created files'
          : 'Filled form saved · ${fileNameOf(path)}'),
      action: AppFiles.isWeb ? null : SnackBarAction(
        label: 'Share', textColor: AppTheme.brandGold,
        onPressed: () => AppFiles.share(path)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();

    return Scaffold(
      backgroundColor: _nightMode && !_formsEngine ? Colors.black : AppTheme.voidBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildToolbar(),

            if (_formsEngine && _isXfa && !_dismissedBanner) _formsBanner(),

            if (!_formsEngine && _isScanned && !_dismissedBanner)
              _banner(Icons.document_scanner_rounded, Colors.blue,
                  'Scanned document — text search and DocMind™ won\'t work.'),

            Expanded(child: _buildBody(prefs)),

            if (!_formsEngine && _totalPages > 0 && prefs.showPageCount) _buildPageBar(),
          ],
        ),
      ),
    );
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
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Go Back')),
          if (_bytes != null)
            FilledButton.icon(
              onPressed: () => setState(() { _errorMessage = null; _formsEngine = true; }),
              icon: const Icon(Icons.dynamic_form_rounded, size: 18),
              label: const Text('Try the Forms engine'),
            ),
        ]),
      ]),
    ));
  }

  Widget _formsBanner() => _banner(
        Icons.verified_rounded, AppTheme.brandGold,
        'Adobe XFA form — opened with the ProDFOS Forms engine (same as Firefox). '
        'Fill it in, then tap Save.');

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
        Key3D(icon: Icons.arrow_back_rounded, size: 38, tooltip: 'Back',
          onTap: () { _saveProgress(); Navigator.of(context).pop(); }),
        const SizedBox(width: 12),
        Expanded(child: Text(_fileName, overflow: TextOverflow.ellipsis,
          style: AppTheme.body(14, weight: FontWeight.w600))),
        const SizedBox(width: 6),
        Key3D(icon: Icons.dynamic_form_rounded, size: 36, active: _formsEngine,
          tooltip: _formsEngine ? 'Switch to standard viewer' : 'Open with Forms engine (XFA)',
          onTap: _bytes == null ? null : toggleEngine),
        if (!_formsEngine) ...[
          const SizedBox(width: 6),
          Key3D(icon: _nightMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 36,
            active: _nightMode, tooltip: 'Night mode',
            onTap: () => setState(() => _nightMode = !_nightMode)),
        ],
        const SizedBox(width: 4),
        Tooltip(
          message: 'DocMind™ AI',
          child: AiOrb(size: 44, onTap: () => DocMindSheet.show(context, widget.filePath)),
        ),
        if (!_formsEngine) ...[
          const SizedBox(width: 4),
          Key3D(icon: Icons.edit_note_rounded, size: 36, gold: true, tooltip: 'Edit PDF',
            onTap: () {
              _saveProgress();
              context.push('/editor?path=${Uri.encodeComponent(widget.filePath)}');
            }),
        ],
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          key: _menuKey,
          tooltip: 'More',
          onSelected: (action) {
            switch (action) {
              case 'first': _controller.jumpToPage(1);
              case 'last': if (_totalPages > 0) _controller.jumpToPage(_totalPages);
              case 'bookmark': _viewerKey.currentState?.openBookmarkView();
              case 'share': AppFiles.share(widget.filePath);
            }
          },
          itemBuilder: (_) => [
            if (!_formsEngine) ...const [
              PopupMenuItem(value: 'first', child: Text('Go to First Page')),
              PopupMenuItem(value: 'last', child: Text('Go to Last Page')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'bookmark', child: Text('Bookmarks')),
            ],
            PopupMenuItem(value: 'share', child: Text(AppFiles.isWeb ? 'Download' : 'Share')),
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
    setState(() { _isLoading = false; _errorMessage = 'Failed to load PDF:\n${d.description}'; });
  }
}
