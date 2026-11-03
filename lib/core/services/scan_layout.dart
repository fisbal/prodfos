import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Page layout for each kind of scanned document (book, ID card, receipt, whiteboard…).
/// Pure functions on images: they run in a background isolate via compute() and the same on
/// Android, Windows and the web build that Office In 1 shows in its ProDFos tab.

/// A small grey copy (longest side [size]) to measure the page quickly.
img.Image _small(img.Image src, [int size = 400]) {
  final s = size / math.max(src.width, src.height);
  final w = math.max(1, (src.width * s).round());
  final h = math.max(1, (src.height * s).round());
  return img.grayscale(img.copyResize(src, width: w, height: h, interpolation: img.Interpolation.average));
}

/// Mean brightness of each column (or row) of a grey image.
List<double> _profile(img.Image g, {required bool columns}) {
  final n = columns ? g.width : g.height;
  final m = columns ? g.height : g.width;
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    var sum = 0.0;
    for (var j = 0; j < m; j++) {
      sum += columns ? g.getPixel(i, j).r : g.getPixel(j, i).r;
    }
    out[i] = sum / m;
  }
  return out;
}

double _median(List<double> xs) {
  final s = [...xs]..sort();
  return s.isEmpty ? 0 : s[s.length ~/ 2];
}

/// Cuts away the dark table, hands or background around a page: rows and columns at the edges that
/// are much darker than the paper. Never cuts more than [maxCut] of a side.
img.Image autoTrim(img.Image src, {double maxCut = 0.22}) {
  final g = _small(src);
  final cols = _profile(g, columns: true);
  final rows = _profile(g, columns: false);
  final paper = math.max(_median(cols), _median(rows));
  if (paper < 90) return src; // a dark photo, not a page: keep it whole
  final limit = paper * 0.62;
  int cut(List<double> p, bool fromEnd) {
    final most = (p.length * maxCut).floor();
    var k = 0;
    while (k < most && p[fromEnd ? p.length - 1 - k : k] < limit) {
      k++;
    }
    return k;
  }
  final sx = src.width / g.width, sy = src.height / g.height;
  final l = (cut(cols, false) * sx).floor(), r = (cut(cols, true) * sx).floor();
  final t = (cut(rows, false) * sy).floor(), b = (cut(rows, true) * sy).floor();
  if (l + r + t + b == 0) return src;
  return img.copyCrop(src, x: l, y: t, width: math.max(1, src.width - l - r), height: math.max(1, src.height - t - b));
}

/// Where the two pages of an open book meet: the darkest column in the middle third
/// (the binding shadow). Returns the x position in the source image, or null when the picture
/// is not a double page (portrait, or no clear gutter).
int? findGutter(img.Image src) {
  if (src.width < src.height * 1.05) return null; // a single page is taller than wide
  final g = _small(src);
  final cols = _profile(g, columns: true);
  final from = (cols.length * 0.36).floor(), to = (cols.length * 0.64).ceil();
  var best = from;
  for (var i = from; i < to; i++) {
    if (cols[i] < cols[best]) best = i;
  }
  final paper = _median(cols);
  // A real gutter is clearly darker than the paper around it.
  if (cols[best] > paper * 0.93) return (src.width / 2).round();
  return (best * src.width / g.width).round();
}

/// An open book photographed as one picture → its two pages, in reading order.
/// [rightToLeft] for Arabic, Hebrew, manga: the right page comes first.
List<img.Image> splitSpread(img.Image src, {bool rightToLeft = false}) {
  final x = findGutter(src);
  if (x == null) return [src];
  final left = img.copyCrop(src, x: 0, y: 0, width: x, height: src.height);
  final right = img.copyCrop(src, x: x, y: 0, width: src.width - x, height: src.height);
  return rightToLeft ? [right, left] : [left, right];
}

