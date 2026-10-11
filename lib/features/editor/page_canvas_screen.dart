import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/pdf_edit_service.dart';
import 'signature_pad_sheet.dart';

enum CanvasTool { pen, marker, text, image, stamp, signature, note, replace }

/// Opens one page as a live canvas. Returns new PDF bytes on Apply, or null.
class PageCanvasScreen extends StatefulWidget {
  final Uint8List bytes;
  final int pageIndex;
  final CanvasTool initialTool;

  const PageCanvasScreen({
    super.key,
    required this.bytes,
    required this.pageIndex,
    this.initialTool = CanvasTool.pen,
  });

  @override
  State<PageCanvasScreen> createState() => _PageCanvasScreenState();
}

class _PageCanvasScreenState extends State<PageCanvasScreen> {
  Uint8List? _png;
  Size? _pageSize;
  bool _loading = true;
  bool _applying = false;
  String? _error;

  final List<PenStroke> _strokes = [];
  final List<EditItem> _items = [];
  final List<Object> _history = [];
  PenStroke? _current;
  int? _selected;

  late CanvasTool _tool;
  Color _penColor = Colors.black;
  double _penWidth = 2.0;
  Color _markerColor = const Color(0xFFFFEB3B);
  double _scale = 1.0;

  static const _gold = AppTheme.brandGold;

  bool get _isDrawTool => _tool == CanvasTool.pen || _tool == CanvasTool.marker;

  @override
  void initState() {
    super.initState();
    _tool = widget.initialTool;
    _load();
  }

  Future<void> _load() async {
    try {
      final info = PdfEditService.pageInfo(widget.bytes, widget.pageIndex);
      if (info.rotated) {
        setState(() {
          _loading = false;
          _error = 'This page is rotated.\nOpen Pages and turn it upright before editing it.';
        });
        return;
      }
      Uint8List? png;
      await for (final r in Printing.raster(widget.bytes, pages: [widget.pageIndex], dpi: 110)) {
        png = await r.toPng();
      }
      setState(() { _png = png; _pageSize = info.size; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = 'Could not open this page:\n$e'; });
    }
  }

