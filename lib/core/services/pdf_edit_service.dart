import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

// ══════════════════════════════════════════════════════════════════
// MODELS — every coordinate is in PDF page points (top-left origin)
// ══════════════════════════════════════════════════════════════════

enum EditItemType { text, image, stamp, signature, note, replace }

class PenStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final double opacity; // 1.0 pen, ~0.35 marker
  PenStroke({required this.points, required this.color, required this.width, this.opacity = 1.0});
}

class EditItem {
  final EditItemType type;
  Offset position;
  Size size;
  String text;
  double fontSize;
  Color color;
  Uint8List? imageBytes;
  Rect? coverRect;          // replace: original text area to white-out
  String fontFamily;        // 'helvetica' | 'times' | 'courier'
  bool bold;

  EditItem({
    required this.type,
    required this.position,
    required this.size,
    this.text = '',
    this.fontSize = 14,
    this.color = Colors.black,
    this.imageBytes,
    this.coverRect,
    this.fontFamily = 'helvetica',
    this.bold = false,
  });
}

class TextLineHit {
  final String text;
  final Rect bounds;
  final double fontSize;
  final String fontFamily;
  final bool bold;
  TextLineHit(this.text, this.bounds, this.fontSize, this.fontFamily, this.bold);
}

class PageEntry {
  final int docIndex;   // -1 = blank page
  final int pageIndex;
  int extraTurns;       // quarter turns clockwise added by the user
  PageEntry({required this.docIndex, required this.pageIndex, this.extraTurns = 0});
  bool get isBlank => docIndex < 0;
  PageEntry copy() => PageEntry(docIndex: docIndex, pageIndex: pageIndex, extraTurns: extraTurns);
}

// ══════════════════════════════════════════════════════════════════
// ENGINE
// ══════════════════════════════════════════════════════════════════

class PdfEditService {
  PdfEditService._();

  /// Page size in points, whether the page carries a rotation, and page count.
  static ({Size size, bool rotated, int count}) pageInfo(Uint8List bytes, int index) {
    final doc = PdfDocument(inputBytes: bytes);
    try {
      final page = doc.pages[index];
      return (
        size: page.size,
        rotated: page.rotation != PdfPageRotateAngle.rotateAngle0,
        count: doc.pages.count,
      );
    } finally {
      doc.dispose();
    }
  }

  /// Finds the text line under (or nearest to) a tap, with its font details.
  static TextLineHit? findLineAt(Uint8List bytes, int pageIndex, Offset p) {
    final doc = PdfDocument(inputBytes: bytes);
    try {
      final lines = PdfTextExtractor(doc)
          .extractTextLines(startPageIndex: pageIndex, endPageIndex: pageIndex);

      TextLine? best;
      double bestDist = double.infinity;
      for (final l in lines) {
        if (l.text.trim().isEmpty) continue;
        if (l.bounds.inflate(3).contains(p)) { best = l; break; }
        final withinX = p.dx >= l.bounds.left - 10 && p.dx <= l.bounds.right + 10;
        final dy = (l.bounds.center.dy - p.dy).abs();
        if (withinX && dy < 14 && dy < bestDist) { best = l; bestDist = dy; }
      }
      if (best == null) return null;

      final name = best.fontName.toLowerCase();
      String family = 'helvetica';
      if (name.contains('courier') || name.contains('mono')) {
        family = 'courier';
      } else if (name.contains('times') || name.contains('georgia') || name.contains('garamond') ||
          (name.contains('serif') && !name.contains('sans'))) {
        family = 'times';
      }
      final bold = best.fontStyle.contains(PdfFontStyle.bold) || name.contains('bold');
      final size = best.fontSize > 0 ? best.fontSize : best.bounds.height * 0.8;

      return TextLineHit(best.text, best.bounds, size, family, bold);
    } finally {
      doc.dispose();
    }
  }

  /// Writes strokes and items onto one page and returns the new PDF bytes.
  static Future<Uint8List> applyPageEdits(
    Uint8List bytes, int pageIndex, List<PenStroke> strokes, List<EditItem> items,
  ) async {
    final doc = PdfDocument(inputBytes: bytes);
    try {
      final page = doc.pages[pageIndex];
      final g = page.graphics;

      // 1. White-out replacements first, so everything else can sit on top
      for (final it in items.where((i) => i.type == EditItemType.replace)) {
        final cover = it.coverRect!.inflate(1.2);
        g.drawRectangle(brush: PdfSolidBrush(PdfColor(255, 255, 255)), bounds: cover);
        g.drawString(
          it.text, _font(it.fontFamily, it.fontSize, bold: it.bold),
          brush: PdfSolidBrush(_pc(it.color)),
          bounds: Rect.fromLTWH(it.coverRect!.left, it.coverRect!.top, 0, 0),
        );
      }

      // 2. Pen & marker strokes
      for (final s in strokes) {
        if (s.points.isEmpty) continue;
        g.save();
        if (s.opacity < 1.0) g.setTransparency(s.opacity);
        final pen = PdfPen(_pc(s.color), width: s.width)
          ..lineCap = PdfLineCap.round
          ..lineJoin = PdfLineJoin.round;
        if (s.points.length == 1) {
          final c = s.points.first;
          g.drawEllipse(Rect.fromCircle(center: c, radius: s.width / 2),
              brush: PdfSolidBrush(_pc(s.color)));
        } else {
          for (int i = 1; i < s.points.length; i++) {
            g.drawLine(pen, s.points[i - 1], s.points[i]);
          }
        }
        g.restore();
      }

      // 3. Items
      for (final it in items) {
        final r = Rect.fromLTWH(it.position.dx, it.position.dy, it.size.width, it.size.height);
        switch (it.type) {
          case EditItemType.replace:
            break; // done in step 1
          case EditItemType.text:
            g.drawString(it.text, _font('helvetica', it.fontSize, bold: it.bold),
                brush: PdfSolidBrush(_pc(it.color)),
                bounds: Rect.fromLTWH(r.left, r.top, 0, 0));
            break;
          case EditItemType.image:
          case EditItemType.signature:
            if (it.imageBytes != null) g.drawImage(PdfBitmap(it.imageBytes!), r);
            break;
          case EditItemType.stamp:
            _drawStamp(g, it, r);
            break;
          case EditItemType.note:
            page.annotations.add(PdfPopupAnnotation(
              Rect.fromLTWH(r.left, r.top, 22, 22), it.text,
              author: 'ProDFOS', color: PdfColor(255, 202, 40),
            ));
            break;
        }
      }

      return Uint8List.fromList(await doc.save());
    } finally {
      doc.dispose();
    }
  }

