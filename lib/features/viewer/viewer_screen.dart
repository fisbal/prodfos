import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync_pdf;
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/document_manager.dart';
import '../../core/services/preferences_service.dart';
import '../docmind/docmind_sheet.dart';

class ViewerScreen extends StatefulWidget {
  final String filePath;
  static Uint8List? webBytes;
  static String? webFileName;
  const ViewerScreen({super.key, required this.filePath});
  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final GlobalKey<SfPdfViewerState> _viewerKey = GlobalKey();
  final PdfViewerController _controller = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 0;
  bool _nightMode = false;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isXfa = false;
  bool _isScanned = false;
  bool _dismissedBanner = false;

  @override
  void initState() {
    super.initState();
    _nightMode = context.read<PreferencesService>().nightMode;
    // Pre-check for XFA before viewer loads
    if (!kIsWeb && widget.filePath != 'web-memory') {
      _preCheck();
    }
  }

  /// Quick pre-check: scan PDF bytes for /XFA marker
  Future<void> _preCheck() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final content = String.fromCharCodes(bytes, 0, bytes.length.clamp(0, bytes.length));
      if (content.contains('/XFA')) {
        setState(() { _isXfa = true; _isLoading = false; });
        return;
      }
      // Also check text of page 1 for "Please wait" fallback
      try {
        final doc = sync_pdf.PdfDocument(inputBytes: bytes);
        if (doc.pages.count > 0) {
          final extractor = sync_pdf.PdfTextExtractor(doc);
          final text = extractor.extractText(startPageIndex: 0, endPageIndex: 0);
          if (text.contains('Please wait') && text.contains('Adobe Reader')) {
            setState(() { _isXfa = true; _isLoading = false; });
            doc.dispose();
            return;
          }
          // Check if scanned (no text on first 3 pages)
          if (text.trim().isEmpty && doc.pages.count <= 3) {
            bool hasText = false;
            for (int i = 1; i < doc.pages.count; i++) {
              final t = extractor.extractText(startPageIndex: i, endPageIndex: i);
              if (t.trim().isNotEmpty) { hasText = true; break; }
            }
            if (!hasText) setState(() => _isScanned = true);
          }
        }
        doc.dispose();
      } catch (_) {}

      // Restore reading position
      final lastPage = context.read<DocumentManager>().getLastPage(widget.filePath);
      if (lastPage > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _controller.jumpToPage(lastPage);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  String get _fileName {
    if (widget.filePath == 'web-memory') return ViewerScreen.webFileName ?? 'Document';
    return widget.filePath.split(RegExp(r'[/\\]')).last;
  }

  void _saveProgress() {
    if (!kIsWeb && widget.filePath != 'web-memory') {
      context.read<DocumentManager>().saveReadingProgress(widget.filePath, _currentPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();

    return Scaffold(
      backgroundColor: _nightMode ? Colors.black : Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildToolbar(),

            // Scanned document banner
            if (_isScanned && !_dismissedBanner)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.blue.withValues(alpha: 0.12),
                child: Row(children: [
                  const Icon(Icons.document_scanner_rounded, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Scanned document — text search and DocMind™ won\'t work.',
                    style: TextStyle(fontSize: 12, color: Colors.white70))),
                  IconButton(icon: const Icon(Icons.close, size: 16), padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _dismissedBanner = true)),
                ]),
              ),

            // Main content
            Expanded(
              child: _isXfa
                  ? _buildXfaScreen()
                  : Stack(children: [
                      ColorFiltered(
                        colorFilter: _nightMode
                            ? const ColorFilter.matrix([-1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0])
                            : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                        child: _buildPdfViewer(prefs),
                      ),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator(color: AppTheme.brandGold)),
                      if (_errorMessage != null)
                        Center(child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text(_errorMessage!, textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                            const SizedBox(height: 16),
                            TextButton(onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Go Back')),
                          ]),
                        )),
                    ]),
            ),

