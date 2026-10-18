import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/platform/app_files.dart';
import '../../core/services/pdf_service.dart';

class TextToPdfScreen extends StatefulWidget {
  const TextToPdfScreen({super.key});
  @override
  State<TextToPdfScreen> createState() => _TextToPdfScreenState();
}

class _TextToPdfScreenState extends State<TextToPdfScreen> {
  final _titleController = TextEditingController(text: 'My Document');
  final _textController = TextEditingController();
  bool _isProcessing = false;

  Future<void> _convert() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter some text first')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final result = await context.read<PdfService>().textToPdf(
        _textController.text,
        title: _titleController.text.trim().isEmpty ? 'Document' : _titleController.text.trim(),
      );
      setState(() => _isProcessing = false);
      if (mounted) {
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
                Text('File: ${result.fileName}'),
                Text('Size: ${result.fileSizeFormatted}'),
                const SizedBox(height: 8),
                Text(AppFiles.isWeb ? 'Kept in this browser (Tools → Created files)' : 'Saved to: ProDFOS folder',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
              TextButton.icon(
                onPressed: () { Navigator.pop(ctx); AppFiles.share(result.outputPath); },
                icon: Icon(AppFiles.isWeb ? Icons.download_rounded : Icons.share, size: 18), label: Text(AppFiles.isWeb ? 'Download' : 'Share'),
              ),
              FilledButton.icon(
                onPressed: () { Navigator.pop(ctx); AppFiles.open(result.outputPath); },
                icon: const Icon(Icons.open_in_new, size: 18), label: const Text('Open'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text to PDF'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _isProcessing ? null : _convert,
              icon: _isProcessing
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: Text(_isProcessing ? 'Creating...' : 'Create PDF'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Document Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Type or paste your text here...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }
}