/// Evens out the light on a page: the shadow of a book's binding, a curved page, a lamp on one side,
/// the glare and shade on a whiteboard. Each pixel is divided by the local paper brightness
/// (a heavily blurred copy), so the paper becomes even and the ink keeps its strength.
/// [strength] 0 = nothing, 1 = full.
img.Image flattenLight(img.Image src, {double strength = 1}) {
  if (strength <= 0) return src;
  final w = src.width, h = src.height;
  // Paper brightness map: shrink, take the bright paper (a max filter hides the ink), blur, grow.
  final sw = math.max(8, (w / 24).round()), sh = math.max(8, (h / 24).round());
  var bg = img.copyResize(src, width: sw, height: sh, interpolation: img.Interpolation.average);
  final dil = bg.clone();
  for (var y = 0; y < sh; y++) {
    for (var x = 0; x < sw; x++) {
      num r = 0, gg = 0, b = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final p = bg.getPixel((x + dx).clamp(0, sw - 1), (y + dy).clamp(0, sh - 1));
          r = math.max(r, p.r); gg = math.max(gg, p.g); b = math.max(b, p.b);
        }
      }
      dil.setPixelRgb(x, y, r, gg, b);
    }
  }
  bg = img.gaussianBlur(dil, radius: 2);
  bg = img.copyResize(bg, width: w, height: h, interpolation: img.Interpolation.linear);
  final out = src.clone();
  for (final p in out) {
    final q = bg.getPixel(p.x, p.y);
    double ch(num v, num paper) {
      final flat = (v * 245 / math.max(40, paper)).clamp(0, 255);
      return v + (flat - v) * strength;
    }
    p.r = ch(p.r, q.r);
    p.g = ch(p.g, q.g);
    p.b = ch(p.b, q.b);
  }
  return out;
}

/// Pixels per millimetre at 300 dpi (print quality).
const double pxPerMm = 300 / 25.4;

/// The real size of an A4 sheet at 300 dpi.
const int a4W = 2480, a4H = 3508;

/// Removes accents for the built-in bitmap font (it only knows plain letters).
String plain(String s) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿÀÂÄÁÃÅÇÉÈÊËÍÌÎÏÑÓÒÔÖÕÚÙÛÜÝœŒæÆß’';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyAAAAAACEEEEIIIINOOOOOUUUUYoOaAs\'';
  final b = StringBuffer();
  for (final c in s.split('')) {
    final i = from.indexOf(c);
    b.write(i < 0 ? c : (c == 'œ' ? 'oe' : c == 'Œ' ? 'OE' : c == 'æ' ? 'ae' : c == 'Æ' ? 'AE' : c == 'ß' ? 'ss' : to[i]));
  }
  return b.toString();
}

/// Writes a light diagonal watermark over the image, repeated, like the French "FiligraneFacile":
/// "Copie pour la banque X – 03/11/2026". A copy of an ID card with it cannot be reused elsewhere.
void watermark(img.Image page, String text) {
  final t = plain(text.trim());
  if (t.isEmpty) return;
  final font = img.arial48;
  final tw = t.length * 26 + 80;
  final band = img.Image(width: tw, height: 72, numChannels: 4);
  img.fill(band, color: img.ColorRgba8(0, 0, 0, 0));
  img.drawString(band, t, font: font, x: 40, y: 12, color: img.ColorRgba8(90, 90, 110, 110));
  final rot = img.copyRotate(band, angle: -30);
  for (var y = -rot.height ~/ 2; y < page.height; y += 420) {
    for (var x = ((y ~/ 420).isEven ? -200 : 200) - rot.width ~/ 3; x < page.width; x += rot.width + 120) {
      img.compositeImage(page, rot, dstX: x, dstY: y);
    }
  }
}

