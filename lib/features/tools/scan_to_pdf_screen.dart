import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/image_enhancer.dart';

class ScanToPdfScreen extends StatefulWidget {
  const ScanToPdfScreen({super.key});
  @override
  State<ScanToPdfScreen> createState() => _ScanToPdfScreenState();
}

class _ScanToPdfScreenState extends State<ScanToPdfScreen> {
  final List<_ScanPage> _pages = [];
  bool _isProcessing = false;
  String _status = '';
  String _filter = 'natural'; // original | natural | bright | bw

  static const _teal = Color(0xFF00897B);

  /// ProDFOS owns color processing whenever a ProDFOS filter is active.
  bool get _prodfosHandlesColor => _filter != 'original';

  // ── Capture ──────────────────────────────────────────────
  Future<void> _scanWithMLKit() async {
    // AUTO: ProDFOS filter active → Google in BASE mode (crop/perspective only,
    // zero enhancement → no double processing).
    // Original → FULL mode so Google's own tools stay available.
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg},
        mode: _prodfosHandlesColor ? ScannerMode.base : ScannerMode.full,
        pageLimit: 50,
        isGalleryImport: false,
      ),
    );

    try {
      final result = await scanner.scanDocument();
      final images = result.images ?? const <String>[];
      if (images.isEmpty) return;
      setState(() {
        for (final path in images) {
          _pages.add(_ScanPage(path: path, name: 'Page ${_pages.length + 1}'));
        }
      });
    } catch (e) {
      // User cancelling the scanner also lands here — stay quiet about that
      final msg = e.toString().toLowerCase();
      if (mounted && !msg.contains('cancel')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanner error: $e')),
        );
      }
    } finally {
      scanner.close();
    }
  }

  Future<void> _captureBasic() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera, requestFullMetadata: false,
    );
    if (photo == null) return;
    setState(() {
      _pages.add(_ScanPage(path: photo.path, name: 'Page ${_pages.length + 1}'));
    });
  }

  Future<void> _addFromGallery() async {
    final images = await ImagePicker().pickMultiImage(requestFullMetadata: false);
    if (images.isEmpty) return;
    setState(() {
      for (final im in images) {
        _pages.add(_ScanPage(path: im.path, name: 'Page ${_pages.length + 1}'));
      }
    });
  }

  // ── Build PDF ────────────────────────────────────────────
  Future<void> _createPdf() async {
    if (_pages.isEmpty) return;
    setState(() { _isProcessing = true; _status = 'Preparing...'; });

    try {
      var paths = _pages.map((p) => p.path).toList();

      if (_prodfosHandlesColor) {
        final tmp = await getTemporaryDirectory();
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final enhanced = <String>[];
        for (int i = 0; i < paths.length; i++) {
          setState(() => _status = 'Enhancing ${i + 1}/${paths.length}...');
          final out = '${tmp.path}/prodfos_enh_${stamp}_$i.jpg';
          await compute(enhanceImageFile, {
            'input': paths[i],
            'output': out,
            'mode': _filter,
          });
          enhanced.add(out);
        }
        paths = enhanced;
      }

      setState(() => _status = 'Building PDF...');
      final result = await context.read<PdfService>().imagesToPdf(paths);

      setState(() { _isProcessing = false; _status = ''; });
      if (mounted) _showSuccessDialog(result);
    } catch (e) {
      setState(() { _isProcessing = false; _status = ''; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  void _showSuccessDialog(PdfResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green, size: 24),
          SizedBox(width: 8),
          Text('Scan Complete'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_pages.length} page(s) scanned'),
            Text('File: ${result.fileName}'),
            Text('Size: ${result.fileSizeFormatted}'),
            const SizedBox(height: 8),
            Text('Saved to: ProDFOS folder in Downloads',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: const Text('Done'),
          ),
          TextButton.icon(
            onPressed: () { Navigator.pop(ctx); Share.shareXFiles([XFile(result.outputPath)]); },
            icon: const Icon(Icons.share, size: 18), label: const Text('Share'),
          ),
          FilledButton.icon(
            onPressed: () { Navigator.pop(ctx); OpenFilex.open(result.outputPath); },
            icon: const Icon(Icons.open_in_new, size: 18), label: const Text('Open'),
          ),
        ],
      ),
    );
  }

  void _renumberPages() {
    for (int i = 0; i < _pages.length; i++) {
      _pages[i] = _ScanPage(path: _pages[i].path, name: 'Page ${i + 1}');
    }
  }

  // ── UI ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan to PDF'),
        actions: [
          if (_pages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : _createPdf,
                icon: _isProcessing
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(_isProcessing ? _status : 'Create PDF'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_pages.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppTheme.darkCard.withValues(alpha: 0.5),
              child: Row(children: [
                Icon(Icons.description_rounded, size: 18, color: AppTheme.brandGold.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Text('${_pages.length} page(s)', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _isProcessing ? null : () => setState(() => _pages.clear()),
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text('Clear All', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ]),
            ),

          Expanded(child: _pages.isEmpty ? _buildEmptyState() : _buildPageList()),

          // Bottom panel: filters + capture buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              border: Border(top: BorderSide(color: AppTheme.darkBorder.withValues(alpha: 0.5))),
            ),
            child: Column(children: [
              Row(children: [
                Expanded(child: _filterChip('original', 'Original', Icons.image_rounded)),
                const SizedBox(width: 6),
                Expanded(child: _filterChip('natural', 'Natural', Icons.wb_sunny_outlined)),
                const SizedBox(width: 6),
                Expanded(child: _filterChip('bright', 'Bright', Icons.auto_fix_high_rounded)),
                const SizedBox(width: 6),
                Expanded(child: _filterChip('bw', 'B&W', Icons.contrast_rounded)),
              ]),
              const SizedBox(height: 8),
              Text(
                _prodfosHandlesColor
                    ? 'Google auto-enhance off · ProDFOS handles color'
                    : 'Google scanner tools enabled · no ProDFOS processing',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _scanWithMLKit,
                  icon: const Icon(Icons.document_scanner_rounded, size: 20),
                  label: const Text('Smart Scan'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _captureBasic,
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Quick Photo'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppTheme.brandGold.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _addFromGallery,
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppTheme.brandGold.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, IconData icon) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: _isProcessing ? null : () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brandGold.withValues(alpha: 0.15) : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.brandGold : AppTheme.darkBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 19,
            color: selected ? AppTheme.brandGold : Colors.white.withValues(alpha: 0.4)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.brandGold : Colors.white.withValues(alpha: 0.5),
          )),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84, height: 84,
            decoration: BoxDecoration(color: _teal.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.document_scanner_rounded, size: 42, color: _teal.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 20),
          const Text('Smart Document Scanner', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            'Pick a look below, then scan.\nNatural keeps the real paper tone and watermarks.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), height: 1.5),
          ),
        ]),
      ),
    );
  }

  Widget _buildPageList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pages.length,
      onReorder: (old, nw) {
        setState(() {
          if (nw > old) nw--;
          final item = _pages.removeAt(old);
          _pages.insert(nw, item);
          _renumberPages();
        });
      },
      itemBuilder: (_, i) {
        final page = _pages[i];
        return Card(
          key: ValueKey('scan_${page.path}_$i'),
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: Row(children: [
            Image.file(File(page.path), width: 80, height: 100, fit: BoxFit.cover,
              cacheWidth: 240,
              errorBuilder: (_, __, ___) => Container(width: 80, height: 100, color: AppTheme.darkBg,
                child: const Icon(Icons.broken_image, size: 24))),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(page.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Drag to reorder', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
              ],
            )),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: Colors.red.withValues(alpha: 0.7)),
              onPressed: _isProcessing ? null : () => setState(() { _pages.removeAt(i); _renumberPages(); }),
            ),
            const Icon(Icons.drag_handle, size: 20),
            const SizedBox(width: 8),
          ]),
        );
      },
    );
  }
}

class _ScanPage {
  final String path;
  final String name;
  _ScanPage({required this.path, required this.name});
}