            if (_totalPages > 0 && prefs.showPageCount && !_isXfa) _buildPageBar(),
          ],
        ),
      ),
    );
  }

  // ── XFA Screen ───────────────────────────────────────────
  Widget _buildXfaScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, size: 44, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            const Text('XFA Form Detected', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(
              'This PDF uses Adobe XFA technology (created with Adobe LiveCycle).\n\n'
              'No PDF viewer can display XFA forms except Adobe Acrobat Reader — '
              'not Chrome, Firefox, Foxit, or any mobile app.\n\n'
              'To view or fill this form, use Adobe Acrobat Reader (free on Play Store).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), height: 1.6, fontSize: 14),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Go Back'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () {
                    // Share the file so user can open it in Adobe
                    Share.shareXFiles(
                      [XFile(widget.filePath)],
                      text: 'Open this XFA form in Adobe Acrobat Reader',
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open in Another App'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Toolbar ──────────────────────────────────────────────
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22),
          onPressed: () { _saveProgress(); Navigator.of(context).pop(); }),
        Expanded(child: Text(_fileName, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        IconButton(
          icon: Icon(_nightMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20,
            color: _nightMode ? AppTheme.brandGold : null),
          onPressed: () => setState(() => _nightMode = !_nightMode),
        ),
        IconButton(
          icon: const Icon(Icons.auto_awesome, size: 20, color: Color(0xFF6C5CE7)),
          tooltip: 'DocMind™ AI',
          onPressed: () => DocMindSheet.show(context, widget.filePath),
        ),
        IconButton(icon: const Icon(Icons.edit_note_rounded, size: 24),
          tooltip: 'Edit PDF',
          onPressed: () {
            if (kIsWeb || widget.filePath == 'web-memory' || _isXfa) return;
            _saveProgress();
            context.push('/editor?path=${Uri.encodeComponent(widget.filePath)}');
          }),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 20),
          onSelected: (action) {
            switch (action) {
              case 'first': _controller.jumpToPage(1);
              case 'last': if (_totalPages > 0) _controller.jumpToPage(_totalPages);
              case 'bookmark': _viewerKey.currentState?.openBookmarkView();
              case 'share':
                if (!kIsWeb && widget.filePath != 'web-memory') {
                  Share.shareXFiles([XFile(widget.filePath)]);
                }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'first', child: Text('Go to First Page')),
            PopupMenuItem(value: 'last', child: Text('Go to Last Page')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'bookmark', child: Text('Bookmarks')),
            PopupMenuItem(value: 'share', child: Text('Share')),
          ],
        ),
      ]),
    );
  }

  // ── PDF Viewer ───────────────────────────────────────────
  Widget _buildPdfViewer(PreferencesService prefs) {
    if (kIsWeb || widget.filePath == 'web-memory') {
      final bytes = ViewerScreen.webBytes;
      if (bytes == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() { _isLoading = false; _errorMessage = 'No PDF data available'; });
        });
        return const SizedBox.shrink();
      }
      return SfPdfViewer.memory(bytes,
        key: _viewerKey, controller: _controller,
        canShowScrollHead: prefs.showScrollHead,
        enableTextSelection: true, pageSpacing: prefs.pageSpacing,
        onDocumentLoaded: _onLoaded, onPageChanged: _onPageChanged, onDocumentLoadFailed: _onFailed,
      );
    }
    return SfPdfViewer.file(File(widget.filePath),
      key: _viewerKey, controller: _controller,
      canShowScrollHead: prefs.showScrollHead,
      enableTextSelection: true, pageSpacing: prefs.pageSpacing,
      onDocumentLoaded: _onLoaded, onPageChanged: _onPageChanged, onDocumentLoadFailed: _onFailed,
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
          child: Slider(value: _currentPage.toDouble(), min: 1,
            max: _totalPages.toDouble().clamp(1, double.infinity),
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
  }
  void _onPageChanged(PdfPageChangedDetails d) {
    setState(() => _currentPage = d.newPageNumber); _saveProgress();
  }
  void _onFailed(PdfDocumentLoadFailedDetails d) {
    setState(() { _isLoading = false; _errorMessage = 'Failed to load PDF:\n${d.description}'; });
  }
}
