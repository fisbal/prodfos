import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/pdf_service.dart';

class ImagesToPdfScreen extends StatefulWidget {
  const ImagesToPdfScreen({super.key});
  @override
  State<ImagesToPdfScreen> createState() => _ImagesToPdfScreenState();
}

class _ImagesToPdfScreenState extends State<ImagesToPdfScreen> {
  final List<_ImageEntry> _images = [];
  bool _isProcessing = false;

  Future<void> _addImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      for (final f in result.files) {
        if (f.path != null) {
          _images.add(_ImageEntry(path: f.path!, name: f.name, size: f.size));
        }
      }
    });
  }

  Future<void> _convert() async {
    if (_images.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      final paths = _images.map((i) => i.path).toList();
      final result = await context.read<PdfService>().imagesToPdf(paths);
      setState(() => _isProcessing = false);
      if (mounted) _showSuccessDialog(result);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversion failed: $e')),
        );
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
          Text('PDF Created'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_images.length} image(s) converted'),
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
        title: const Text('Images to PDF'),
        actions: [
          if (_images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : _convert,
                icon: _isProcessing
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(_isProcessing ? 'Converting...' : 'Create PDF'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _images.isEmpty
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, size: 56,
                        color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 12),
                      Text('No images added yet',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                    ],
                  ))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _images.length,
                    onReorder: (old, nw) {
                      setState(() {
                        if (nw > old) nw--;
                        final item = _images.removeAt(old);
                        _images.insert(nw, item);
                      });
                    },
                    itemBuilder: (_, i) {
                      final img = _images[i];
                      return Card(
                        key: ValueKey('${img.path}_$i'),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(img.path),
                              width: 48, height: 48, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 48, height: 48,
                                color: AppTheme.darkBg,
                                child: const Icon(Icons.broken_image, size: 20),
                              ),
                            ),
                          ),
                          title: Text(img.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14)),
                          subtitle: Text('Page ${i + 1}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(() => _images.removeAt(i)),
                              ),
                              const Icon(Icons.drag_handle, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addImages,
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: const Text('Add Images'),
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

class _ImageEntry {
  final String path, name;
  final int size;
  _ImageEntry({required this.path, required this.name, required this.size});
}
