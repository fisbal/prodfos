import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../platform/app_files.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync_pdf;

/// Result of a PDF operation — holds output path and metadata.
class PdfResult {
  final String outputPath;
  final String fileName;
  final int fileSize;
  final String operation;

  PdfResult({
    required this.outputPath,
    required this.fileName,
    required this.fileSize,
    required this.operation,
  });

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class PdfService extends ChangeNotifier {
  bool _isProcessing = false;
  String? _statusMessage;

  bool get isProcessing => _isProcessing;
  String? get statusMessage => _statusMessage;

  /// Output folder: Download/ProDFOS (Android), Documents\\ProDFOS (Windows),
  /// browser storage (Web).
  Future<String> _getOutputDir() => AppFiles.outputDir();

  /// Generate a unique output filename
  String _uniqueName(String baseName, String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final cleanName = baseName.replaceAll(RegExp(r'[^\w\-.]'), '_');
    return '${cleanName}_$timestamp.$extension';
  }

  // ══════════════════════════════════════════════════════════════════
  // MERGE — Combine multiple PDFs into one
  // ══════════════════════════════════════════════════════════════════
  Future<PdfResult> mergePdfs(List<String> filePaths) async {
    _setStatus('Merging ${filePaths.length} PDFs...');

    try {
      final mergedDoc = sync_pdf.PdfDocument();

      for (int i = 0; i < filePaths.length; i++) {
        _setStatus('Processing file ${i + 1} of ${filePaths.length}...');
        final bytes = await AppFiles.readBytes(filePaths[i]);
        final sourceDoc = sync_pdf.PdfDocument(inputBytes: bytes);

        // Copy each page from source to merged document
        for (int j = 0; j < sourceDoc.pages.count; j++) {
          final template = sourceDoc.pages[j].createTemplate();
          final pageSize = sourceDoc.pages[j].size;
          final newPage = mergedDoc.pages.add();
          // Set page size to match source
          newPage.graphics.drawPdfTemplate(
            template,
            Offset.zero,
            pageSize,
          );
        }
        sourceDoc.dispose();
      }

      // Save
      final outputDir = await _getOutputDir();
      final fileName = _uniqueName('merged', 'pdf');
      final outputPath = AppFiles.join(outputDir, fileName);
      final outputBytes = await mergedDoc.save();
      await AppFiles.writeBytes(outputPath, outputBytes);
      mergedDoc.dispose();

      final result = PdfResult(
        outputPath: outputPath,
        fileName: fileName,
        fileSize: outputBytes.length,
        operation: 'Merge',
      );
      _clearStatus();
      return result;
    } catch (e) {
      _clearStatus();
      throw Exception('Merge failed: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // SPLIT — Extract specific pages from a PDF
  // ══════════════════════════════════════════════════════════════════
  Future<PdfResult> splitPdf(String filePath, List<int> pageNumbers) async {
    _setStatus('Splitting PDF...');

    try {
      final bytes = await AppFiles.readBytes(filePath);
      final sourceDoc = sync_pdf.PdfDocument(inputBytes: bytes);
      final newDoc = sync_pdf.PdfDocument();

      for (final pageNum in pageNumbers) {
        if (pageNum >= 1 && pageNum <= sourceDoc.pages.count) {
          _setStatus('Extracting page $pageNum...');
          final template = sourceDoc.pages[pageNum - 1].createTemplate();
          final pageSize = sourceDoc.pages[pageNum - 1].size;
          final newPage = newDoc.pages.add();
          newPage.graphics.drawPdfTemplate(template, Offset.zero, pageSize);
        }
      }

      // Save
      final outputDir = await _getOutputDir();
      final baseName = p.basenameWithoutExtension(filePath);
      final fileName = _uniqueName('${baseName}_pages', 'pdf');
      final outputPath = AppFiles.join(outputDir, fileName);
      final outputBytes = await newDoc.save();
      await AppFiles.writeBytes(outputPath, outputBytes);
      sourceDoc.dispose();
      newDoc.dispose();

      final result = PdfResult(
        outputPath: outputPath,
        fileName: fileName,
        fileSize: outputBytes.length,
        operation: 'Split',
      );
      _clearStatus();
      return result;
    } catch (e) {
      _clearStatus();
      throw Exception('Split failed: $e');
    }
  }

  /// Get page count of a PDF file
  Future<int> getPageCount(String filePath) async {
    final bytes = await AppFiles.readBytes(filePath);
    final doc = sync_pdf.PdfDocument(inputBytes: bytes);
    final count = doc.pages.count;
    doc.dispose();
    return count;
  }

  // ══════════════════════════════════════════════════════════════════
  // EXTRACT TEXT — Pull text from a PDF
  // ══════════════════════════════════════════════════════════════════
  Future<PdfResult> extractText(String filePath) async {
    _setStatus('Extracting text...');

    try {
      final bytes = await AppFiles.readBytes(filePath);
      final doc = sync_pdf.PdfDocument(inputBytes: bytes);
      final buffer = StringBuffer();

      for (int i = 0; i < doc.pages.count; i++) {
        _setStatus('Reading page ${i + 1} of ${doc.pages.count}...');
        final extractor = sync_pdf.PdfTextExtractor(doc);
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
        if (text.isNotEmpty) {
          buffer.writeln('--- Page ${i + 1} ---');
          buffer.writeln(text);
          buffer.writeln();
        }
      }

      doc.dispose();

      // Save as .txt
      final outputDir = await _getOutputDir();
      final baseName = p.basenameWithoutExtension(filePath);
      final fileName = _uniqueName('${baseName}_text', 'txt');
      final outputPath = AppFiles.join(outputDir, fileName);
      final content = buffer.toString();
      await AppFiles.writeString(outputPath, content);

      final result = PdfResult(
        outputPath: outputPath,
        fileName: fileName,
        fileSize: content.length,
        operation: 'Extract Text',
      );
      _clearStatus();
      return result;
    } catch (e) {
      _clearStatus();
      throw Exception('Text extraction failed: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // IMAGE TO PDF — Create PDF from images
  // ══════════════════════════════════════════════════════════════════
  Future<PdfResult> imagesToPdf(List<String> imagePaths) async {
    _setStatus('Creating PDF from ${imagePaths.length} images...');

    try {
      final doc = sync_pdf.PdfDocument();

      for (int i = 0; i < imagePaths.length; i++) {
        _setStatus('Adding image ${i + 1} of ${imagePaths.length}...');
        // Original bytes are embedded as-is — no re-compression
        final imageBytes = await AppFiles.readBytes(imagePaths[i]);
        final image = sync_pdf.PdfBitmap(imageBytes);

        final isLandscape = image.width > image.height;

        // Each image gets its own section so orientation is per-page.
        // Syncfusion ignores a custom landscape Size — orientation must be explicit.
        final section = doc.sections!.add();
        section.pageSettings.size = sync_pdf.PdfPageSize.letter; // 8.5 x 11 in
        section.pageSettings.orientation = isLandscape
            ? sync_pdf.PdfPageOrientation.landscape
            : sync_pdf.PdfPageOrientation.portrait;
        section.pageSettings.margins.all = 0;

        final page = section.pages.add();
        final pageSize = page.getClientSize();

        // FIT mode: whole image always visible, never cropped
        final scaleX = pageSize.width / image.width;
        final scaleY = pageSize.height / image.height;
        final scale = scaleX < scaleY ? scaleX : scaleY;

        final imgWidth = image.width * scale;
        final imgHeight = image.height * scale;
        final x = (pageSize.width - imgWidth) / 2;
        final y = (pageSize.height - imgHeight) / 2;

        page.graphics.drawImage(
          image,
          Rect.fromLTWH(x, y, imgWidth, imgHeight),
        );
      }

      // Save
      final outputDir = await _getOutputDir();
      final fileName = _uniqueName('scan', 'pdf');
      final outputPath = AppFiles.join(outputDir, fileName);
      final outputBytes = await doc.save();
      await AppFiles.writeBytes(outputPath, outputBytes);
      doc.dispose();

      final result = PdfResult(
        outputPath: outputPath,
        fileName: fileName,
        fileSize: outputBytes.length,
        operation: 'Images to PDF',
      );
      _clearStatus();
      return result;
    } catch (e) {
      _clearStatus();
      throw Exception('Image to PDF failed: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // TEXT TO PDF — Create PDF from plain text
  // ══════════════════════════════════════════════════════════════════
  Future<PdfResult> textToPdf(String textContent, {String title = 'Document'}) async {
    _setStatus('Creating PDF...');

    try {
      final doc = sync_pdf.PdfDocument();
      final page = doc.pages.add();
      final font = sync_pdf.PdfStandardFont(sync_pdf.PdfFontFamily.helvetica, 12);
      final titleFont = sync_pdf.PdfStandardFont(sync_pdf.PdfFontFamily.helvetica, 18,
          style: sync_pdf.PdfFontStyle.bold);

      // Title
      page.graphics.drawString(
        title,
        titleFont,
        bounds: Rect.fromLTWH(40, 40, page.size.width - 80, 30),
      );

      // Body text with auto-pagination
      final format = sync_pdf.PdfStringFormat(
        lineSpacing: 4,
      );
      page.graphics.drawString(
        textContent,
        font,
        bounds: Rect.fromLTWH(40, 80, page.size.width - 80, page.size.height - 120),
        format: format,
      );

      // Save
      final outputDir = await _getOutputDir();
      final fileName = _uniqueName(title, 'pdf');
      final outputPath = AppFiles.join(outputDir, fileName);
      final outputBytes = await doc.save();
      await AppFiles.writeBytes(outputPath, outputBytes);
      doc.dispose();

      final result = PdfResult(
        outputPath: outputPath,
        fileName: fileName,
        fileSize: outputBytes.length,
        operation: 'Text to PDF',
      );
      _clearStatus();
      return result;
    } catch (e) {
      _clearStatus();
      throw Exception('Text to PDF failed: $e');
    }
  }

  void _setStatus(String msg) {
    _isProcessing = true;
    _statusMessage = msg;
    notifyListeners();
  }

  void _clearStatus() {
    _isProcessing = false;
    _statusMessage = null;
    notifyListeners();
  }
}
