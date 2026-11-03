import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import '../../core/theme/app_theme.dart';
import '../../core/l10n/l10n.dart';

/// The 21 handwriting styles, the same as in Office In 1 (all free, SIL Open Font License, from Google Fonts).
const signatureFonts = <String>[
  'Homemade Apple', 'Mrs Saint Delafield', 'Herr Von Muellerhoff', 'Mr Dafoe', 'Great Vibes', 'Allura', 'Alex Brush',
  'Sacramento', 'Parisienne', 'Pinyon Script', 'Dancing Script', 'Satisfy', 'Yellowtail', 'Kaushan Script',
  'Cedarville Cursive', 'La Belle Aurore', 'Kristi', 'Marck Script', 'Caveat', 'Pacifico', 'Permanent Marker',
];

/// "Martin Ballas" → "MB".
String initialsOf(String name) => name.trim().split(RegExp(r'[\s-]+'))
    .where((w) => w.isNotEmpty && !RegExp(r'^(de|du|des|la|le|van|von|da|di|del|dos|der)$', caseSensitive: false).hasMatch(w))
    .map((w) => w[0].toUpperCase()).take(4).join();

/// Signatures (Martin, 2026-11-03): draw it, type it in one of 21 handwriting styles, or import a photo (the paper
/// becomes transparent). Several are kept on this device; place the signature, a full signature line (name, title,
/// date) or the initials. Returns PNG bytes (transparent background), or null.
class SignaturePadSheet extends StatefulWidget {
  const SignaturePadSheet({super.key});

  static Future<Uint8List?> show(BuildContext context) {
    return showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const SignaturePadSheet(),
    );
  }

  @override
  State<SignaturePadSheet> createState() => _SignaturePadSheetState();
}

class _SignaturePadSheetState extends State<SignaturePadSheet> {
  static const _oldKey = 'saved_signature_png';
  static const _listKey = 'saved_signatures';
  final _padKey = GlobalKey<SfSignaturePadState>();
  Color _ink = const Color(0xFF0D1B4C); // deep navy — reads as real pen ink
  bool _hasStrokes = false;
  int _mode = 0; // 0 draw, 1 type, 2 import
  String _font = signatureFonts.first;
  final _name = TextEditingController();
  final _title = TextEditingController();
  final _typed = TextEditingController();
  bool _line = false;
  Uint8List? _photo;
  String _error = '';
  bool _busy = false;
  List<Uint8List> _saved = [];

  Box get _box => Hive.box('settings');

  @override
  void initState() {
    super.initState();
    final list = _box.get(_listKey);
    if (list is List) _saved = list.whereType<Uint8List>().toList();
    final old = _box.get(_oldKey);
    if (old is Uint8List && !_saved.any((s) => _same(s, old))) _saved.insert(0, old);
    _name.text = (_box.get('signature_name') as String?) ?? '';
    _title.text = (_box.get('signature_title') as String?) ?? '';
  }

