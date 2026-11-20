import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:printing/printing.dart';
import '../../core/l10n/l10n.dart';
import '../../core/services/pdf_edit_service.dart';
import '../../core/services/print/print_plan.dart';
import '../../core/services/print/windows_print.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/scene3d.dart';

/// ProDFOS print panel (Windows): printer, pages, copies, manual two-sided,
/// order, and the printer's own preferences (paper, quality, two-sided).
/// Everything chosen here is kept for next time (Martin, 2026-11-20).
Future<void> showPrintPanel(
  BuildContext context, {
  required Uint8List bytes,
  required String name,
  required int pageCount,
  required int currentPage,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PrintPanel(bytes: bytes, name: name, pageCount: pageCount, currentPage: currentPage),
  );
}

class _PrintPanel extends StatefulWidget {
  final Uint8List bytes;
  final String name;
  final int pageCount;
  final int currentPage;
  const _PrintPanel({required this.bytes, required this.name, required this.pageCount, required this.currentPage});

  @override
  State<_PrintPanel> createState() => _PrintPanelState();
}

class _PrintPanelState extends State<_PrintPanel> {
  static Box get _box => Hive.box('settings');

  List<Printer> _printers = const [];
  Printer? _printer;
  bool _loadingPrinters = true;
  PrintPages _pages = PrintPages.all;
  final _range = TextEditingController();
  int _copies = _box.get('print.copies', defaultValue: 1) as int;
  bool _manualDuplex = _box.get('print.manualDuplex', defaultValue: false) as bool;
  bool _reverse = _box.get('print.reverse', defaultValue: false) as bool;
  bool _reverseBacks = _box.get('print.reverseBacks', defaultValue: true) as bool;
  bool _busy = false;
  String? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  @override
  void dispose() {
    _range.dispose();
    super.dispose();
  }

  Future<void> _loadPrinters() async {
    try {
      final list = await Printing.listPrinters();
      final usable = list.where((p) => p.isAvailable).toList();
      final saved = _box.get('print.printer') as String?;
      if (!mounted) return;
      setState(() {
        _printers = usable;
        _printer = usable.where((p) => p.name == saved).firstOrNull ??
            usable.where((p) => p.isDefault).firstOrNull ??
            usable.firstOrNull;
        _loadingPrinters = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  void _remember() {
    _box.putAll({
      if (_printer != null) 'print.printer': _printer!.name,
      'print.copies': _copies,
      'print.manualDuplex': _manualDuplex,
      'print.reverse': _reverse,
      'print.reverseBacks': _reverseBacks,
    });
  }

  PrintPlan get _plan => PrintPlan(
        pages: _pages,
        range: _range.text,
        copies: _copies,
        manualDuplex: _manualDuplex,
        reverse: _reverse,
        reverseBacks: _reverseBacks,
      );

  List<List<PageEntry>>? _jobs() {
    try {
      return planPrintJobs(_plan, pageCount: widget.pageCount, currentPage: widget.currentPage);
    } on FormatException {
      setState(() => _error = tr('Check the pages, for example 1-4, 7'));
      return null;
    }
  }

  Future<Uint8List> _build(List<PageEntry> entries) =>
      PdfEditService.rebuildPages([Uint8List.fromList(widget.bytes)], entries);

  Future<void> _send(Printer printer, Uint8List pdf, int total) async {
    try {
      await WindowsPrint.printPdf(
        printer: printer.name,
        name: widget.name,
        pdf: pdf,
        onPage: (n) {
          if (mounted) setState(() => _progress = tr('Page {n} of {total}', {'n': n, 'total': total}));
        },
      );
    } on MissingPluginException {
      // Older Windows runner: the printing package prints instead.
      await Printing.directPrintPdf(printer: printer, onLayout: (_) async => pdf, name: widget.name);
    }
  }

  Future<void> _print() async {
    final printer = _printer;
    final jobs = _jobs();
    if (printer == null || jobs == null) return;
    _remember();
    setState(() { _busy = true; _error = null; _progress = null; });
    try {
      for (var i = 0; i < jobs.length; i++) {
        if (i == 1) {
          final go = await _askFlip(jobs[0].length);
          if (go != true) break;
        }
        final pdf = await _build(jobs[i]);
        await _send(printer, pdf, jobs[i].length);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() { _busy = false; _progress = null; _error = tr('Printing failed: {e}', {'e': e}); });
    }
  }

  /// The printer's own window: paper, quality, two-sided… kept for this printer.
  Future<void> _preferences() async {
    final printer = _printer;
    if (printer == null) return;
    try {
      final saved = await WindowsPrint.editSettings(printer.name);
      if (saved && mounted) setState(() {});
    } on MissingPluginException {
      // Older Windows runner: Windows' own box.
      final jobs = _jobs();
      if (jobs == null) return;
      final pdf = await _build(jobs.first);
      if (mounted) Navigator.of(context).pop();
      await Printing.layoutPdf(onLayout: (_) async => pdf, name: widget.name);
    } catch (e) {
      if (mounted) setState(() => _error = tr('Printing failed: {e}', {'e': e}));
    }
  }

  Future<bool?> _askFlip(int sheets) => showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(tr('Fronts printed')),
          content: Text(tr(
              '{n} sheets are printed on one side. Wait until the printer stops, take the stack, turn it over and put it back in the paper tray as it came out, then tap Print the backs.',
              {'n': sheets})),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Print the backs'))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final rangeError = _pages == PrintPages.range &&
        _range.text.trim().isNotEmpty &&
        parsePageRange(_range.text, widget.pageCount) == null;
    final printer = _printer;
    final hasSettings = printer != null && WindowsPrint.savedSettings(printer.name) != null;
    return Dialog(
      backgroundColor: const Color(0xFF101016),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppTheme.brandGold.withValues(alpha: 0.25)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.print_rounded, color: AppTheme.brandGold),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('Print'), style: AppTheme.display(24))),
              Text(tr('{n} pages', {'n': widget.pageCount}), style: AppTheme.body(13, color: AppTheme.creamFaint)),
            ]),
            const SizedBox(height: 18),