  static void _drawStamp(PdfGraphics g, EditItem it, Rect r) {
    final color = _pc(it.color);
    final w = r.width, h = r.height;
    g.save();
    g.translateTransform(r.left + w / 2, r.top + h / 2);
    g.rotateTransform(-10);
    g.setTransparency(0.9);
    g.drawRectangle(pen: PdfPen(color, width: 2.5), bounds: Rect.fromLTWH(-w / 2, -h / 2, w, h));
    g.drawRectangle(pen: PdfPen(color, width: 0.8),
        bounds: Rect.fromLTWH(-w / 2 + 4, -h / 2 + 4, w - 8, h - 8));
    g.drawString(
      it.text, _font('helvetica', it.fontSize, bold: true),
      brush: PdfSolidBrush(color),
      bounds: Rect.fromLTWH(-w / 2, -h / 2, w, h),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.middle,
      ),
    );
    g.restore();
  }

  /// Rebuilds a document from an ordered page list (reorder / rotate / delete /
  /// duplicate / blank / pages inserted from other PDFs).
  /// Note: pages are re-drawn as templates → form fields & annotations flatten.
  static Future<Uint8List> rebuildPages(List<Uint8List> sources, List<PageEntry> entries) async {
    final srcDocs = sources.map((b) => PdfDocument(inputBytes: b)).toList();
    final out = PdfDocument();
    try {
      Size refSize = const Size(612, 792); // US Letter default for blanks
      if (srcDocs.isNotEmpty && srcDocs.first.pages.count > 0) {
        refSize = srcDocs.first.pages[0].size;
      }

      for (final e in entries) {
        final section = out.sections!.add();
        section.pageSettings.margins.all = 0;

        PdfPage? srcPage;
        Size size = refSize;
        int baseTurns = 0;
        if (!e.isBlank) {
          srcPage = srcDocs[e.docIndex].pages[e.pageIndex];
          size = srcPage.size;
          baseTurns = _turnsOf(srcPage.rotation);
        }

        section.pageSettings.size = size;
        section.pageSettings.orientation = size.width > size.height
            ? PdfPageOrientation.landscape
            : PdfPageOrientation.portrait;
        section.pageSettings.rotate = _angleOf((baseTurns + e.extraTurns) % 4);

        final page = section.pages.add();
        if (srcPage != null) {
          page.graphics.drawPdfTemplate(srcPage.createTemplate(), Offset.zero, size);
        }
      }
      return Uint8List.fromList(await out.save());
    } finally {
      out.dispose();
      for (final d in srcDocs) { d.dispose(); }
    }
  }

  /// Saves an edited copy next to the other ProDFOS outputs. Returns the path.
  static Future<String> saveEdited(Uint8List bytes, String originalName) async {
    final dir = Directory('/storage/emulated/0/Download/ProDFOS');
    if (!await dir.exists()) await dir.create(recursive: true);
    final base = originalName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^\w\-]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final path = '${dir.path}/${base}_edited_$stamp.pdf';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  // ── helpers ──────────────────────────────────────────────
  static PdfColor _pc(Color c) =>
      PdfColor((c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round());

  static PdfStandardFont _font(String family, double size, {bool bold = false}) {
    final f = family == 'times'
        ? PdfFontFamily.timesRoman
        : family == 'courier' ? PdfFontFamily.courier : PdfFontFamily.helvetica;
    return PdfStandardFont(f, size, style: bold ? PdfFontStyle.bold : PdfFontStyle.regular);
  }

  static int _turnsOf(PdfPageRotateAngle a) {
    switch (a) {
      case PdfPageRotateAngle.rotateAngle90: return 1;
      case PdfPageRotateAngle.rotateAngle180: return 2;
      case PdfPageRotateAngle.rotateAngle270: return 3;
      default: return 0;
    }
  }

  static PdfPageRotateAngle _angleOf(int turns) {
    switch (turns) {
      case 1: return PdfPageRotateAngle.rotateAngle90;
      case 2: return PdfPageRotateAngle.rotateAngle180;
      case 3: return PdfPageRotateAngle.rotateAngle270;
      default: return PdfPageRotateAngle.rotateAngle0;
    }
  }
}
