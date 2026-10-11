import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/pdf_edit_service.dart';

/// Returns rebuilt PDF bytes on Apply, or null.
class PageOrganizerScreen extends StatefulWidget {
  final Uint8List bytes;
  const PageOrganizerScreen({super.key, required this.bytes});

  @override
  State<PageOrganizerScreen> createState() => _PageOrganizerScreenState();
}

class _PageOrganizerScreenState extends State<PageOrganizerScreen> {
  final List<Uint8List> _sources = [];
  final List<List<Uint8List>> _thumbs = []; // [docIndex][pageIndex] → png
  final List<PageEntry> _entries = [];
  bool _loading = true;
  bool _applying = false;
  bool _changed = false;

  static const _gold = AppTheme.brandGold;

  @override
  void initState() {
    super.initState();
    _addSource(widget.bytes, appendPages: true).then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _addSource(Uint8List bytes, {required bool appendPages, int? insertAt}) async {
    final docIndex = _sources.length;
    _sources.add(bytes);
    final thumbs = <Uint8List>[];
    await for (final r in Printing.raster(bytes, dpi: 28)) {
      thumbs.add(await r.toPng());
    }
    _thumbs.add(thumbs);
    if (appendPages) {
      final newEntries = [
        for (int i = 0; i < thumbs.length; i++) PageEntry(docIndex: docIndex, pageIndex: i),
      ];
      setState(() {
        if (insertAt != null) {
          _entries.insertAll(insertAt, newEntries);
        } else {
          _entries.addAll(newEntries);
        }
      });
    }
  }

  // ── Actions ──────────────────────────────────────────────
  void _rotate(int i, int turns) => setState(() {
        _entries[i].extraTurns = (_entries[i].extraTurns + turns) % 4;
        _changed = true;
      });

  void _duplicate(int i) => setState(() {
        _entries.insert(i + 1, _entries[i].copy());
        _changed = true;
      });

  void _delete(int i) {
    if (_entries.length == 1) {
      _snack('A document needs at least one page.');
      return;
    }
    setState(() { _entries.removeAt(i); _changed = true; });
  }

  void _addBlank() => setState(() {
        _entries.add(PageEntry(docIndex: -1, pageIndex: 0));
        _changed = true;
      });

  Future<void> _insertPdf() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (r == null || r.files.first.bytes == null) return;
    setState(() => _loading = true);
    try {
      await _addSource(r.files.first.bytes!, appendPages: true);
      _changed = true;
      _snack('Added ${r.files.first.name}');
    } catch (e) {
      _snack('Could not read that PDF: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _apply() async {
    if (!_changed) { Navigator.pop(context); return; }
    setState(() => _applying = true);
    try {
      final out = await PdfEditService.rebuildPages(_sources, _entries);
      if (mounted) Navigator.pop(context, out);
    } catch (e) {
      setState(() => _applying = false);
      _snack('Failed: $e');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ── UI ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Organize Pages'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton.icon(
              onPressed: _applying || _loading ? null : _apply,
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: _gold.withValues(alpha: 0.08),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: _gold.withValues(alpha: 0.8)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '${_entries.length} pages · Drag to reorder. Organize pages before '
              'filling forms — reorganizing flattens form fields.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
            )),
          ]),
        ),
        Expanded(
          child: _loading && _entries.isEmpty
              ? const Center(child: CircularProgressIndicator(color: _gold))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: _entries.length,
                  onReorder: (o, n) => setState(() {
                    if (n > o) n--;
                    _entries.insert(n, _entries.removeAt(o));
                    _changed = true;
                  }),
                  itemBuilder: (_, i) => _tile(i),
                ),
        ),
        if (_loading && _entries.isNotEmpty)
          const LinearProgressIndicator(color: _gold),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _loading ? null : _addBlank,
                icon: const Icon(Icons.note_add_outlined, size: 18),
                label: const Text('Blank Page'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: _loading ? null : _insertPdf,
                icon: const Icon(Icons.library_add_outlined, size: 18),
                label: const Text('Insert PDF'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
              )),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _tile(int i) {
    final e = _entries[i];
    Widget thumb;
    if (e.isBlank) {
      thumb = Container(color: Colors.white);
    } else {
      thumb = Image.memory(_thumbs[e.docIndex][e.pageIndex], fit: BoxFit.contain, gaplessPlayback: true);
    }

    return Container(
      key: ObjectKey(e),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          SizedBox(
            width: 64, height: 84,
            child: Center(child: RotatedBox(
              quarterTurns: e.extraTurns,
              child: Container(
                decoration: BoxDecoration(boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 6),
                ]),
                child: thumb,
              ),
            )),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Page ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 3),
            Text(
              e.isBlank ? 'Blank page'
                  : e.docIndex > 0 ? 'Inserted · p.${e.pageIndex + 1}'
                  : 'Original p.${e.pageIndex + 1}${e.extraTurns != 0 ? ' · rotated' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              _iconBtn(Icons.rotate_left_rounded, () => _rotate(i, 3)),
              _iconBtn(Icons.rotate_right_rounded, () => _rotate(i, 1)),
              _iconBtn(Icons.copy_rounded, () => _duplicate(i)),
              _iconBtn(Icons.delete_outline_rounded, () => _delete(i), color: Colors.redAccent),
            ]),
          ])),
          const Icon(Icons.drag_handle_rounded, color: Colors.white38),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 20, color: color ?? Colors.white70),
      ),
    );
  }
}
