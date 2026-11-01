import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/platform/app_files.dart';
import '../../core/services/pdf_service.dart';
import '../../core/l10n/l10n.dart';

class TextToPdfScreen extends StatefulWidget {
  const TextToPdfScreen({super.key});
  @override
  State<TextToPdfScreen> createState() => _TextToPdfScreenState();
}

class _TextToPdfScreenState extends State<TextToPdfScreen> {
  final _titleController = TextEditingController(text: tr('My Document'));
  final _textController = TextEditingController();
  bool _isProcessing = false;

  Future<void> _convert() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Enter some text first'))),
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
            title: Row(children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text(tr('PDF Created')),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('File: {name}', {'name': result.fileName})),
                Text(tr('Size: {size}', {'size': result.fileSizeFormatted})),
                const SizedBox(height: 8),
                Text(AppFiles.isWeb ? tr('Kept in this browser (Tools → Created files)') : tr('Saved to: ProDFOS folder'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Done'))),
              TextButton.icon(
                onPressed: () { Navigator.pop(ctx); AppFiles.share(result.outputPath); },
                icon: Icon(AppFiles.isWeb ? Icons.download_rounded : Icons.share, size: 18), label: Text(AppFiles.isWeb ? tr('Download') : tr('Share')),
              ),
              FilledButton.icon(
                onPressed: () { Navigator.pop(ctx); AppFiles.open(result.outputPath); },
                icon: const Icon(Icons.open_in_new, size: 18), label: Text(tr('Open')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Failed: {e}', {'e': e}))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Text to PDF')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _isProcessing ? null : _convert,
              icon: _isProcessing
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: Text(_isProcessing ? tr('Creating...') : tr('Create PDF')),
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
              decoration: InputDecoration(
                labelText: tr('Document Title'),
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
                decoration: InputDecoration(
                  hintText: tr('Type or paste your text here...'),
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
