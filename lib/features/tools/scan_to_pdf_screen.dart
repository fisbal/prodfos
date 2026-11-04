import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/platform/app_files.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/image_enhancer.dart';
import '../../core/services/scan_layout.dart';
import 'scan_types.dart';
import '../../core/l10n/l10n.dart';

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
  ScanType _type = scanTypes.first;
  // Book: cut double pages in two, reading direction, binding shadow, cover kept whole.
  bool _split = true, _rtl = false, _shadow = true, _cover = true;
  // Cards: a watermark so a copy cannot be reused ("Copie pour la banque X").
  final _mark = TextEditingController();

  @override
  void dispose() { _mark.dispose(); super.dispose(); }

  void _pickType(ScanType t) => setState(() { _type = t; _filter = t.filter; });

  /// Cards: which side the next picture is (front, back).
  String get _nextSide => !_type.isCard || _type.sides < 2 ? '' : (_pages.length.isEven ? tr('Front side') : tr('Back side§card'));

  static const _teal = Color(0xFF00897B);

  /// ProDFOS owns color processing whenever a ProDFOS filter is active.
  bool get _prodfosHandlesColor => _filter != 'original';

  /// Google's ML Kit scanner only exists on Android phones.
  bool get _hasSmartScanner => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Camera capture: Android, and phone browsers (web). Not Windows desktop.
  bool get _hasCamera => kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  /// Image picker results → ProDFOS paths (bytes are copied into the browser store on web).
  Future<void> _addXFiles(List<XFile> files) async {
    final paths = <String>[];
    for (final x in files) {
      paths.add(kIsWeb ? await AppFiles.fromBytes(await x.readAsBytes(), x.name) : x.path);
    }
    if (!mounted) return;
    setState(() {
      for (final p in paths) {
        _pages.add(_ScanPage(path: p, name: tr('Page {n}', {'n': _pages.length + 1})));
      }
    });
  }

  // ── Capture ──────────────────────────────────────────────
  Future<void> _scanWithMLKit() async {
    // AUTO: ProDFOS filter active → Google in BASE mode (crop/perspective only,
    // zero enhancement → no double processing).
    // Original → FULL mode so Google's own tools stay available.
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg},
        mode: _prodfosHandlesColor ? ScannerMode.base : ScannerMode.full,
        pageLimit: _type.isCard ? _type.sides : 50,
        isGalleryImport: false,
      ),
    );

    try {
      final result = await scanner.scanDocument();
      final images = result.images ?? const <String>[];
      if (images.isEmpty) return;
      setState(() {
        for (final path in images) {
          _pages.add(_ScanPage(path: path, name: tr('Page {n}', {'n': _pages.length + 1})));
        }
      });
    } catch (e) {
      // User cancelling the scanner also lands here — stay quiet about that
      final msg = e.toString().toLowerCase();
      if (mounted && !msg.contains('cancel')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Scanner error: {e}', {'e': e}))),
        );
      }
    } finally {
      scanner.close();
    }
  }

  /// Book: the camera opens again for the next page until you cancel. Card: front, then back.
  Future<void> _captureBasic() async {
    final start = _pages.length;
    while (mounted) {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera, requestFullMetadata: false,
      );
      if (photo == null) return;
      await _addXFiles([photo]);
      final taken = _pages.length - start;
      final more = _type.layout == 'book' || (_type.isCard && taken < _type.sides);
      if (!more || taken >= 200) return;
    }
  }

  Future<void> _addFromGallery() async {
    final images = await ImagePicker().pickMultiImage(requestFullMetadata: false);
    if (images.isEmpty) return;
    await _addXFiles(images);
  }

  // ── Build PDF ────────────────────────────────────────────
  Future<({String name, bool elsewhere})?> _askNameAndPlace() async {
    final folder = AppFiles.placeOf(AppFiles.join(await AppFiles.outputDir(), 'x.pdf'));
    if (!mounted) return null;
    return askScanNameAndPlace(context, folder);
  }

  Future<void> _createPdf() async {
    if (_pages.isEmpty) return;
    final choice = await _askNameAndPlace();
    if (choice == null || !mounted) return;
    setState(() { _isProcessing = true; _status = tr('Preparing...'); });

    try {
      var paths = _pages.map((p) => p.path).toList();

      if (_prodfosHandlesColor) {
        final enhanced = <String>[];
        for (int i = 0; i < paths.length; i++) {
          setState(() => _status = tr('Enhancing {i}/{n}...', {'i': i + 1, 'n': paths.length}));
          final src = await AppFiles.readBytes(paths[i]);
          final out = await compute(enhanceImageBytes, <String, Object>{
            'bytes': src,
            'mode': _filter,
          });
          enhanced.add(await AppFiles.fromBytes(out, 'prodfos_enh_$i.jpg'));
        }
        paths = enhanced;
      }

      // Lay the pages out for this kind of document (book pages, card at real size, receipt…).
      if (_type.layout != 'photo' || _type.flatten) {
        if (!mounted) return;
        setState(() => _status = tr('Laying out pages...'));
        final bytes = <Uint8List>[for (final p in paths) await AppFiles.readBytes(p)];
        final laid = await compute(layoutPages, <String, Object>{
          'bytes': bytes, 'layout': _type.layout,
          'split': _split, 'rtl': _rtl, 'shadow': _type.layout == 'book' ? _shadow : _type.flatten, 'cover': _cover,
          'cardW': _type.cardW, 'cardH': _type.cardH, 'sides': _type.sides, 'mark': _mark.text,
        });
        paths = [for (var i = 0; i < laid.length; i++) await AppFiles.fromBytes(laid[i], 'prodfos_page_$i.jpg')];
      }

      if (!mounted) return;
      setState(() => _status = tr('Building PDF...'));
      final pdfService = context.read<PdfService>();
      final result = await pdfService.imagesToPdf(paths,
          paper: _type.isCard ? 'a4' : _type.layout == 'receipt' ? 'image' : 'letter', name: choice.name);
      String? copy;
      if (choice.elsewhere) {
        setState(() => _status = tr('Saving a copy...'));
        try { copy = await AppFiles.saveCopyAs(result.outputPath, result.fileName); } catch (_) { copy = null; }
      }

      if (!mounted) return;
      setState(() { _isProcessing = false; _status = ''; });
      _showSuccessDialog(result, copy: copy, askedCopy: choice.elsewhere);
    } catch (e) {
      if (!mounted) return;
      setState(() { _isProcessing = false; _status = ''; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Failed: {e}', {'e': e}))));
      }
    }
  }

  void _showSuccessDialog(PdfResult result, {String? copy, bool askedCopy = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Row(children: [
          Icon(Icons.check_circle, color: Colors.green, size: 24),
          SizedBox(width: 8),
          Text(tr('Scan Complete')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('{n} page(s) scanned', {'n': _pages.length})),
            Text(tr('File: {name}', {'name': result.fileName}), key: const Key('scan-done-name'), style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(tr('Size: {size}', {'size': result.fileSizeFormatted})),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.folder_rounded, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(tr('Saved in: {place}', {'place': AppFiles.placeOf(result.outputPath)}), key: const Key('scan-done-place'))),
            ]),
            if (!AppFiles.isWeb)
              Padding(padding: const EdgeInsets.only(left: 24, top: 2),
                child: SelectableText(result.outputPath, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12))),
            if (askedCopy) ...[
              const SizedBox(height: 6),
              Text(copy != null ? tr('A copy was also saved where you chose.') : tr('No copy elsewhere: the choice was cancelled.'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
            ],
            const SizedBox(height: 6),
            Text(tr('Also in ProDFOS: Tools → Created files.'), style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: Text(tr('Done')),
          ),
          TextButton.icon(
            onPressed: () { Navigator.pop(ctx); AppFiles.share(result.outputPath); },
            icon: Icon(AppFiles.isWeb ? Icons.download_rounded : Icons.share, size: 18),
            label: Text(AppFiles.isWeb ? tr('Download') : tr('Share')),
          ),
          FilledButton.icon(
            onPressed: () { Navigator.pop(ctx); AppFiles.open(result.outputPath); },
            icon: const Icon(Icons.open_in_new, size: 18), label: Text(tr('Open')),
          ),
        ],
      ),
    );
  }

  void _renumberPages() {
    for (int i = 0; i < _pages.length; i++) {
      _pages[i] = _ScanPage(path: _pages[i].path, name: tr('Page {n}', {'n': i + 1}));
    }
  }

  // ── UI ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Scan to PDF')),
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
                label: Text(_isProcessing ? _status : tr('Create PDF')),
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
                Text(tr('{n} page(s)', {'n': _pages.length}), style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _isProcessing ? null : () => setState(() => _pages.clear()),
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: Text(tr('Clear All'), style: TextStyle(color: Colors.red, fontSize: 12)),
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
            // Short screens (a phone sideways): the panel scrolls instead of overflowing.
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.62),
            child: SingleChildScrollView(child: Column(children: [
              _typePicker(),
              _typeOptions(),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _filterChip('original', tr('Original'), Icons.image_rounded)),
                const SizedBox(width: 6),
                Expanded(child: _filterChip('natural', tr('Natural'), Icons.wb_sunny_outlined)),
                const SizedBox(width: 6),
                Expanded(child: _filterChip('bright', tr('Bright'), Icons.auto_fix_high_rounded)),
                const SizedBox(width: 6),
                Expanded(child: _filterChip('bw', 'B&W', Icons.contrast_rounded)),
              ]),
              const SizedBox(height: 8),
              Text(
                !_hasSmartScanner
                    ? (_prodfosHandlesColor ? tr('ProDFOS enhances every page') : tr('Pages kept exactly as captured'))
                    : _prodfosHandlesColor
                        ? tr('Google auto-enhance off · ProDFOS handles color')
                        : tr('Google scanner tools enabled · no ProDFOS processing'),
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35)),
              ),
              const SizedBox(height: 12),
              if (_hasSmartScanner) SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _scanWithMLKit,
                  icon: const Icon(Icons.document_scanner_rounded, size: 20),
                  label: Text(tr('Smart Scan')),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (_hasSmartScanner) const SizedBox(height: 10),
              Row(children: [
                if (_hasCamera) Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _captureBasic,
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: Text(_nextSide.isEmpty ? (_type.layout == 'book' ? tr('Page after page') : tr('Quick Photo')) : _nextSide, overflow: TextOverflow.ellipsis),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppTheme.brandGold.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
                if (_hasCamera) const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _addFromGallery,
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: Text(_hasCamera ? tr('Gallery') : tr('Add images')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppTheme.brandGold.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ]),
            ])),
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

  String _typeHint() {
    switch (_type.layout) {
      case 'book': return tr('Open the book flat. Each photo of two pages becomes two pages, in reading order, without the binding shadow. The camera opens again for the next page.');
      case 'card': return _type.sides == 2
          ? tr('Scan the front, then the back. Both come out at real size on one A4 sheet, ready to print.')
          : tr('Scan the page with the photo. It comes out at real size on one A4 sheet, ready to print.');
      case 'receipt': return tr('Lay the receipt flat on a dark table. It keeps its long shape.');
      case 'board': return tr('Stand in front of the board. The light is made even and the marker stays sharp.');
      case 'photo': return tr('The picture is kept as it is, colours included.');
      default: return tr('Pick a look below, then scan.\nNatural keeps the real paper tone and watermarks.');
    }
  }

  /// The kinds of document, in a row you can scroll (like pro scanner apps).
  Widget _typePicker() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        key: const ValueKey('scan-types'),
        scrollDirection: Axis.horizontal,
        itemCount: scanTypes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final t = scanTypes[i];
          final on = t.id == _type.id;
          return ChoiceChip(
            key: ValueKey('scan-type-${t.id}'),
            selected: on,
            showCheckmark: false,
            avatar: Icon(t.icon, size: 16, color: on ? AppTheme.brandGold : Colors.white.withValues(alpha: 0.55)),
            label: Text(tr(t.label)),
            labelStyle: TextStyle(fontSize: 12.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? AppTheme.brandGold : Colors.white.withValues(alpha: 0.75)),
            selectedColor: AppTheme.brandGold.withValues(alpha: 0.15),
            backgroundColor: AppTheme.darkCard,
            side: BorderSide(color: on ? AppTheme.brandGold : AppTheme.darkBorder),
            onSelected: _isProcessing ? null : (_) => _pickType(t),
          );
        },
      ),
    );
  }

  /// Book and card settings.
  Widget _typeOptions() {
    Widget sw(String label, bool v, ValueChanged<bool> f) => FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: v, onSelected: _isProcessing ? null : (x) => setState(() => f(x)),
      selectedColor: AppTheme.brandGold.withValues(alpha: 0.15), backgroundColor: AppTheme.darkCard,
      side: BorderSide(color: v ? AppTheme.brandGold : AppTheme.darkBorder), visualDensity: VisualDensity.compact,
    );
    if (_type.layout == 'book') {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(spacing: 6, runSpacing: 4, children: [
          sw(tr('Split double pages'), _split, (x) => _split = x),
          sw(tr('Remove binding shadow'), _shadow, (x) => _shadow = x),
          sw(tr('Keep the cover whole'), _cover, (x) => _cover = x),
          sw(tr('Right to left (Arabic, manga)'), _rtl, (x) => _rtl = x),
        ]),
      );
    }
    if (_type.isCard) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextField(
          key: const ValueKey('scan-mark'),
          controller: _mark,
          enabled: !_isProcessing,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.water_drop_outlined, size: 18),
            labelText: tr('Watermark (optional)'),
            hintText: tr('Copy for … only – date'),
            border: const OutlineInputBorder(),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
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
          Text(tr('Smart Document Scanner'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            _typeHint(),
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
            Image(image: ResizeImage(AppFiles.image(page.path), width: 240),
              width: 80, height: 100, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(width: 80, height: 100, color: AppTheme.darkBg,
                child: const Icon(Icons.broken_image, size: 24))),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(page.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_type.isCard && _type.sides == 2 ? (i.isEven ? tr('Front side') : tr('Back side§card')) : tr('Drag to reorder'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
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

/// Before saving: the file's name (editable) and where it goes.
Future<({String name, bool elsewhere})?> askScanNameAndPlace(BuildContext context, String folder) =>
    showDialog<({String name, bool elsewhere})>(context: context, builder: (_) => _ScanSaveDialog(folder: folder));

class _ScanSaveDialog extends StatefulWidget {
  const _ScanSaveDialog({required this.folder});
  final String folder;
  @override
  State<_ScanSaveDialog> createState() => _ScanSaveDialogState();
}

class _ScanSaveDialogState extends State<_ScanSaveDialog> {
  final _name = TextEditingController(text: PdfService.defaultScanName());
  bool _elsewhere = false;

  @override
  void initState() {
    super.initState();
    _name.selection = TextSelection(baseOffset: 0, extentOffset: _name.text.length);
  }

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  void _save() => Navigator.pop(context, (name: _name.text, elsewhere: _elsewhere));

  @override
  Widget build(BuildContext context) => AlertDialog(
    // Phones held sideways are only about 390 px high: the whole dialog scrolls, never the choices alone.
    scrollable: true,
    title: Text(tr('Save the scan')),
    content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        key: const Key('scan-name'), controller: _name, autofocus: true,
        decoration: InputDecoration(labelText: tr('File name'), suffixText: '.pdf', prefixIcon: const Icon(Icons.picture_as_pdf_rounded)),
        onSubmitted: (_) => _save(),
      ),
      const SizedBox(height: 16),
      Text(tr('Where'), style: const TextStyle(fontWeight: FontWeight.w600)),
      RadioGroup<bool>(
        groupValue: _elsewhere,
        onChanged: (v) => setState(() => _elsewhere = v ?? false),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          RadioListTile<bool>(
            key: const Key('scan-place-prodfos'), value: false, contentPadding: EdgeInsets.zero,
            title: Text(tr('ProDFOS folder')), subtitle: Text(widget.folder),
          ),
          if (AppFiles.canChoosePlace)
            RadioListTile<bool>(
              key: const Key('scan-place-other'), value: true, contentPadding: EdgeInsets.zero,
              title: Text(AppFiles.isWeb ? tr('Also download a copy') : tr('Also save a copy elsewhere…')),
              subtitle: Text(AppFiles.isWeb ? tr('Your browser saves it in Downloads') : tr('Any folder, SD card or Drive')),
            ),
        ]),
      ),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
      FilledButton.icon(key: const Key('scan-save'), onPressed: _save, icon: const Icon(Icons.save_rounded, size: 18), label: Text(tr('Save'))),
    ],
  );
}
