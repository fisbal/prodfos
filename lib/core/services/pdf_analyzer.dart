import 'dart:io';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync_pdf;

/// Issues detected in a PDF before rendering.
class PdfAnalysis {
  final bool isXfa;
  final bool isEncrypted;
  final bool isScannedOnly;
  final bool isCorrupted;
  final bool isOversized;
  final int pageCount;
  final int fileSizeBytes;
  final String? errorMessage;
  final List<String> warnings;

  PdfAnalysis({
    this.isXfa = false,
    this.isEncrypted = false,
    this.isScannedOnly = false,
    this.isCorrupted = false,
    this.isOversized = false,
    this.pageCount = 0,
    this.fileSizeBytes = 0,
    this.errorMessage,
    this.warnings = const [],
  });

  bool get hasIssues => isXfa || isEncrypted || isScannedOnly || isCorrupted || isOversized || warnings.isNotEmpty;
  bool get canOpen => !isXfa && !isCorrupted; // Can still attempt to render

  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Analyzes a PDF for compatibility issues before the viewer tries to render it.
class PdfAnalyzer {
  static const int _oversizeThreshold = 100 * 1024 * 1024; // 100 MB

  /// Run all checks on a PDF file.
  static Future<PdfAnalysis> analyze(String filePath) async {
    final file = File(filePath);
    final warnings = <String>[];

    // Check file exists
    if (!await file.exists()) {
      return PdfAnalysis(
        isCorrupted: true,
        errorMessage: 'File not found: $filePath',
      );
    }

    final fileSize = await file.length();
    final isOversized = fileSize > _oversizeThreshold;
    if (isOversized) {
      warnings.add('This PDF is ${(fileSize / (1024 * 1024)).toStringAsFixed(0)} MB — it may load slowly.');
    }

    // Read raw bytes for header checks
    final bytes = await file.readAsBytes();

    // Check valid PDF header
    if (bytes.length < 5 || String.fromCharCodes(bytes.sublist(0, 5)) != '%PDF-') {
      return PdfAnalysis(
        isCorrupted: true,
        fileSizeBytes: fileSize,
        errorMessage: 'This file does not appear to be a valid PDF.',
      );
    }

    // Check for XFA (search for /XFA in the raw bytes)
    final isXfa = _containsPattern(bytes, '/XFA');

    // Check for encryption marker
    final hasEncryptMarker = _containsPattern(bytes, '/Encrypt');

    if (isXfa) {
      warnings.add('This is an XFA form created with Adobe LiveCycle. Only Adobe Acrobat Reader can display XFA forms — no other PDF viewer supports them (not Chrome, Firefox, Foxit, or any mobile app).');
    }

    // Try to open with Syncfusion to get page count and check text
    int pageCount = 0;
    bool isScannedOnly = false;
    bool isCorrupted = false;
    String? errorMessage;

    try {
      final doc = sync_pdf.PdfDocument(inputBytes: bytes);
      pageCount = doc.pages.count;

      // Check if the document has extractable text (first page)
      if (pageCount > 0 && !isXfa) {
        try {
          final extractor = sync_pdf.PdfTextExtractor(doc);
          final text = extractor.extractText(startPageIndex: 0, endPageIndex: 0);
          if (text.trim().isEmpty) {
            // Check a few more pages before concluding
            bool foundText = false;
            final pagesToCheck = pageCount > 3 ? 3 : pageCount;
            for (int i = 1; i < pagesToCheck; i++) {
              final moreText = extractor.extractText(startPageIndex: i, endPageIndex: i);
              if (moreText.trim().isNotEmpty) {
                foundText = true;
                break;
              }
            }
            if (!foundText) {
              isScannedOnly = true;
              warnings.add('This PDF appears to be scanned (image-only). Text search and DocMind™ AI won\'t work on this document.');
            }
          }
        } catch (_) {
          // Text extraction failed — might be scanned
        }
      }

      // Check for very high page count
      if (pageCount > 500) {
        warnings.add('This PDF has $pageCount pages. Navigation and scrolling may be slow.');
      }

      doc.dispose();
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('password') || msg.contains('encrypted')) {
        return PdfAnalysis(
          isEncrypted: true,
          fileSizeBytes: fileSize,
          pageCount: 0,
          warnings: ['This PDF is password-protected.'],
        );
      }
      isCorrupted = true;
      errorMessage = 'Failed to read PDF: ${e.toString()}';
    }

    return PdfAnalysis(
      isXfa: isXfa,
      isEncrypted: hasEncryptMarker && pageCount == 0,
      isScannedOnly: isScannedOnly,
      isCorrupted: isCorrupted,
      isOversized: isOversized,
      pageCount: pageCount,
      fileSizeBytes: fileSize,
      errorMessage: errorMessage,
      warnings: warnings,
    );
  }

  /// Search for an ASCII pattern in PDF bytes (efficient enough for markers).
  static bool _containsPattern(Uint8List bytes, String pattern) {
    final patternBytes = pattern.codeUnits;
    if (patternBytes.length > bytes.length) return false;

    // Search in first 50KB and last 50KB (XFA/Encrypt markers are in the xref/trailer area)
    final searchRanges = <List<int>>[];
    searchRanges.add([0, bytes.length.clamp(0, 50000)]);
    if (bytes.length > 50000) {
      searchRanges.add([bytes.length - 50000, bytes.length]);
    }

    for (final range in searchRanges) {
      for (int i = range[0]; i <= range[1] - patternBytes.length; i++) {
        bool match = true;
        for (int j = 0; j < patternBytes.length; j++) {
          if (bytes[i + j] != patternBytes[j]) {
            match = false;
            break;
          }
        }
        if (match) return true;
      }
    }
    return false;
  }
}
