import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/pdf_service.dart';

class ExtractTextScreen extends StatefulWidget {
  const ExtractTextScreen({super.key});
  @override
  State<ExtractTextScreen> createState() => _ExtractTextScreenState();
}

class _ExtractTextScreenState extends State<ExtractTextScreen> {
  String? _filePath;
  String? _fileName;
  bool _isProcessing = false;
  PdfResult? _result;
  String? _previewText;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.first.path == null) return;
    setState(() {
      _filePath = result.files.first.path!;
      _fileName = result.files.first.name;
      _result = null;
      _previewText = null;
    });
  }

  Future<void> _extract() async {
    if (_filePath == null) return;
    setState(() => _isProcessing = true);
    try {
      final result = await context.read<PdfService>().extractText(_filePath!);
      final content = await File(result.outputPath).readAsString();
      setState(() {
        _isProcessing = false;
        _result = result;
        _previewText = content.length > 2000 ? '${content.substring(0, 2000)}...' : content;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extraction failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Extract Text')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkCard, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: _filePath == null
                  ? Column(children: [
                      Icon(Icons.text_snippet_rounded, size: 40,
                        color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.file_open_rounded, size: 18),
                        label: const Text('Choose PDF'),
                      ),
                    ])
                  : Row(children: [
                      Icon(Icons.picture_as_pdf_rounded,
                        color: AppTheme.brandGold.withValues(alpha: 0.6)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_fileName ?? '', maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                      TextButton(onPressed: _pickFile, child: const Text('Change')),
                    ]),
            ),
            const SizedBox(height: 16),

            if (_filePath != null && _result == null)
              FilledButton.icon(
                onPressed: _isProcessing ? null : _extract,
                icon: _isProcessing
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.text_snippet_rounded, size: 18),
                label: Text(_isProcessing ? 'Extracting...' : 'Extract Text'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),

            if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text('Text Extracted', style: TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 8),
                    Text('${_result!.fileName} • ${_result!.fileSizeFormatted}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                    const SizedBox(height: 12),
                    Row(children: [
                      OutlinedButton.icon(
                        onPressed: () => Share.shareXFiles([XFile(_result!.outputPath)]),
                        icon: const Icon(Icons.share, size: 16), label: const Text('Share'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => OpenFilex.open(_result!.outputPath),
                        icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Open'),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Preview:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _previewText ?? '',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13, height: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
