import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/pdf_service.dart';

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});
  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  String? _filePath;
  String? _fileName;
  int _totalPages = 0;
  final Set<int> _selectedPages = {};
  bool _isProcessing = false;
  final _rangeController = TextEditingController();
  String _mode = 'pick'; // pick | range

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.first.path == null) return;

    setState(() => _isProcessing = true);
    try {
      final path = result.files.first.path!;
      final count = await context.read<PdfService>().getPageCount(path);
      setState(() {
        _filePath = path;
        _fileName = result.files.first.name;
        _totalPages = count;
        _selectedPages.clear();
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e')),
        );
      }
    }
  }

  List<int> _getSelectedPages() {
    if (_mode == 'range') {
      return _parseRange(_rangeController.text, _totalPages);
    }
    return _selectedPages.toList()..sort();
  }

  List<int> _parseRange(String input, int max) {
    final pages = <int>{};
    for (final part in input.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
      if (part.contains('-')) {
        final bounds = part.split('-');
        if (bounds.length != 2) continue;
        final start = int.tryParse(bounds[0].trim());
        final end = int.tryParse(bounds[1].trim());
        if (start == null || end == null) continue;
        for (int i = start; i <= end && i <= max; i++) {
          if (i >= 1) pages.add(i);
        }
      } else {
        final p = int.tryParse(part);
        if (p != null && p >= 1 && p <= max) pages.add(p);
      }
    }
    return pages.toList()..sort();
  }

  Future<void> _split() async {
    final pages = _getSelectedPages();
    if (pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one page')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final result = await context.read<PdfService>().splitPdf(_filePath!, pages);
      setState(() => _isProcessing = false);
      if (mounted) _showSuccessDialog(result, pages.length);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Split failed: $e')),
        );
      }
    }
  }

  void _showSuccessDialog(PdfResult result, int pageCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Split Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Extracted $pageCount page(s)'),
            Text('File: ${result.fileName}'),
            Text('Size: ${result.fileSizeFormatted}'),
            const SizedBox(height: 8),
            Text('Saved to: ProDFOS folder in Downloads',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split PDF'),
        actions: [
          if (_filePath != null && _getSelectedPages().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : _split,
                icon: _isProcessing
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.content_cut_rounded, size: 18),
                label: Text(_isProcessing ? 'Splitting...' : 'Extract ${_getSelectedPages().length} pages'),
              ),
            ),
        ],
      ),
      body: _filePath == null ? _buildPickState() : _buildPageSelector(),
    );
  }

  Widget _buildPickState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.content_cut_rounded, size: 56, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text('Select a PDF to split', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isProcessing ? null : _pickFile,
            icon: const Icon(Icons.file_open_rounded, size: 18),
            label: const Text('Choose PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildPageSelector() {
    return Column(
      children: [
        // File info
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.darkCard, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: AppTheme.brandGold.withValues(alpha: 0.6)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_fileName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('$_totalPages pages', style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
                  ],
                ),
              ),
              TextButton(onPressed: _pickFile, child: const Text('Change')),
            ],
          ),
        ),

        // Mode tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _modeChip('Pick Pages', 'pick'),
              const SizedBox(width: 8),
              _modeChip('Page Range', 'range'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Selector
        Expanded(
          child: _mode == 'pick' ? _buildPageGrid() : _buildRangeInput(),
        ),
      ],
    );
  }

  Widget _modeChip(String label, String value) {
    final selected = _mode == value;
    return GestureDetector(
      onTap: () => setState(() => _mode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brandGold.withValues(alpha: 0.15) : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.brandGold.withValues(alpha: 0.5) : AppTheme.darkBorder,
          ),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? AppTheme.brandGold : Colors.white.withValues(alpha: 0.5),
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        )),
      ),
    );
  }

  Widget _buildPageGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8,
      ),
      itemCount: _totalPages,
      itemBuilder: (_, i) {
        final page = i + 1;
        final selected = _selectedPages.contains(page);
        return GestureDetector(
          onTap: () => setState(() {
            if (selected) { _selectedPages.remove(page); }
            else { _selectedPages.add(page); }
          }),
          child: Container(
            decoration: BoxDecoration(
              color: selected ? AppTheme.brandGold.withValues(alpha: 0.2) : AppTheme.darkCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppTheme.brandGold : AppTheme.darkBorder,
                width: selected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text('$page', style: TextStyle(
                color: selected ? AppTheme.brandGold : Colors.white.withValues(alpha: 0.5),
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              )),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRangeInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _rangeController,
            decoration: const InputDecoration(
              hintText: 'e.g. 1-3, 5, 8-10',
              labelText: 'Page range',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            'Use commas for individual pages, dashes for ranges.\nExample: 1-3, 5, 8-10 extracts pages 1, 2, 3, 5, 8, 9, 10',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
          ),
          if (_rangeController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Will extract: ${_parseRange(_rangeController.text, _totalPages).join(", ")}',
              style: TextStyle(color: AppTheme.brandGold.withValues(alpha: 0.7), fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }
}