  // ── History ──────────────────────────────────────────────
  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      final last = _history.removeLast();
      if (last is PenStroke) _strokes.remove(last);
      if (last is EditItem) _items.remove(last);
      _selected = null;
    });
  }

  void _addItem(EditItem it) {
    setState(() {
      _items.add(it);
      _history.add(it);
      _selected = _items.length - 1;
    });
  }

  // ── Apply ────────────────────────────────────────────────
  Future<void> _apply() async {
    if (_strokes.isEmpty && _items.isEmpty) { Navigator.pop(context); return; }
    setState(() => _applying = true);
    try {
      final out = await PdfEditService.applyPageEdits(
          widget.bytes, widget.pageIndex, _strokes, _items);
      if (mounted) Navigator.pop(context, out);
    } catch (e) {
      setState(() => _applying = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Apply failed: $e')));
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_strokes.isEmpty && _items.isEmpty) return true;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits on this page will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    return r ?? false;
  }

  // ── Taps on the page ─────────────────────────────────────
  Future<void> _onPageTap(Offset p) async {
    if (_selected != null) { setState(() => _selected = null); return; }
    switch (_tool) {
      case CanvasTool.pen:
      case CanvasTool.marker:
        return;
      case CanvasTool.text:
        final r = await _textDialog();
        if (r == null) return;
        final s = _measure(r.text, r.size);
        _addItem(EditItem(type: EditItemType.text, position: p, size: s,
            text: r.text, fontSize: r.size, color: r.color));
        return;
      case CanvasTool.image:
        final x = await ImagePicker().pickImage(source: ImageSource.gallery, requestFullMetadata: false);
        if (x == null) return;
        final bytes = await x.readAsBytes();
        final dims = await decodeImageFromList(bytes);
        const w = 180.0;
        final h = w * dims.height / dims.width;
        _addItem(EditItem(type: EditItemType.image,
            position: p - Offset(w / 2, h / 2), size: Size(w, h), imageBytes: bytes));
        return;
      case CanvasTool.stamp:
        final s = await _stampPicker();
        if (s == null) return;
        const fs = 16.0;
        final w = s.label.length * fs * 0.68 + 28;
        const h = fs + 20;
        _addItem(EditItem(type: EditItemType.stamp,
            position: p - Offset(w / 2, h / 2), size: Size(w, h),
            text: s.label, fontSize: fs, color: s.color));
        return;
      case CanvasTool.signature:
        final png = await SignaturePadSheet.show(context);
        if (png == null) return;
        final dims = await decodeImageFromList(png);
        const w = 170.0;
        final h = w * dims.height / dims.width;
        _addItem(EditItem(type: EditItemType.signature,
            position: p - Offset(w / 2, h / 2), size: Size(w, h), imageBytes: png));
        return;
      case CanvasTool.note:
        final t = await _noteDialog();
        if (t == null || t.trim().isEmpty) return;
        _addItem(EditItem(type: EditItemType.note, position: p, size: const Size(22, 22), text: t));
        return;
      case CanvasTool.replace:
        final hit = PdfEditService.findLineAt(widget.bytes, widget.pageIndex, p);
        if (hit == null) {
          _snack('No text found here — tap directly on a line of text.');
          return;
        }
        final newText = await _replaceDialog(hit.text);
        if (newText == null) return;
        final m = _measure(newText, hit.fontSize, family: hit.fontFamily, bold: hit.bold);
        _addItem(EditItem(
          type: EditItemType.replace,
          position: hit.bounds.topLeft,
          size: Size(math.max(hit.bounds.width, m.width), hit.bounds.height),
          text: newText, fontSize: hit.fontSize, coverRect: hit.bounds,
          fontFamily: hit.fontFamily, bold: hit.bold,
        ));
        return;
    }
  }

  // ── Selected item actions ────────────────────────────────
  void _resizeSelected(double f) {
    final i = _selected;
    if (i == null) return;
    final it = _items[i];
    if (it.type == EditItemType.replace || it.type == EditItemType.note) return;
    setState(() {
      final c = it.position + Offset(it.size.width / 2, it.size.height / 2);
      it.size = Size(it.size.width * f, it.size.height * f);
      if (it.type == EditItemType.text || it.type == EditItemType.stamp) it.fontSize *= f;
      it.position = c - Offset(it.size.width / 2, it.size.height / 2);
    });
  }

  void _deleteSelected() {
    final i = _selected;
    if (i == null) return;
    setState(() {
      final it = _items.removeAt(i);
      _history.remove(it);
      _selected = null;
    });
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
        if (await _confirmDiscard() && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B10),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (await _confirmDiscard() && mounted) Navigator.pop(context);
            },
          ),
          title: Text('Page ${widget.pageIndex + 1}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              onPressed: _history.isEmpty || _applying ? null : _undo,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilledButton.icon(
                onPressed: _applying || _loading || _error != null ? null : _apply,
                icon: _applying
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.check_rounded, size: 18),
                label: const Text('Apply'),
              ),
            ),
          ],
        ),
        body: Column(children: [
          Expanded(child: _buildStage()),
          if (_selected != null) _selectionBar() else if (_isDrawTool) _drawOptions(),
          _hint(),
          _toolBar(),
        ]),
      ),
    );
  }

  Widget _buildStage() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(_error!, textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), height: 1.5)),
      ));
    }
    return LayoutBuilder(builder: (ctx, c) {
      final ps = _pageSize!;
      final aspect = ps.height / ps.width;
      double w = c.maxWidth - 24;
      double h = w * aspect;
      if (h > c.maxHeight - 24) { h = c.maxHeight - 24; w = h / aspect; }
      _scale = w / ps.width;

      return Center(
        child: Container(
          width: w, height: h,
          decoration: BoxDecoration(boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 8)),
          ]),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onPageTap(d.localPosition / _scale),
            onPanStart: _isDrawTool ? (d) => _strokeStart(d.localPosition / _scale) : null,
            onPanUpdate: _isDrawTool ? (d) => _strokeMove(d.localPosition / _scale) : null,
            onPanEnd: _isDrawTool ? (_) => _strokeEnd() : null,
            child: Stack(children: [
              Positioned.fill(child: Image.memory(_png!, fit: BoxFit.fill, gaplessPlayback: true)),
              Positioned.fill(child: IgnorePointer(
                child: CustomPaint(painter: _StrokePainter(_strokes, _current, _scale)),
              )),
              for (int i = 0; i < _items.length; i++) _buildItem(i),
            ]),
          ),
        ),
      );
    });
  }

  // ── Strokes ──────────────────────────────────────────────
  void _strokeStart(Offset p) {
    final marker = _tool == CanvasTool.marker;
    setState(() {
      _selected = null;
      _current = PenStroke(
        points: [p],
        color: marker ? _markerColor : _penColor,
        width: marker ? 12 : _penWidth,
        opacity: marker ? 0.35 : 1.0,
      );
    });
  }

  void _strokeMove(Offset p) {
    if (_current == null) return;
    setState(() => _current!.points.add(p));
  }

  void _strokeEnd() {
    final s = _current;
    if (s == null) return;
    setState(() {
      _strokes.add(s);
      _history.add(s);
      _current = null;
    });
  }

  // ── Items ────────────────────────────────────────────────
  Widget _buildItem(int i) {
    final it = _items[i];
    final sel = _selected == i;
    final s = _scale;

    Widget content;
    switch (it.type) {
      case EditItemType.text:
        content = Text(it.text, softWrap: false, overflow: TextOverflow.visible,
          style: TextStyle(fontSize: it.fontSize * s, color: it.color, height: 1.15,
              fontWeight: it.bold ? FontWeight.bold : FontWeight.normal));
        break;
      case EditItemType.image:
      case EditItemType.signature:
        content = Image.memory(it.imageBytes!, fit: BoxFit.fill, gaplessPlayback: true);
        break;
      case EditItemType.stamp:
        content = Transform.rotate(
          angle: -10 * math.pi / 180,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: it.color.withValues(alpha: 0.9), width: 2.5 * s)),
            padding: EdgeInsets.all(3 * s),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: it.color.withValues(alpha: 0.9), width: 0.8 * s)),
              alignment: Alignment.center,
              child: FittedBox(child: Text(it.text, style: TextStyle(
                color: it.color, fontWeight: FontWeight.w900, letterSpacing: 1,
                fontSize: it.fontSize * s))),
            ),
          ),
        );
        break;
      case EditItemType.note:
        content = Container(
          decoration: BoxDecoration(color: const Color(0xFFFFCA28),
            borderRadius: BorderRadius.circular(4 * s)),
          child: Icon(Icons.sticky_note_2_rounded, size: 16 * s, color: Colors.black87),
        );
        break;
      case EditItemType.replace:
        content = Container(
          color: Colors.white,
          alignment: Alignment.topLeft,
          child: Text(it.text, softWrap: false, overflow: TextOverflow.visible,
            style: TextStyle(
              fontSize: it.fontSize * s, color: it.color, height: 1.1,
              fontWeight: it.bold ? FontWeight.bold : FontWeight.normal,
              fontFamily: it.fontFamily == 'times' ? 'serif'
                  : it.fontFamily == 'courier' ? 'monospace' : null,
            )),
        );
        break;
    }

    return Positioned(
      left: it.position.dx * s,
      top: it.position.dy * s,
      width: it.size.width * s,
      height: it.size.height * s,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selected = sel ? null : i),
        onPanStart: (_) => setState(() => _selected = i),
        onPanUpdate: it.type == EditItemType.replace
            ? null
            : (d) => setState(() => it.position += d.delta / s),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: content),
          if (sel)
            Positioned.fill(child: IgnorePointer(child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: _gold, width: 1.5),
                color: _gold.withValues(alpha: 0.06),
              ),
            ))),
        ]),
      ),
    );
  }

  // ── Bars ─────────────────────────────────────────────────
  Widget _selectionBar() {
    final it = _items[_selected!];
    final resizable = it.type != EditItemType.replace && it.type != EditItemType.note;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.darkSurface,
      child: Row(children: [
        Icon(Icons.open_with_rounded, size: 18, color: _gold.withValues(alpha: 0.8)),
        const SizedBox(width: 8),
        Expanded(child: Text(
          it.type == EditItemType.replace ? 'Replacement text' : 'Drag to move',
          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)))),
        if (resizable) ...[
          _roundBtn(Icons.remove_rounded, () => _resizeSelected(0.87)),
          const SizedBox(width: 8),
          _roundBtn(Icons.add_rounded, () => _resizeSelected(1.15)),
          const SizedBox(width: 8),
        ],
        _roundBtn(Icons.delete_outline_rounded, _deleteSelected, color: Colors.redAccent),
        const SizedBox(width: 8),
        _roundBtn(Icons.check_rounded, () => setState(() => _selected = null), color: _gold),
      ]),
    );
  }

  Widget _drawOptions() {
    final marker = _tool == CanvasTool.marker;
    final colors = marker
        ? const [Color(0xFFFFEB3B), Color(0xFF69F0AE), Color(0xFFFF80AB), Color(0xFF40C4FF)]
        : const [Colors.black, Color(0xFF1A3A8F), Color(0xFFD32F2F), Color(0xFF2E7D32), AppTheme.brandGold];
    final current = marker ? _markerColor : _penColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppTheme.darkSurface,
      child: Row(children: [
        for (final c in colors)
          GestureDetector(
            onTap: () => setState(() => marker ? _markerColor = c : _penColor = c),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: c, shape: BoxShape.circle,
                border: Border.all(
                  color: current == c ? _gold : Colors.white24,
                  width: current == c ? 2.5 : 1),
              ),
            ),
          ),
        if (!marker) Expanded(
          child: Slider(
            value: _penWidth, min: 1, max: 8,
            activeColor: _gold,
            onChanged: (v) => setState(() => _penWidth = v),
          ),
        ),
      ]),
    );
  }

  Widget _hint() {
    const hints = {
      CanvasTool.pen: 'Draw with your finger',
      CanvasTool.marker: 'Swipe over text to highlight it',
      CanvasTool.text: 'Tap where the text should go',
      CanvasTool.image: 'Tap where the image should go',
      CanvasTool.stamp: 'Tap where the stamp should go',
      CanvasTool.signature: 'Tap where you want to sign',
      CanvasTool.note: 'Tap to pin a note',
      CanvasTool.replace: 'Tap a line of text to rewrite it',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(_error != null ? '' : hints[_tool]!,
        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
    );
  }

  Widget _toolBar() {
    const tools = [
      (CanvasTool.pen, Icons.edit_rounded, 'Pen'),
      (CanvasTool.marker, Icons.brush_rounded, 'Marker'),
      (CanvasTool.text, Icons.text_fields_rounded, 'Text'),
      (CanvasTool.image, Icons.image_rounded, 'Image'),
      (CanvasTool.stamp, Icons.approval_rounded, 'Stamp'),
      (CanvasTool.signature, Icons.draw_rounded, 'Sign'),
      (CanvasTool.note, Icons.sticky_note_2_rounded, 'Note'),
      (CanvasTool.replace, Icons.find_replace_rounded, 'Replace'),
    ];
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 74,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          children: [
            for (final t in tools)
              GestureDetector(
                onTap: () => setState(() { _tool = t.$1; _selected = null; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 66,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: _tool == t.$1 ? _gold.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _tool == t.$1 ? _gold : Colors.transparent, width: 1.2),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(t.$2, size: 22,
                      color: _tool == t.$1 ? _gold : Colors.white.withValues(alpha: 0.55)),
                    const SizedBox(height: 3),
                    Text(t.$3, style: TextStyle(fontSize: 11,
                      color: _tool == t.$1 ? _gold : Colors.white.withValues(alpha: 0.55),
                      fontWeight: _tool == t.$1 ? FontWeight.w700 : FontWeight.w500)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppTheme.darkCard, shape: BoxShape.circle,
          border: Border.all(color: AppTheme.darkBorder)),
        child: Icon(icon, size: 18, color: color ?? Colors.white70),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // DIALOGS
  // ══════════════════════════════════════════════════════════════════
  Future<({String text, double size, Color color})?> _textDialog() {
    final ctrl = TextEditingController();
    double size = 14;
    Color color = Colors.black;
    const sizes = [10.0, 12.0, 14.0, 18.0, 24.0, 32.0];
    const colors = [Colors.black, Color(0xFF1A3A8F), Color(0xFFD32F2F), Color(0xFF2E7D32)];

    return showDialog<({String text, double size, Color color})>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: const Text('Add Text'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctrl, autofocus: true, maxLines: 4, minLines: 1,
            decoration: const InputDecoration(hintText: 'Type your text…', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in sizes)
              ChoiceChip(label: Text('${s.toInt()}'), selected: size == s,
                onSelected: (_) => setD(() => size = s)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            for (final c in colors)
              GestureDetector(
                onTap: () => setD(() => color = c),
                child: Container(
                  margin: const EdgeInsets.only(right: 10), width: 28, height: 28,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                    border: Border.all(color: color == c ? _gold : Colors.white24,
                      width: color == c ? 2.5 : 1)),
                ),
              ),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, (text: ctrl.text, size: size, color: color));
            },
            child: const Text('Add'),
          ),
        ],
      )),
    );
  }

  Future<String?> _noteDialog() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sticky Note'),
        content: TextField(controller: ctrl, autofocus: true, maxLines: 5, minLines: 2,
          decoration: const InputDecoration(hintText: 'Write your note…', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Pin note')),
        ],
      ),
    );
  }

  Future<String?> _replaceDialog(String original) {
    final ctrl = TextEditingController(text: original);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace Text'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Original', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45))),
          const SizedBox(height: 4),
          Text(original, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
          const SizedBox(height: 14),
          TextField(controller: ctrl, autofocus: true, maxLines: 3, minLines: 1,
            decoration: const InputDecoration(labelText: 'New text', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Text('The original line is covered and your text is written in a matching font.',
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Replace')),
        ],
      ),
    );
  }

  Future<({String label, Color color})?> _stampPicker() {
    final today = DateTime.now();
    final date = '${today.day.toString().padLeft(2, '0')}/'
        '${today.month.toString().padLeft(2, '0')}/${today.year}';
    final stamps = [
      ('APPROVED', const Color(0xFF2E7D32)),
      ('PAID', const Color(0xFF1565C0)),
      ('RECEIVED', const Color(0xFF00838F)),
      ('CONFIDENTIAL', const Color(0xFFC62828)),
      ('REJECTED', const Color(0xFFC62828)),
      ('DRAFT', const Color(0xFF616161)),
      ('SIGNED $date', const Color(0xFF1A3A8F)),
      ('COPY', const Color(0xFF6A1B9A)),
    ];
    return showModalBottomSheet<({String label, Color color})>(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.darkBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          const Text('Choose a Stamp', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true, crossAxisCount: 2, childAspectRatio: 3.0,
            mainAxisSpacing: 10, crossAxisSpacing: 10,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final st in stamps)
                InkWell(
                  onTap: () => Navigator.pop(ctx, (label: st.$1, color: st.$2)),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Transform.rotate(angle: -6 * math.pi / 180, child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(border: Border.all(color: st.$2, width: 2)),
                      child: Text(st.$1, style: TextStyle(color: st.$2,
                        fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                    )),
                  ),
                ),
            ],
          ),
        ]),
      )),
    );
  }

  // ── Helpers ──────────────────────────────────────────────
  Size _measure(String text, double fontSize, {String family = 'helvetica', bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
        fontSize: fontSize, height: 1.15,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontFamily: family == 'times' ? 'serif' : family == 'courier' ? 'monospace' : null,
      )),
      textDirection: TextDirection.ltr,
    )..layout();
    return Size(tp.width + 4, tp.height + 2);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

class _StrokePainter extends CustomPainter {
  final List<PenStroke> strokes;
  final PenStroke? current;
  final double scale;
  _StrokePainter(this.strokes, this.current, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in [...strokes, if (current != null) current!]) {
      final paint = Paint()
        ..color = s.color.withValues(alpha: s.opacity)
        ..strokeWidth = s.width * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (s.points.length == 1) {
        canvas.drawCircle(s.points.first * scale, s.width * scale / 2,
            paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(s.points.first.dx * scale, s.points.first.dy * scale);
      for (final p in s.points.skip(1)) {
        path.lineTo(p.dx * scale, p.dy * scale);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) => true;
}
