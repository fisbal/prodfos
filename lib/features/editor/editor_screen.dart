import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/platform/app_files.dart';
import '../../core/services/document_manager.dart';
import '../../core/services/pdf_edit_service.dart';
import 'page_canvas_screen.dart';
import 'page_organizer_screen.dart';

class EditorScreen extends StatefulWidget {
  final String filePath;
  const EditorScreen({super.key, required this.filePath});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  Uint8List? _bytes;
  int _version = 0;
  final List<Uint8List> _undo = [];
  PdfViewerController _controller = PdfViewerController();
  PdfAnnotationMode _markup = PdfAnnotationMode.none;
  int _page = 1;
  int _pageCount = 0;
  bool _dirty = false;
  bool _busy = false;
  String? _error;

  static const _gold = AppTheme.brandGold;

  String get _fileName => fileNameOf(widget.filePath);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await AppFiles.readBytes(widget.filePath);
      setState(() => _bytes = b);
    } catch (e) {
      setState(() => _error = 'Could not open file:\n$e');
    }
  }

  // ── Core flow ────────────────────────────────────────────
  /// Current document INCLUDING highlights and filled form fields made in the viewer.
  Future<Uint8List> _snapshot() async =>
      Uint8List.fromList(await _controller.saveDocument());

  void _commit(Uint8List before, Uint8List after) {
    final old = _controller;
    setState(() {
      _undo.add(before);
      if (_undo.length > 20) _undo.removeAt(0);
      _bytes = after;
      _version++;
      _controller = PdfViewerController();
      _dirty = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _setMarkup(PdfAnnotationMode m) {
    final next = _markup == m ? PdfAnnotationMode.none : m;
    setState(() {
      _markup = next;
      if (next != PdfAnnotationMode.none) _dirty = true;
    });
    _controller.annotationMode = next;
  }

  Future<void> _openCanvas(CanvasTool tool) async {
    if (_busy) return;
    _setMarkupOff();
    setState(() => _busy = true);
    try {
      final base = await _snapshot();
      if (!mounted) return;
      final result = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(builder: (_) =>
            PageCanvasScreen(bytes: base, pageIndex: _page - 1, initialTool: tool)),
      );
      if (result != null && mounted) _commit(base, result);
    } catch (e) {
      _snack('Could not open editor: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPages() async {
    if (_busy) return;
    _setMarkupOff();
    setState(() => _busy = true);
    try {
      final base = await _snapshot();
      if (!mounted) return;
      final result = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(builder: (_) => PageOrganizerScreen(bytes: base)),
      );
      if (result != null && mounted) {
        _page = 1;
        _commit(base, result);
      }
    } catch (e) {
      _snack('Could not open pages: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setMarkupOff() {
    if (_markup != PdfAnnotationMode.none) {
      _controller.annotationMode = PdfAnnotationMode.none;
      setState(() => _markup = PdfAnnotationMode.none);
    }
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    final old = _controller;
    setState(() {
      _bytes = _undo.removeLast();
      _version++;
      _controller = PdfViewerController();
      _markup = PdfAnnotationMode.none;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Future<void> _save() async {
    if (_busy) return;
    _setMarkupOff();
    setState(() => _busy = true);
    try {
      final out = await _snapshot();
      final path = await PdfEditService.saveEdited(out, _fileName);
      final name = path.split('/').last;
      if (!mounted) return;
      context.read<DocumentManager>().addToRecent(path, name);
      setState(() => _dirty = false);
      _showSaved(path, name);
    } catch (e) {
      _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSaved(String path, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green, size: 24),
          SizedBox(width: 8),
          Text('Saved'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name),
          const SizedBox(height: 8),
          Text(AppFiles.isWeb
              ? 'Kept in this browser (Tools → Created files). Use Download to save it.\nYour original file is untouched.'
              : 'Saved to the ProDFOS folder.\nYour original file is untouched.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep editing')),
          TextButton.icon(
            onPressed: () { Navigator.pop(ctx); AppFiles.share(path); },
            icon: Icon(AppFiles.isWeb ? Icons.download_rounded : Icons.share, size: 18),
            label: Text(AppFiles.isWeb ? 'Download' : 'Share'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.pushReplacement('/viewer?path=${Uri.encodeComponent(path)}');
            },
            icon: const Icon(Icons.visibility_rounded, size: 18), label: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Save your edits as a new copy before leaving?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Discard')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'stay'), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save')),
        ],
      ),
    );
    if (r == 'save') { await _save(); return false; }
    return r == 'discard';
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ══════════════════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted) Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              if (await _confirmLeave() && mounted) Navigator.of(this.context).pop();
            },
          ),
          titleSpacing: 0,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_fileName, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text(_pageCount > 0 ? 'Editing · page $_page of $_pageCount' : 'Editing',
              style: TextStyle(fontSize: 11, color: _gold.withValues(alpha: 0.8))),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: 'Undo',
              onPressed: _undo.isEmpty || _busy ? null : _undoLast,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilledButton.icon(
                onPressed: _busy || _bytes == null ? null : _save,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
        body: Column(children: [
          Expanded(child: _buildViewer()),
          if (_markup != PdfAnnotationMode.none) _markupHint(),
          _toolPanel(),
        ]),
      ),
    );
  }

  Widget _buildViewer() {
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }
    if (_bytes == null) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }
    return SfPdfViewer.memory(
      _bytes!,
      key: ValueKey(_version),
      controller: _controller,
      pageSpacing: 4,
      maxZoomLevel: 5, // pinch and double-tap zoom, required in every app
      enableDoubleTapZooming: true,
      onDocumentLoaded: (d) {
        setState(() => _pageCount = d.document.pages.count);
        if (_page > 1 && _page <= _pageCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _controller.jumpToPage(_page));
        }
      },
      onPageChanged: (d) => setState(() => _page = d.newPageNumber),
      onFormFieldValueChanged: (_) {
        if (!_dirty) setState(() => _dirty = true);
      },
      onDocumentLoadFailed: (d) => setState(() => _error = d.description),
    );
  }

  Widget _markupHint() {
    final name = _markup == PdfAnnotationMode.highlight ? 'Highlight'
        : _markup == PdfAnnotationMode.underline ? 'Underline' : 'Strikethrough';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _gold.withValues(alpha: 0.12),
      child: Text('$name on — drag across text. Tap $name again to stop.',
        style: TextStyle(fontSize: 12, color: _gold.withValues(alpha: 0.95))),
    );
  }

  Widget _toolPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(top: BorderSide(color: AppTheme.darkBorder.withValues(alpha: 0.6))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 82,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            children: [
              _tool(Icons.border_color_rounded, 'Highlight',
                  active: _markup == PdfAnnotationMode.highlight,
                  onTap: () => _setMarkup(PdfAnnotationMode.highlight)),
              _tool(Icons.format_underlined_rounded, 'Underline',
                  active: _markup == PdfAnnotationMode.underline,
                  onTap: () => _setMarkup(PdfAnnotationMode.underline)),
              _tool(Icons.strikethrough_s_rounded, 'Strike',
                  active: _markup == PdfAnnotationMode.strikethrough,
                  onTap: () => _setMarkup(PdfAnnotationMode.strikethrough)),
              _divider(),
              _tool(Icons.edit_rounded, 'Draw', onTap: () => _openCanvas(CanvasTool.pen)),
              _tool(Icons.text_fields_rounded, 'Text', onTap: () => _openCanvas(CanvasTool.text)),
              _tool(Icons.image_rounded, 'Image', onTap: () => _openCanvas(CanvasTool.image)),
              _tool(Icons.approval_rounded, 'Stamp', onTap: () => _openCanvas(CanvasTool.stamp)),
              _tool(Icons.draw_rounded, 'Sign', onTap: () => _openCanvas(CanvasTool.signature)),
              _tool(Icons.sticky_note_2_rounded, 'Note', onTap: () => _openCanvas(CanvasTool.note)),
              _tool(Icons.find_replace_rounded, 'Replace', onTap: () => _openCanvas(CanvasTool.replace)),
              _divider(),
              _tool(Icons.auto_awesome_motion_rounded, 'Pages', onTap: _openPages),
              _tool(Icons.assignment_rounded, 'Forms', onTap: () =>
                  _snack('Tap any form field in the document to fill it. Tap Save when done.')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tool(IconData icon, String label, {required VoidCallback onTap, bool active = false}) {
    return GestureDetector(
      onTap: _busy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 68,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: active ? _gold.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? _gold : Colors.transparent, width: 1.2),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 22, color: active ? _gold : Colors.white.withValues(alpha: 0.7)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? _gold : Colors.white.withValues(alpha: 0.6))),
        ]),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        color: AppTheme.darkBorder);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