/// An ID card, driving licence, health card…: front and back side by side on one A4 sheet, each at its
/// real size (so a printed copy matches the card), with thin cut marks and an optional watermark.
img.Image cardSheet(List<img.Image> sides, {required double widthMm, required double heightMm, String mark = ''}) {
  final page = img.Image(width: a4W, height: a4H);
  img.fill(page, color: img.ColorRgb8(255, 255, 255));
  final cw = (widthMm * pxPerMm).round(), ch = (heightMm * pxPerMm).round();
  final gap = (12 * pxPerMm).round();
  final total = sides.length * ch + (sides.length - 1) * gap;
  var y = ((a4H - total) / 2).round().clamp(0, a4H);
  final x = ((a4W - cw) / 2).round();
  for (final s0 in sides) {
    var s = autoTrim(s0, maxCut: 0.3);
    // Cards are landscape: turn a portrait shot.
    if ((s.height > s.width) != (ch > cw)) s = img.copyRotate(s, angle: 90);
    s = img.copyResize(s, width: cw, height: ch, interpolation: img.Interpolation.cubic);
    img.compositeImage(page, s, dstX: x, dstY: y);
    // Cut marks at the four corners.
    final grey = img.ColorRgb8(170, 170, 170);
    const m = 40;
    for (final cx in [x, x + cw]) {
      for (final cy in [y, y + ch]) {
        img.drawLine(page, x1: cx - m, y1: cy, x2: cx - 8, y2: cy, color: grey);
        img.drawLine(page, x1: cx + 8, y1: cy, x2: cx + m, y2: cy, color: grey);
        img.drawLine(page, x1: cx, y1: cy - m, x2: cx, y2: cy - 8, color: grey);
        img.drawLine(page, x1: cx, y1: cy + 8, x2: cx, y2: cy + m, color: grey);
      }
    }
    y += ch + gap;
  }
  watermark(page, mark);
  return page;
}

/// Lays out the captured pictures for one kind of document.
///   'bytes'  : List<Uint8List> pictures, in order
///   'layout' : 'normal' | 'book' | 'card' | 'receipt' | 'board' | 'photo'
///   'split'  : book: cut double pages in two (bool)
///   'rtl'    : book: right page first (bool)
///   'shadow' : book/board/notes: even out the light (bool)
///   'cover'  : book: keep the first picture whole (bool)
///   'cardW', 'cardH' : card size in mm;  'sides' : 1 or 2;  'mark' : watermark text
/// returns List<Uint8List> page pictures (JPEG), ready for the PDF.
List<Uint8List> layoutPages(Map<String, Object> a) {
  final pics = (a['bytes'] as List).cast<Uint8List>();
  final layout = (a['layout'] as String?) ?? 'normal';
  final out = <img.Image>[];
  img.Image? decode(Uint8List b) {
    final d = img.decodeImage(b);
    return d == null ? null : img.bakeOrientation(d);
  }
  final images = pics.map(decode).whereType<img.Image>().toList();
  switch (layout) {
    case 'book':
      final split = a['split'] != false, rtl = a['rtl'] == true, shadow = a['shadow'] != false, cover = a['cover'] != false;
      for (var i = 0; i < images.length; i++) {
        var p = autoTrim(images[i]);
        final parts = (split && !(cover && i == 0)) ? splitSpread(p, rightToLeft: rtl) : [p];
        for (var q in parts) {
          q = autoTrim(q, maxCut: 0.12);
          out.add(shadow ? flattenLight(q) : q);
        }
      }
      break;
    case 'card':
      final sides = ((a['sides'] as int?) ?? 1).clamp(1, 2);
      final w = (a['cardW'] as num?)?.toDouble() ?? 85.6, h = (a['cardH'] as num?)?.toDouble() ?? 54;
      for (var i = 0; i < images.length; i += sides) {
        out.add(cardSheet(images.sublist(i, math.min(images.length, i + sides)), widthMm: w, heightMm: h, mark: (a['mark'] as String?) ?? ''));
      }
      break;
    case 'receipt':
      for (final p in images) {
        out.add(autoTrim(p, maxCut: 0.35));
      }
      break;
    case 'board':
      for (final p in images) {
        out.add(flattenLight(autoTrim(p, maxCut: 0.15)));
      }
      break;
    case 'photo':
      out.addAll(images);
      break;
    default:
      for (final p in images) {
        final q = autoTrim(p, maxCut: 0.15);
        out.add(a['shadow'] == true ? flattenLight(q, strength: 0.8) : q);
      }
  }
  return out.map((p) => img.encodeJpg(p, quality: 94)).toList();
}