            _label(tr('Printer')),
            if (_loadingPrinters)
              const LinearProgressIndicator(color: AppTheme.brandGold)
            else if (_printers.isEmpty)
              Text(tr('No printer found'), style: AppTheme.body(14, color: AppTheme.creamMuted))
            else ...[
              DropdownButtonFormField<String>(
                initialValue: printer?.url,
                isExpanded: true,
                dropdownColor: const Color(0xFF17171E),
                items: [
                  for (final p in _printers)
                    DropdownMenuItem(value: p.url, child: Text(p.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: _busy ? null : (url) => setState(() => _printer = _printers.firstWhere((p) => p.url == url)),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(
                  hasSettings
                      ? tr('Your printer settings are kept for this printer')
                      : tr('Paper, quality and two-sided: open the printer preferences once, ProDFOS keeps them'),
                  style: AppTheme.body(12.5, color: hasSettings ? AppTheme.brandGold : AppTheme.creamFaint))),
                TextButton.icon(
                  onPressed: _busy || printer == null ? null : _preferences,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(tr('Printer preferences…')),
                ),
              ]),
            ],
            const SizedBox(height: 14),

            _label(tr('Pages')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip(PrintPages.all, tr('All')),
              _chip(PrintPages.current, tr('Current page ({n})', {'n': widget.currentPage})),
              _chip(PrintPages.range, tr('Pages…')),
              _chip(PrintPages.odd, tr('Odd only')),
              _chip(PrintPages.even, tr('Even only')),
            ]),
            if (_pages == PrintPages.range) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _range,
                autofocus: true,
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  hintText: tr('for example 1-4, 7'),
                  errorText: rangeError ? tr('Check the pages, for example 1-4, 7') : null,
                ),
              ),
            ],
            const SizedBox(height: 18),

            _label(tr('Copies')),
            Row(children: [
              Key3D(icon: Icons.remove_rounded, size: 36,
                  onTap: _copies > 1 ? () => setState(() => _copies--) : null),
              SizedBox(width: 56, child: Text('$_copies', textAlign: TextAlign.center,
                  style: AppTheme.display(22, color: AppTheme.brandGold))),
              Key3D(icon: Icons.add_rounded, size: 36,
                  onTap: _copies < 99 ? () => setState(() => _copies++) : null),
            ]),
            const SizedBox(height: 10),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _manualDuplex,
              onChanged: (v) => setState(() => _manualDuplex = v),
              title: Text(tr('Two-sided (manual)')),
              subtitle: Text(tr('Prints the fronts, then asks you to turn the stack over for the backs'),
                  style: AppTheme.body(12.5, color: AppTheme.creamFaint)),
            ),
            if (_manualDuplex)
              SwitchListTile(
                contentPadding: const EdgeInsets.only(left: 16),
                value: _reverseBacks,
                onChanged: (v) => setState(() => _reverseBacks = v),
                title: Text(tr('Backs from the last sheet')),
                subtitle: Text(tr('Turn off if your backs come out in the wrong order'),
                    style: AppTheme.body(12.5, color: AppTheme.creamFaint)),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _reverse,
              onChanged: (v) => setState(() => _reverse = v),
              title: Text(tr('Reverse order')),
            ),
            Text(tr('Printed at actual size (100 %).'), style: AppTheme.body(12.5, color: AppTheme.creamFaint)),

            if (_progress != null) ...[
              const SizedBox(height: 10),
              Text(_progress!, style: AppTheme.body(13, color: AppTheme.brandGold)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 18),
            Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 10,
                children: [
              TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(tr('Cancel'))),
              Button3D(
                label: _busy ? tr('Printing…') : tr('Print'),
                icon: Icons.print_rounded,
                onTap: _busy || printer == null || rangeError ? null : _print,
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: AppTheme.body(11, weight: FontWeight.w700, color: AppTheme.brandGold, letterSpacing: 1.6)),
      );

  Widget _chip(PrintPages value, String label) =>
      Chip3D(label: label, selected: _pages == value, onTap: () => setState(() { _pages = value; _error = null; }));
}