  @override
  void dispose() { _name.dispose(); _title.dispose(); _typed.dispose(); super.dispose(); }

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i += math.max(1, a.length ~/ 256)) { if (a[i] != b[i]) return false; }
    return true;
  }

  Future<void> _keep(Uint8List png) async {
    _saved.removeWhere((s) => _same(s, png));
    _saved.insert(0, png);
    if (_saved.length > 12) _saved = _saved.sublist(0, 12);
    await _box.put(_listKey, _saved);
    await _box.put(_oldKey, png);
    await _box.put('signature_name', _name.text.trim());
    await _box.put('signature_title', _title.text.trim());
  }

  // ---------------------------------------------------------------- pictures

  static Future<Uint8List?> _png(ui.Image img) async => (await img.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();

  /// Cuts a picture down to its ink (+ a small margin).
  static Future<ui.Image> _trim(ui.Image img) async {
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return img;
    final w = img.width, h = img.height;
    var x0 = w, y0 = h, x1 = -1, y1 = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (data.getUint8((y * w + x) * 4 + 3) > 8) { x0 = math.min(x0, x); x1 = math.max(x1, x); y0 = math.min(y0, y); y1 = math.max(y1, y); }
      }
    }
    if (x1 < 0) return img;
    const pad = 8;
    x0 = math.max(0, x0 - pad); y0 = math.max(0, y0 - pad); x1 = math.min(w - 1, x1 + pad); y1 = math.min(h - 1, y1 + pad);
    final rec = ui.PictureRecorder();
    Canvas(rec).drawImageRect(img, Rect.fromLTRB(x0.toDouble(), y0.toDouble(), x1 + 1.0, y1 + 1.0), Rect.fromLTWH(0, 0, (x1 - x0 + 1).toDouble(), (y1 - y0 + 1).toDouble()), Paint());
    return rec.endRecording().toImage(x1 - x0 + 1, y1 - y0 + 1);
  }

  Future<ui.Image?> _typedImage(String text, String font) async {
    if (text.trim().isEmpty) return null;
    final style = GoogleFonts.getFont(font, fontSize: 120, color: _ink);
    try { await GoogleFonts.pendingFonts([style]); } catch (_) { /* the fallback still writes */ }
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    final rec = ui.PictureRecorder();
    tp.paint(Canvas(rec), const Offset(40, 40));
    final img = await rec.endRecording().toImage((tp.width + 80).ceil(), (tp.height + 80).ceil());
    return _trim(img);
  }

  /// A photo of a signature: smaller, the paper made transparent (light pixels fade out), trimmed.
  static Future<ui.Image?> _photoImage(Uint8List bytes) async {
    final probe = await (await ui.instantiateImageCodec(bytes)).getNextFrame();
    final k = math.min(1.0, 1200 / probe.image.width);
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: (probe.image.width * k).round());
    final img = (await codec.getNextFrame()).image;
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final px = data.buffer.asUint8List();
    final hist = List<int>.filled(256, 0);
    for (var i = 0; i < px.length; i += 4) { hist[(0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2]).round().clamp(0, 255)]++; }
    var acc = 0, paper = 255;
    for (var v = 255; v >= 0; v--) { acc += hist[v]; if (acc > px.length / 8) { paper = v; break; } }
    final hi = math.max(60, paper - 25), lo = math.max(20, hi - 90);
    for (var i = 0; i < px.length; i += 4) {
      final l = 0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2];
      final a = l >= hi ? 0 : l <= lo ? 255 : (255 * (hi - l) / (hi - lo)).round();
      px[i + 3] = math.min(px[i + 3], a);
    }
    final done = await _fromPixels(px, img.width, img.height);
    return _trim(done);
  }

  static Future<ui.Image> _fromPixels(Uint8List px, int w, int h) async {
    final buf = await ui.ImmutableBuffer.fromUint8List(px);
    final desc = ui.ImageDescriptor.raw(buf, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
    return (await (await desc.instantiateCodec()).getNextFrame()).image;
  }

  /// The signature with a line, the name in bold, the title and today's date under it.
  Future<ui.Image> _withLine(ui.Image sig) async {
    const scale = 3.0;
    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    TextPainter text(String s, {bool bold = false, double size = 15}) => TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size * scale, color: const Color(0xFF111111), fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      textDirection: TextDirection.ltr)..layout();
    final lines = [
      if (_name.text.trim().isNotEmpty) text(_name.text.trim(), bold: true),
      if (_title.text.trim().isNotEmpty) text(_title.text.trim(), size: 13),
      text(date, size: 13),
    ];
    final sigW = 220 * scale, sigH = sigW * sig.height / sig.width;
    final width = [sigW, ...lines.map((l) => l.width)].reduce(math.max) + 8;
    final height = sigH + 10 * scale + lines.fold<double>(0, (a, l) => a + l.height + 2 * scale) + 4;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawImageRect(sig, Rect.fromLTWH(0, 0, sig.width.toDouble(), sig.height.toDouble()), Rect.fromLTWH(0, 0, sigW, sigH), Paint()..filterQuality = FilterQuality.high);
    var y = sigH + 4 * scale;
    c.drawLine(Offset(0, y), Offset(math.max(sigW, 200 * scale), y), Paint()..color = const Color(0xFF333333)..strokeWidth = 1.2 * scale);
    y += 6 * scale;
    for (final l in lines) { l.paint(c, Offset(0, y)); y += l.height + 2 * scale; }
    return rec.endRecording().toImage(width.ceil(), height.ceil());
  }

  // ---------------------------------------------------------------- actions

  Future<ui.Image?> _make() async {
    switch (_mode) {
      case 0:
        if (!_hasStrokes) return null;
        return _trim(await _padKey.currentState!.toImage(pixelRatio: 3.0));
      case 1:
        return _typedImage(_typed.text.isNotEmpty ? _typed.text : _name.text, _font);
      default:
        return _photo == null ? null : _photoImage(_photo!);
    }
  }

  Future<void> _use({bool initials = false}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = ''; });
    try {
      ui.Image? img;
      if (initials) {
        final ini = initialsOf(_name.text.isNotEmpty ? _name.text : _typed.text);
        if (ini.isEmpty) { setState(() => _error = tr('Type your name first.')); return; }
        img = await _typedImage(ini, _font);
      } else {
        img = await _make();
        if (img == null) {
          setState(() => _error = tr(_mode == 0 ? 'Sign inside the box with your finger' : _mode == 1 ? 'Type your name first.' : 'Choose a photo of your signature first.'));
          return;
        }
        final plain = await _png(img);
        if (plain != null) await _keep(plain);
        if (_line) img = await _withLine(img);
      }
      final png = img == null ? null : await _png(img);
      if (png != null && mounted) Navigator.pop(context, png);
    } catch (_) {
      if (mounted) setState(() => _error = tr('This photo could not be read. Try a JPG or PNG.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useSaved(Uint8List png) async {
    if (!_line) { Navigator.pop(context, png); return; }
    final img = (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;
    final out = await _png(await _withLine(img));
    if (out != null && mounted) Navigator.pop(context, out);
  }

  Future<void> _pickPhoto() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f == null) return;
    final b = await f.readAsBytes();
    setState(() { _photo = b; _error = ''; });
  }

  // ---------------------------------------------------------------- view

  Widget _field(TextEditingController c, String label) => TextField(
    controller: c, maxLength: 80,
    decoration: InputDecoration(labelText: label, counterText: '', isDense: true, border: const OutlineInputBorder()),
    onChanged: (_) => setState(() {}),
  );

  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withValues(alpha: 0.5);
    final sample = _typed.text.isNotEmpty ? _typed.text : (_name.text.isNotEmpty ? _name.text : tr('Your name'));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.darkBorder, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(tr('Your Signature'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(tr('Kept only on this device, never sent.'), style: TextStyle(fontSize: 12.5, color: muted)),
              const SizedBox(height: 12),

              if (_saved.isNotEmpty) ...[
                Text(tr('My signatures'), style: TextStyle(fontSize: 12.5, color: muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 70,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(top: 6, right: 6),
                    itemCount: _saved.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => Stack(clipBehavior: Clip.none, children: [
                      InkWell(
                        onTap: () => _useSaved(_saved[i]),
                        child: Container(
                          width: 150, height: 58, padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: i == 0 ? AppTheme.brandGold : Colors.white24, width: 1.5)),
                          child: Image.memory(_saved[i], fit: BoxFit.contain),
                        ),
                      ),
                      Positioned(right: -6, top: -6, child: InkWell(
                        onTap: () async { setState(() => _saved.removeAt(i)); await _box.put(_listKey, _saved); if (_saved.isEmpty) await _box.delete(_oldKey); },
                        child: Tooltip(message: tr('Delete this signature'),
                          child: const CircleAvatar(radius: 11, backgroundColor: Colors.black87, child: Icon(Icons.close, size: 14, color: Colors.white))),
                      )),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, icon: const Icon(Icons.draw_rounded, size: 18), label: Text(tr('Draw'))),
                  ButtonSegment(value: 1, icon: const Icon(Icons.keyboard_rounded, size: 18), label: Text(tr('Type'))),
                  ButtonSegment(value: 2, icon: const Icon(Icons.image_rounded, size: 18), label: Text(tr('Import'))),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() { _mode = s.first; _error = ''; }),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(_name, tr('Name'))),
                const SizedBox(width: 10),
                Expanded(child: _field(_title, tr('Title (optional)'))),
              ]),
              const SizedBox(height: 12),

              if (_mode == 0) Container(
                height: 200,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(children: [
                    Positioned(left: 20, right: 20, bottom: 50, child: Container(height: 1, color: Colors.black12)),
                    if (!_hasStrokes) Center(child: Text(tr('Sign inside the box with your finger'), style: const TextStyle(color: Colors.black38, fontSize: 13))),
                    SfSignaturePad(
                      key: _padKey,
                      backgroundColor: Colors.transparent,
                      strokeColor: _ink,
                      minimumStrokeWidth: 1.5,
                      maximumStrokeWidth: 4.0,
                      onDrawEnd: () => setState(() => _hasStrokes = true),
                    ),
                  ]),
                ),
              ),

              if (_mode == 1) ...[
                _field(_typed, tr('Text to write')),
                const SizedBox(height: 10),
                Text(tr('21 handwriting styles'), style: TextStyle(fontSize: 12.5, color: muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 230,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, mainAxisExtent: 70, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    itemCount: signatureFonts.length,
                    itemBuilder: (_, i) {
                      final f = signatureFonts[i];
                      return InkWell(
                        onTap: () => setState(() => _font = f),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _font == f ? AppTheme.brandGold : Colors.white24, width: _font == f ? 2.5 : 1)),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            // The sample always fits its tile (no cut name).
                            Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text(sample, maxLines: 1, style: GoogleFonts.getFont(f, fontSize: 26, color: _ink)))),
                            FittedBox(fit: BoxFit.scaleDown, child: Text(f, maxLines: 1, style: const TextStyle(fontSize: 10, color: Colors.black54))),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ],

              if (_mode == 2) ...[
                OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: Text(_photo == null ? tr('Choose a photo of my signature…') : tr('Choose another photo…')),
                ),
                const SizedBox(height: 6),
                Text(tr('Sign in dark ink on white paper, take a photo, and the paper becomes transparent.'), style: TextStyle(fontSize: 12, color: muted)),
                if (_photo != null) Container(
                  margin: const EdgeInsets.only(top: 10), height: 110, padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Image.memory(_photo!, fit: BoxFit.contain),
                ),
              ],
              const SizedBox(height: 12),

              Row(children: [
                for (final c in const [Color(0xFF0D1B4C), Colors.black, Color(0xFF1565C0), Color(0xFF8B1A1A)])
                  GestureDetector(
                    onTap: () => setState(() => _ink = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: c, shape: BoxShape.circle,
                        border: Border.all(color: _ink == c ? AppTheme.brandGold : Colors.white24, width: _ink == c ? 2.5 : 1),
                      ),
                    ),
                  ),
                const Spacer(),
                if (_mode == 0) TextButton.icon(
                  onPressed: () { _padKey.currentState?.clear(); setState(() => _hasStrokes = false); },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(tr('Clear')),
                ),
              ]),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _line,
                onChanged: (v) => setState(() => _line = v),
                title: Text(tr('Signature line (signature, name, title, date)'), style: const TextStyle(fontSize: 14)),
              ),
              if (_error.isNotEmpty) Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error, style: const TextStyle(color: Color(0xFFEF5350), fontWeight: FontWeight.w600)),
              ),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: _busy ? null : () => _use(initials: true),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(tr('Place my initials'), textAlign: TextAlign.center),
                )),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: FilledButton.icon(
                  onPressed: _busy ? null : () => _use(),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(tr('Use this signature'), textAlign: TextAlign.center),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
