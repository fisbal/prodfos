import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:prodfos/core/services/scan_layout.dart';
import 'package:prodfos/features/tools/scan_types.dart';

/// A photo of an open book: two cream pages with dark text lines, a dark binding shadow in the
/// middle at [gutter], on a dark table.
img.Image openBook({int w = 1200, int h = 800, int gutter = 640}) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(30, 30, 30)); // table
  img.fillRect(im, x1: 40, y1: 30, x2: w - 40, y2: h - 30, color: img.ColorRgb8(240, 232, 215)); // pages
  for (var x = gutter - 25; x < gutter + 25; x++) {
    final d = (x - gutter).abs();
    final v = 120 + d * 4;
    img.drawLine(im, x1: x, y1: 30, x2: x, y2: h - 30, color: img.ColorRgb8(v, v - 5, v - 15));
  }
  for (var y = 80; y < h - 80; y += 40) {
    img.fillRect(im, x1: 90, y1: y, x2: gutter - 60, y2: y + 8, color: img.ColorRgb8(40, 40, 40));
    img.fillRect(im, x1: gutter + 60, y1: y, x2: w - 90, y2: y + 8, color: img.ColorRgb8(40, 40, 40));
  }
  return im;
}

void main() {
  test('at least 20 kinds of document, with ID card, book, passport, receipt, whiteboard', () {
    expect(scanTypes.length, greaterThanOrEqualTo(20));
    for (final id in ['document', 'book', 'idcard', 'passport', 'licence', 'receipt', 'whiteboard', 'business']) {
      expect(scanTypes.any((t) => t.id == id), isTrue, reason: id);
    }
    expect(scanTypes.map((t) => t.id).toSet().length, scanTypes.length);
    for (final t in scanTypes.where((t) => t.isCard)) {
      expect(t.cardW, greaterThan(t.cardH));
    }
  });

  test('finds the binding of an open book, even off centre', () {
    final x = findGutter(openBook(gutter: 640))!;
    expect((x - 640).abs(), lessThan(12));
  });

  test('a single page is not split', () {
    expect(findGutter(img.Image(width: 600, height: 900)), isNull);
    expect(splitSpread(img.Image(width: 600, height: 900)).length, 1);
  });

  test('an open book becomes two pages in reading order, right page first for right-to-left', () {
    final book = openBook();
    final ltr = splitSpread(book);
    expect(ltr.length, 2);
    expect(ltr[0].width, greaterThan(ltr[1].width)); // the gutter is right of centre: the left page is wider
    final rtl = splitSpread(book, rightToLeft: true);
    expect(rtl[0].width, ltr[1].width);
  });

  test('cuts away the dark table around a page', () {
    final t = autoTrim(openBook());
    expect(t.width, lessThan(1200 - 60));
    expect(t.height, lessThan(800 - 40));
  });

  test('evens out a shadow: the dark side of the paper becomes as light as the bright side', () {
    final im = img.Image(width: 400, height: 300);
    for (final p in im) {
      final v = 120 + (p.x * 120 / 400).round(); // a lamp on the right
      p..r = v..g = v..b = v;
    }
    final out = flattenLight(im);
    final left = out.getPixel(20, 150).r, right = out.getPixel(380, 150).r;
    expect((left - right).abs(), lessThan(25));
    expect(left, greaterThan(200));
  });

  test('ID card: front and back on one A4 sheet at real size', () {
    final front = img.Image(width: 900, height: 570), back = img.Image(width: 900, height: 570);
    img.fill(front, color: img.ColorRgb8(200, 220, 240));
    img.fill(back, color: img.ColorRgb8(240, 220, 200));
    final page = cardSheet([front, back], widthMm: 85.6, heightMm: 53.98, mark: 'Copie pour la banque – 03/11/2026');
    expect(page.width, a4W);
    expect(page.height, a4H);
    // The card is 85.6 mm wide at 300 dpi = 1011 px: its colour spans that width in the middle.
    final y = (a4H / 2 - 12 * pxPerMm / 2 - 53.98 * pxPerMm / 2).round();
    var run = 0;
    for (var x = 0; x < a4W; x++) {
      final p = page.getPixel(x, y);
      if (p.r < 230 || p.b > p.r + 10) run++;
    }
    expect((run - 85.6 * pxPerMm).abs(), lessThan(40));
  });

  test('layoutPages: a book photo gives two pages, a card pair gives one sheet', () {
    final book = img.encodeJpg(openBook());
    expect(layoutPages({'bytes': [book, book], 'layout': 'book', 'cover': false}).length, 4);
    expect(layoutPages({'bytes': [book, book], 'layout': 'book'}).length, 3); // the cover stays whole
    final card = img.encodeJpg(img.Image(width: 900, height: 570));
    expect(layoutPages({'bytes': [card, card], 'layout': 'card', 'sides': 2, 'cardW': 85.6, 'cardH': 53.98}).length, 1);
  });

  test('accents are kept readable in the watermark font', () {
    expect(plain('Copie réservée à l’État'), "Copie reservee a l'Etat");
  });
}
