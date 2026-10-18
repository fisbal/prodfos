import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/platform/app_files.dart';
import '../../core/services/pdf_service.dart';

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});
  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<_FileEntry> _files = [];
  bool _isProcessing = false;

  Future<void> _addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
      withData: AppFiles.pickWithData,
    );
    if (result == null) return;
    final added = <_FileEntry>[];
    for (final f in result.files) {
      final path = await AppFiles.fromPicked(f);
      if (path != null) added.add(_FileEntry(path: path, name: f.name, size: f.size));
    }
    if (mounted) setState(() => _files.addAll(added));
  }

  Future<void> _merge() async {
    if (_files.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 PDFs to merge')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final pdfService = context.read<PdfService>();
      final paths = _files.map((f) => f.path).toList();
      final result = await pdfService.mergePdfs(paths);

      setState(() => _isProcessing = false);

      if (mounted) _showSuccessDialog(result);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merge failed: $e')),
        );
      }
    }
  }

  void _showSuccessDialog(PdfResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Merge Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: ${result.fileName}'),
            Text('Size: ${result.fileSizeFormatted}'),
            const SizedBox(height: 8),
            Text(
              AppFiles.isWeb ? 'Kept in this browser (Tools → Created files)' : 'Saved to: ProDFOS folder',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              AppFiles.share(result.outputPath);
            },
            icon: Icon(AppFiles.isWeb ? Icons.download_rounded : Icons.share, size: 18),
            label: Text(AppFiles.isWeb ? 'Download' : 'Share'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              AppFiles.open(result.outputPath);
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open'),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge PDFs'),
        actions: [
          if (_files.length >= 2)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : _merge,
                icon: _isProcessing
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.call_merge_rounded, size: 18),
                label: Text(_isProcessing ? 'Merging...' : 'Merge'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Info bar
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.brandGold.withValues(alpha: 0.6), size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Add PDFs and drag to reorder. They will be combined in the order shown.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // File list
          Expanded(
            child: _files.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.note_add_rounded, size: 56,
                          color: Colors.white.withValues(alpha: 0.15)),
                        const SizedBox(height: 12),
                        Text('No files added yet',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _files.length,
                    onReorder: (old, nw) {
                      setState(() {
                        if (nw > old) nw--;
                        final item = _files.removeAt(old);
                        _files.insert(nw, item);
                      });
                    },
                    itemBuilder: (_, i) {
                      final f = _files[i];
                      return Card(
                        key: ValueKey('${f.path}_$i'),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.brandGold.withValues(alpha: 0.15),
                            child: Text('${i + 1}', style: TextStyle(
                              color: AppTheme.brandGold, fontWeight: FontWeight.w700)),
                          ),
                          title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14)),
                          subtitle: Text(_formatSize(f.size),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(() => _files.removeAt(i)),
                              ),
                              const Icon(Icons.drag_handle, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Add button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addFiles,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add PDF Files'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppTheme.brandGold.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileEntry {
  final String path;
  final String name;
  final int size;
  _FileEntry({required this.path, required this.name, required this.size});
}
