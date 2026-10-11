import 'dart:io';
import 'package:image/image.dart' as img;

/// Scan enhancement engine — runs inside a background isolate via compute().
///
/// args:
///   'input'  : source image path
///   'output' : destination JPEG path
///   'mode'   : 'natural' | 'bright' | 'bw'
Future<void> enhanceImageFile(Map<String, String> args) async {
  final bytes = await File(args['input']!).readAsBytes();
  var image = img.decodeImage(bytes);
  if (image == null) throw Exception('Cannot decode image');

  // Respect camera rotation (EXIF) so pages are never sideways
  image = img.bakeOrientation(image);

  switch (args['mode'] ?? 'natural') {
    case 'bw':
      // Crisp black & white — contracts, forms, text-only pages
      image = img.grayscale(image);
      _autoLevelsPerChannel(image, clip: 0.01);
      image = img.contrast(image, contrast: 112);
      _unsharpMask(image, radius: 2, amount: 0.6, threshold: 8);
      break;

    case 'bright':
      // Bright — forces white paper, strong color. Best for receipts, faded forms
      _autoLevelsPerChannel(image, clip: 0.005);
      image = img.adjustColor(image, saturation: 1.10);
      _unsharpMask(image, radius: 2, amount: 0.5, threshold: 6);
      break;

    case 'natural':
    default:
      // Natural — faithful to the real document.
      // Keeps paper tone (cream stays cream), never clips highlights so light
      // watermarks keep their detail, no color shift, gentle edge sharpening.
      _naturalLevels(image);
      _unsharpMask(image, radius: 2, amount: 0.35, threshold: 6);
      break;
  }

  await File(args['output']!).writeAsBytes(img.encodeJpg(image, quality: 96));
}

// ══════════════════════════════════════════════════════════════════
// NATURAL LEVELS
// Same curve applied to R, G and B → no color shift, paper tone preserved.
// Black point from luminance (deepens ink), white point from the brightest
// channel → no channel ever clips, so watermarks and highlights survive.
// ══════════════════════════════════════════════════════════════════
void _naturalLevels(img.Image image) {
  final lumHist = List<int>.filled(256, 0);
  final maxHist = List<int>.filled(256, 0);

  for (final p in image) {
    final r = p.r.toInt().clamp(0, 255);
    final g = p.g.toInt().clamp(0, 255);
    final b = p.b.toInt().clamp(0, 255);
    final lum = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
    lumHist[lum]++;
    final mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
    maxHist[mx]++;
  }

  final total = image.width * image.height;

  // Black point: darkest 0.2% of luminance
  final lowThreshold = (total * 0.002).round();
  int low = 0, acc = 0;
  for (int i = 0; i < 256; i++) {
    acc += lumHist[i];
    if (acc > lowThreshold) { low = i; break; }
  }

  // White point: brightest channel, only 0.02% tolerance — practically no clipping
  final highThreshold = (total * 0.0002).round();
  int high = 255;
  acc = 0;
  for (int i = 255; i >= 0; i--) {
    acc += maxHist[i];
    if (acc > highThreshold) { high = i; break; }
  }

  if (high - low < 20) return; // already full range

  final lut = List<int>.generate(256, (i) {
    final v = ((i - low) * 255 / (high - low)).round();
    return v.clamp(0, 255);
  });

  for (final p in image) {
    p.r = lut[p.r.toInt().clamp(0, 255)];
    p.g = lut[p.g.toInt().clamp(0, 255)];
    p.b = lut[p.b.toInt().clamp(0, 255)];
  }
}

// ══════════════════════════════════════════════════════════════════
// UNSHARP MASK WITH NOISE THRESHOLD
// sharpened = original + amount × (original − blurred)
// only where |original − blurred| > threshold → edges sharpen, grain doesn't.
// ══════════════════════════════════════════════════════════════════
void _unsharpMask(img.Image image,
    {int radius = 2, double amount = 0.5, int threshold = 6}) {
  final blurred = img.gaussianBlur(image.clone(), radius: radius);

  for (final p in image) {
    final b = blurred.getPixel(p.x, p.y);
    p.r = _sharpenChannel(p.r.toInt(), b.r.toInt(), amount, threshold);
    p.g = _sharpenChannel(p.g.toInt(), b.g.toInt(), amount, threshold);
    p.b = _sharpenChannel(p.b.toInt(), b.b.toInt(), amount, threshold);
  }
}

int _sharpenChannel(int orig, int blur, double amount, int threshold) {
  final diff = orig - blur;
  if (diff.abs() <= threshold) return orig;
  return (orig + amount * diff).round().clamp(0, 255);
}

// ══════════════════════════════════════════════════════════════════
// PER-CHANNEL AUTO LEVELS (Bright + B&W)
// Stretches each channel separately → forces white paper, removes color cast.
// ══════════════════════════════════════════════════════════════════
void _autoLevelsPerChannel(img.Image image, {double clip = 0.005}) {
  final hr = List<int>.filled(256, 0);
  final hg = List<int>.filled(256, 0);
  final hb = List<int>.filled(256, 0);

  for (final p in image) {
    hr[p.r.toInt().clamp(0, 255)]++;
    hg[p.g.toInt().clamp(0, 255)]++;
    hb[p.b.toInt().clamp(0, 255)]++;
  }

  final total = image.width * image.height;
  final lutR = _buildLut(hr, total, clip);
  final lutG = _buildLut(hg, total, clip);
  final lutB = _buildLut(hb, total, clip);

  for (final p in image) {
    p.r = lutR[p.r.toInt().clamp(0, 255)];
    p.g = lutG[p.g.toInt().clamp(0, 255)];
    p.b = lutB[p.b.toInt().clamp(0, 255)];
  }
}

List<int> _buildLut(List<int> hist, int total, double clip) {
  final threshold = (total * clip).round();

  int low = 0, acc = 0;
  for (int i = 0; i < 256; i++) {
    acc += hist[i];
    if (acc > threshold) { low = i; break; }
  }

  int high = 255;
  acc = 0;
  for (int i = 255; i >= 0; i--) {
    acc += hist[i];
    if (acc > threshold) { high = i; break; }
  }

  if (high - low < 10) return List<int>.generate(256, (i) => i);

  return List<int>.generate(256, (i) {
    final v = ((i - low) * 255 / (high - low)).round();
    return v.clamp(0, 255);
  });
}
