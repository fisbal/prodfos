import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════════
// ProDFOS 3D — dimensional buttons with tiny living scenes.
//
// • Tilt3D      — perspective tilt that follows the pointer, sinks on press
// • Button3D    — extruded pill button (gold or obsidian) that physically
//                 presses down onto its base
// • SceneTile   — obsidian slab with thickness, rim light and a miniature
//                 animated isometric scene (pages, pens, scanner beams…)
// • AiOrb       — DocMind™ orb: glowing sphere with orbiting particles
//
// Everything is drawn in code (no image assets) so it stays razor sharp
// on phones, 4K monitors and the web.
// ══════════════════════════════════════════════════════════════════

/// The miniature scenes available for tiles.
enum Scene { edit, merge, split, tools, scan, extract, images, text, ai, open }

// ── Tilt + press physics ─────────────────────────────────────────
class Tilt3D extends StatefulWidget {
  final Widget Function(BuildContext context, bool pressed, Offset tilt) builder;
  final VoidCallback? onTap;
  final double maxTilt; // radians
  const Tilt3D({super.key, required this.builder, this.onTap, this.maxTilt = 0.16});

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> {
  Offset _tilt = Offset.zero; // -1..1 in both axes
  bool _pressed = false;

  void _track(Offset local) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    final dx = (local.dx / size.width) * 2 - 1;
    final dy = (local.dy / size.height) * 2 - 1;
    setState(() => _tilt = Offset(dx.clamp(-1.0, 1.0), dy.clamp(-1.0, 1.0)));
  }

  @override
  Widget build(BuildContext context) {
    // No LayoutBuilder here: tiles must also work inside IntrinsicHeight rows.
    return MouseRegion(
        cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        onHover: (e) => _track(e.localPosition),
        onExit: (_) => setState(() => _tilt = Offset.zero),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) { _track(d.localPosition); setState(() => _pressed = true); },
          onTapUp: (_) => setState(() { _pressed = false; _tilt = Offset.zero; }),
          onTapCancel: () => setState(() { _pressed = false; _tilt = Offset.zero; }),
          onTap: widget.onTap,
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(end: _tilt),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => TweenAnimationBuilder<double>(
              tween: Tween(end: _pressed ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              builder: (context, p, _) {
                final m = Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..rotateX(-t.dy * widget.maxTilt)
                  ..rotateY(t.dx * widget.maxTilt)
                  ..multiply(Matrix4.diagonal3Values(1 - 0.035 * p, 1 - 0.035 * p, 1));
                return Transform(
                  alignment: Alignment.center,
                  transform: m,
                  child: widget.builder(context, p > 0.5, t),
                );
              },
            ),
          ),
        ),
      );
  }
}

// ── Extruded pill button ─────────────────────────────────────────
class Button3D extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool gold;
  const Button3D({super.key, required this.label, required this.icon, required this.onTap, this.gold = true});

  static const double _depth = 6;

  @override
  Widget build(BuildContext context) {
    final faceTop = gold ? AppTheme.brandGoldLight : const Color(0xFF2A2A34);
    final faceBottom = gold ? AppTheme.brandGold : const Color(0xFF15151C);
    final base = gold ? AppTheme.brandGoldDark : const Color(0xFF07070A);
    final fg = gold ? const Color(0xFF1A1406) : AppTheme.cream;

    return Opacity(opacity: onTap == null ? 0.45 : 1, child: Tilt3D(
      onTap: onTap,
      maxTilt: 0.10,
      builder: (context, pressed, tilt) {
        final sink = pressed ? _depth - 1.5 : 0.0;
        return Stack(clipBehavior: Clip.none, children: [
          // Floor shadow — tightens when pressed
          Positioned(
            left: 12, right: 12, bottom: 0, height: 26,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: (gold ? AppTheme.brandGold : Colors.black).withValues(alpha: pressed ? 0.25 : 0.45),
                    blurRadius: pressed ? 12 : 26,
                    offset: Offset(-tilt.dx * 6, pressed ? 2 : 10),
                  ),
                ],
              ),
            ),
          ),
          // Extrusion (the button's thickness)
          Positioned(
            left: 0, right: 0, top: _depth, bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [base, Color.lerp(base, Colors.black, 0.45)!],
                ),
                border: gold ? null : Border.all(color: AppTheme.brandGold.withValues(alpha: 0.25)),
              ),
            ),
          ),
          // Face — sizes the whole button and sinks onto the base when pressed
          AnimatedPadding(
            duration: const Duration(milliseconds: 110),
            padding: EdgeInsets.only(top: sink, bottom: _depth - sink),
            child: Container(
              height: 54,
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment(-0.6 + tilt.dx * 0.4, -1), end: const Alignment(0.6, 1),
                  colors: [faceTop, faceBottom],
                ),
                border: Border.all(
                  color: gold ? Colors.white.withValues(alpha: 0.35) : AppTheme.brandGold.withValues(alpha: 0.45),
                ),
              ),
              child: Stack(alignment: Alignment.center, children: [
                // Glossy top highlight
                Positioned(
                  left: -22, right: -22, top: 0, height: 26,
                  child: DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: gold ? 0.40 : 0.09), Colors.white.withValues(alpha: 0)],
                    ),
                  )),
                ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 21, color: fg, shadows: [
                    Shadow(color: gold ? Colors.white.withValues(alpha: 0.5) : Colors.black,
                        offset: const Offset(0, 1), blurRadius: 1),
                  ]),
                  const SizedBox(width: 8),
                  Text(label, style: AppTheme.body(15.5, weight: FontWeight.w700, color: fg).copyWith(
                    shadows: [Shadow(color: gold ? Colors.white.withValues(alpha: 0.45) : Colors.black,
                        offset: const Offset(0, 1), blurRadius: 1)],
                  )),
                ]),
              ]),
            ),
          ),
        ]);
      },
    ));
  }
}

// ── Obsidian slab tile with a living scene ────────────────────────
class SceneTile extends StatelessWidget {
  final Scene scene;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color accent;
  final double sceneHeight;
  final bool large;

  const SceneTile({
    super.key,
    required this.scene,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.accent = AppTheme.brandGold,
    this.sceneHeight = 48,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = large ? 22.0 : 18.0;
    const depth = 5.0;
    return Tilt3D(
      onTap: onTap,
      maxTilt: large ? 0.12 : 0.20,
      builder: (context, pressed, tilt) {
        final sink = pressed ? depth - 1 : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: depth),
          child: Stack(clipBehavior: Clip.none, fit: StackFit.passthrough, children: [
            // Thickness + cast shadow
            Positioned.fill(
              top: depth, bottom: -depth,
              child: DecoratedBox(decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r),
                color: const Color(0xFF050507),
                border: Border.all(color: accent.withValues(alpha: 0.18)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: pressed ? 8 : 22, offset: Offset(-tilt.dx * 5, pressed ? 3 : 12)),
                  BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 30, spreadRadius: -6),
                ],
              )),
            ),
            // Face
            AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              transform: Matrix4.translationValues(0, sink, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r),
                gradient: LinearGradient(
                  begin: Alignment(-0.8 + tilt.dx * 0.5, -1 + tilt.dy * 0.3),
                  end: const Alignment(0.8, 1),
                  colors: const [Color(0xFF262630), Color(0xFF15151C), Color(0xFF0E0E13)],
                  stops: const [0, 0.55, 1],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r),
                // Rim light catching the top edge
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: const Alignment(0, -0.82),
                  colors: [accent.withValues(alpha: 0.11), accent.withValues(alpha: 0)],
                ),
              ),
              padding: large
                  ? const EdgeInsets.fromLTRB(18, 16, 18, 18)
                  : const EdgeInsets.fromLTRB(8, 10, 8, 11),
              child: Column(
                crossAxisAlignment: large ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: sceneHeight,
                    width: double.infinity,
                    child: SceneView(scene: scene, accent: accent, parallax: tilt),
                  ),
                  SizedBox(height: large ? 14 : 6),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: large
                          ? AppTheme.display(20, height: 1.15)
                          : AppTheme.body(11.5, weight: FontWeight.w600, color: AppTheme.cream.withValues(alpha: 0.85))),
                  if (subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(12, color: AppTheme.creamFaint, height: 1.35)),
                  ],
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── Animated scene host ───────────────────────────────────────────
class SceneView extends StatefulWidget {
  final Scene scene;
  final Color accent;
  final Offset parallax;
  /// Faster, brighter animation (DocMind thinking).
  final bool active;
  const SceneView({super.key, required this.scene, this.accent = AppTheme.brandGold,
      this.parallax = Offset.zero, this.active = false});

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: _duration)..repeat();

  Duration get _duration => Duration(milliseconds: widget.active ? 1300 : 4200);

  @override
  void didUpdateWidget(covariant SceneView old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      _c.duration = _duration;
      _c.repeat();
    }
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ScenePainter(widget.scene, _c, widget.accent, widget.parallax, active: widget.active),
        size: Size.infinite,
      ),
    );
  }
}

/// DocMind™ AI orb — usable on its own.
class AiOrb extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;
  final bool thinking;
  const AiOrb({super.key, this.size = 64, this.onTap, this.thinking = false});

  @override
  Widget build(BuildContext context) {
    final orb = SizedBox(width: size, height: size, child: SceneView(scene: Scene.ai, active: thinking));
    if (onTap == null) return orb;
    return Tilt3D(onTap: onTap, maxTilt: 0.25, builder: (_, __, ___) => orb);
  }
}

// ══════════════════════════════════════════════════════════════════
// Painter — tiny isometric world
// ══════════════════════════════════════════════════════════════════
class _Iso {
  final Offset o;
  final double s;
  const _Iso(this.o, this.s);
  Offset p(double x, double y, double z) =>
      o + Offset((x - y) * 0.866 * s, (x + y) * 0.5 * s - z * s);
  Path quad(List<Offset> pts) => Path()..addPolygon(pts, true);
}

class _ScenePainter extends CustomPainter {
  final Scene scene;
  final Animation<double> t;
  final Color accent;
  final Offset parallax;
  final bool active;
  _ScenePainter(this.scene, this.t, this.accent, this.parallax, {this.active = false}) : super(repaint: t);

  static const _paper = Color(0xFFF4F0E6);
  static const _paperSide = Color(0xFFCFC7B4);
  static const _paperEdge = Color(0xFFB3AA95);
  static const _ink = Color(0x33000000);

  double get v => t.value; // 0..1 loop
  double wave([double phase = 0]) => math.sin((v + phase) * 2 * math.pi);
  double ease(double x) => 0.5 - 0.5 * math.cos(x.clamp(0.0, 1.0) * math.pi);
  double pingPong([double phase = 0]) => ease(0.5 - 0.5 * math.cos((v + phase) * 2 * math.pi));

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.translate(parallax.dx * 2.5, parallax.dy * 2);
    switch (scene) {
      case Scene.ai: _ai(canvas, size); break;
      default: _isoScene(canvas, size);
    }
    canvas.restore();
  }

  // Fit a scene whose footprint is (w x d) units into the box.
  _Iso _fit(Size size, double w, double d, {double lift = 0.3}) {
    final s = math.min(size.width / ((w + d) * 0.866 + 0.15), size.height / ((w + d) * 0.5 + lift * 0.6 + 0.12));
    final center = Offset(size.width / 2, size.height * (0.52 + 0.08 * lift));
    final c = Offset((w - d) / 2 * 0.866 * s, (w + d) / 2 * 0.5 * s);
    return _Iso(center - c, s);
  }

  void _isoScene(Canvas canvas, Size size) {
    switch (scene) {
      case Scene.edit: _edit(canvas, size); break;
      case Scene.merge: _merge(canvas, size); break;
      case Scene.split: _split(canvas, size); break;
      case Scene.tools: _tools(canvas, size); break;
      case Scene.scan: _scan(canvas, size); break;
      case Scene.extract: _extract(canvas, size); break;
      case Scene.images: _images(canvas, size); break;
      case Scene.text: _text(canvas, size); break;
      case Scene.open: _open(canvas, size); break;
      case Scene.ai: break;
    }
  }

  // ── primitives ─────────────────────────────────────────────
  void _shadow(Canvas c, _Iso iso, double x, double y, double w, double d, {double alpha = 0.55, double z = 0}) {
    final center = iso.p(x + w / 2, y + d / 2, 0);
    final rx = (w + d) * 0.866 * iso.s * 0.55;
    final ry = (w + d) * 0.5 * iso.s * 0.55;
    final fade = (1 - z * 0.8).clamp(0.25, 1.0);
    c.drawOval(
      Rect.fromCenter(center: center + Offset(0, iso.s * 0.08), width: rx * 2, height: ry * 2),
      Paint()
        ..color = Colors.black.withValues(alpha: alpha * fade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, iso.s * (0.18 + z * 0.3)),
    );
  }

  /// Box with lit top, mid-tone left (+y) face and dark right (+x) face.
  void _box(Canvas c, _Iso iso, double x, double y, double z, double w, double d, double h,
      {required Color top, Color? left, Color? right, Color? topEnd}) {
    final l = left ?? Color.lerp(top, Colors.black, 0.22)!;
    final r = right ?? Color.lerp(top, Colors.black, 0.40)!;
    final pLeft = iso.quad([iso.p(x, y + d, z), iso.p(x + w, y + d, z), iso.p(x + w, y + d, z + h), iso.p(x, y + d, z + h)]);
    final pRight = iso.quad([iso.p(x + w, y, z), iso.p(x + w, y + d, z), iso.p(x + w, y + d, z + h), iso.p(x + w, y, z + h)]);
    final pTop = iso.quad([iso.p(x, y, z + h), iso.p(x + w, y, z + h), iso.p(x + w, y + d, z + h), iso.p(x, y + d, z + h)]);
    c.drawPath(pLeft, Paint()..color = l);
    c.drawPath(pRight, Paint()..color = r);
    final a = iso.p(x, y, z + h), b = iso.p(x + w, y + d, z + h);
    c.drawPath(pTop, Paint()..shader = LinearGradient(colors: [top, topEnd ?? Color.lerp(top, Colors.black, 0.08)!])
        .createShader(Rect.fromPoints(a, b)));
    c.drawPath(pTop, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.white.withValues(alpha: 0.35));
  }

  /// A sheet of paper with text lines. `lines` = how much of the last line is written (0..1).
  void _page(Canvas c, _Iso iso, double x, double y, double z,
      {double w = 1.0, double d = 1.3, Color? tint, int rows = 5, double lastLine = 1, bool header = true}) {
    const h = 0.05;
    _box(c, iso, x, y, z, w, d, h,
        top: tint ?? _paper, left: _paperSide, right: _paperEdge, topEnd: Color.lerp(tint ?? _paper, Colors.black, 0.06));
    final lineP = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.0, iso.s * 0.045);
    final top = z + h;
    if (header) {
      c.drawLine(iso.p(x + 0.14, y + 0.16, top), iso.p(x + w * 0.62, y + 0.16, top),
          lineP..color = accent.withValues(alpha: 0.95)..strokeWidth = math.max(1.4, iso.s * 0.08));
    }
    lineP.strokeWidth = math.max(1.0, iso.s * 0.045);
    for (int k = 0; k < rows; k++) {
      final yy = y + 0.36 + k * (d - 0.5) / rows;
      final full = k.isOdd ? w * 0.72 : w * 0.86;
      final len = (k == rows - 1) ? full * lastLine : full;
      if (len <= 0.02) continue;
      c.drawLine(iso.p(x + 0.14, yy, top), iso.p(x + 0.14 + len - 0.14, yy, top), lineP..color = _ink);
    }
  }

  // ── scenes ─────────────────────────────────────────────────
  void _edit(Canvas c, Size size) {
    final iso = _fit(size, 1.0, 1.3, lift: 0.7);
    _shadow(c, iso, 0, 0, 1.0, 1.3);
    final write = (v * 1.25).clamp(0.0, 1.0);
    _page(c, iso, 0, 0, 0, lastLine: write);
    // Gold pen writing the last line
    const rows = 5;
    final yy = 0.36 + (rows - 1) * (1.3 - 0.5) / rows;
    final len = 0.86 * write;
    final tip = iso.p(0.14 + math.max(0.0, len - 0.14), yy, 0.05 + 0.02 + (write < 1 ? 0 : 0.15 * ease((v - 0.8) * 5)));
    final dir = Offset(0.55, -1.0) * iso.s * 0.9;
    final end = tip + dir;
    final pen = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = iso.s * 0.17
      ..shader = LinearGradient(colors: [AppTheme.brandGoldDark, AppTheme.brandGoldLight, AppTheme.brandGold])
          .createShader(Rect.fromPoints(tip, end));
    // pen shadow on page
    c.drawLine(tip + Offset(iso.s * 0.1, iso.s * 0.02), tip + Offset(dir.dx * 0.9 + iso.s * 0.35, iso.s * 0.15),
        Paint()..color = Colors.black.withValues(alpha: 0.18)..strokeWidth = iso.s * 0.12..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, iso.s * 0.05));
    c.drawLine(tip + dir * 0.18, end, pen);
    c.drawLine(tip, tip + dir * 0.2, Paint()..color = const Color(0xFF2B2B33)..strokeWidth = iso.s * 0.1..strokeCap = StrokeCap.round);
    c.drawCircle(tip + dir * 0.75, iso.s * 0.035, Paint()..color = Colors.white.withValues(alpha: 0.7));
  }

  void _merge(Canvas c, Size size) {
    final iso = _fit(size, 1.9, 1.3, lift: 0.6);
    final p = pingPong();
    final ax = 0.9 * (1 - p) + 0.45 * p, bx = 0.0 * (1 - p) + 0.45 * p;
    final az = 0.0 * (1 - p) + 0.10 * p + 0.25 * math.sin(p * math.pi);
    _shadow(c, iso, bx, 0, 1.0, 1.3);
    _shadow(c, iso, ax, 0, 1.0, 1.3, z: az);
    _page(c, iso, bx, 0, 0, rows: 4);
    _page(c, iso, ax, 0, az, rows: 4, tint: const Color(0xFFFFF4D6));
    if (p > 0.92) _sparkle(c, iso.p(0.95, 0.65, 0.5), iso.s * 0.22 * ((p - 0.92) / 0.08));
  }

  void _split(Canvas c, Size size) {
    final iso = _fit(size, 1.9, 1.3, lift: 0.6);
    final p = pingPong(0.25);
    final ax = 0.45 - 0.45 * p, bx = 0.45 + 0.45 * p;
    final bz = 0.08 * (1 - p) + 0.25 * math.sin(p * math.pi);
    _shadow(c, iso, ax, 0, 1.0, 1.3);
    _shadow(c, iso, bx, 0, 1.0, 1.3, z: bz);
    _page(c, iso, ax, 0, 0, rows: 4);
    _page(c, iso, bx, 0, bz, rows: 2, tint: const Color(0xFFFFF4D6));
  }

  void _tools(Canvas c, Size size) {
    final iso = _fit(size, 1.6, 1.6, lift: 0.9);
    final colors = [AppTheme.brandGold, const Color(0xFF3A3A46), const Color(0xFF3A3A46), _paper];
    final order = [0, 1, 2, 3];
    for (final i in order) {
      final gx = (i % 2) * 0.85, gy = (i ~/ 2) * 0.85;
      final z = 0.12 + 0.18 * (0.5 + 0.5 * wave(i * 0.23));
      _shadow(c, iso, gx, gy, 0.7, 0.7, z: z, alpha: 0.45);
    }
    for (final i in order) {
      final gx = (i % 2) * 0.85, gy = (i ~/ 2) * 0.85;
      final z = 0.12 + 0.18 * (0.5 + 0.5 * wave(i * 0.23));
      _box(c, iso, gx, gy, z, 0.7, 0.7, 0.42, top: i == 0 ? AppTheme.brandGoldLight : colors[i],
          topEnd: i == 0 ? AppTheme.brandGold : null);
    }
  }

  void _scan(Canvas c, Size size) {
    final iso = _fit(size, 1.0, 1.3, lift: 0.6);
    _shadow(c, iso, 0, 0, 1.0, 1.3);
    _page(c, iso, 0, 0, 0);
    final y = 0.05 + 1.2 * pingPong();
    const z = 0.22;
    // light sheet hitting the page
    final a = iso.p(-0.08, y, 0.06), b = iso.p(1.08, y, 0.06);
    final a2 = iso.p(-0.08, y, z), b2 = iso.p(1.08, y, z);
    c.drawPath(iso.quad([a, b, b2, a2]), Paint()
      ..shader = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [accent.withValues(alpha: 0.55), accent.withValues(alpha: 0)])
          .createShader(Rect.fromPoints(a2, b)));
    c.drawLine(a, b, Paint()
      ..color = accent
      ..strokeWidth = iso.s * 0.06
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, iso.s * 0.08));
    c.drawLine(a, b, Paint()..color = Colors.white.withValues(alpha: 0.9)..strokeWidth = math.max(1, iso.s * 0.02));
    // scanner bar body
    _box(c, iso, -0.1, y - 0.04, z, 1.2, 0.08, 0.06, top: const Color(0xFF3A3A46));
  }

  void _extract(Canvas c, Size size) {
    final iso = _fit(size, 1.0, 1.3, lift: 1.0);
    _shadow(c, iso, 0, 0, 1.0, 1.3);
    _page(c, iso, 0, 0, 0, header: false);
    // Letters lifting off the page as glowing tiles
    for (int i = 0; i < 3; i++) {
      final ph = (v + i / 3) % 1.0;
      final z = 0.1 + ph * 0.9;
      final alpha = (1 - ph) * math.min(1, ph * 4);
      final x = 0.18 + i * 0.26, y = 0.45 + i * 0.12;
      final pos = iso.p(x, y, z);
      final r = iso.s * 0.15;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: pos, width: r * 2, height: r * 1.6), Radius.circular(r * 0.35)),
          Paint()..color = accent.withValues(alpha: 0.9 * alpha));
      final tp = TextPainter(
        text: TextSpan(text: 'TAg'[i], style: TextStyle(color: Colors.black.withValues(alpha: alpha), fontSize: r * 1.2, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _images(Canvas c, Size size) {
    final iso = _fit(size, 1.9, 1.3, lift: 0.7);
    final p = pingPong(0.1);
    _shadow(c, iso, 0.8, 0, 1.0, 1.3);
    _page(c, iso, 0.8, 0, 0, rows: 3, header: false);
    // photo card sliding onto the page
    final px = 0.0 + 0.85 * p, pz = 0.35 * math.sin(p * math.pi) + 0.06 * p;
    _shadow(c, iso, px, 0.15, 0.9, 0.75, z: pz, alpha: 0.4);
    _box(c, iso, px, 0.15, pz, 0.9, 0.75, 0.04, top: const Color(0xFF6FA8DC), topEnd: const Color(0xFF2E5E8C));
    final top = pz + 0.04;
    final m = iso.quad([iso.p(px + 0.08, 0.15 + 0.7, top), iso.p(px + 0.38, 0.15 + 0.3, top), iso.p(px + 0.6, 0.15 + 0.7, top)]);
    c.drawPath(m, Paint()..color = const Color(0xFF2F6B3A));
    final m2 = iso.quad([iso.p(px + 0.42, 0.15 + 0.7, top), iso.p(px + 0.62, 0.15 + 0.42, top), iso.p(px + 0.85, 0.15 + 0.7, top)]);
    c.drawPath(m2, Paint()..color = const Color(0xFF3F8A4C));
    c.drawCircle(iso.p(px + 0.7, 0.15 + 0.2, top), iso.s * 0.08, Paint()..color = AppTheme.brandGoldLight);
  }

  void _text(Canvas c, Size size) {
    final iso = _fit(size, 1.0, 1.3, lift: 0.5);
    _shadow(c, iso, 0, 0, 1.0, 1.3);
    final typed = (v * 1.3).clamp(0.0, 1.0);
    _page(c, iso, 0, 0, 0, rows: 4, lastLine: typed);
    // blinking caret
    if ((v * 6).floor().isEven) {
      final yy = 0.36 + 3 * (1.3 - 0.5) / 4;
      final x = 0.14 + math.max(0.0, 0.72 * typed - 0.14);
      c.drawLine(iso.p(x + 0.04, yy, 0.05), iso.p(x + 0.04, yy, 0.2),
          Paint()..color = accent..strokeWidth = math.max(1.2, iso.s * 0.05)..strokeCap = StrokeCap.round);
    }
  }

  void _open(Canvas c, Size size) {
    final iso = _fit(size, 1.0, 1.3, lift: 0.8);
    final z = 0.15 + 0.12 * (0.5 + 0.5 * wave());
    _shadow(c, iso, 0, 0, 1.0, 1.3, z: z);
    _page(c, iso, 0, 0, z, tint: const Color(0xFFFFF4D6));
  }

  void _sparkle(Canvas c, Offset at, double r) {
    if (r <= 0) return;
    final p = Paint()..color = Colors.white.withValues(alpha: 0.9);
    final path = Path()
      ..moveTo(at.dx, at.dy - r)..quadraticBezierTo(at.dx, at.dy, at.dx + r, at.dy)
      ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + r)..quadraticBezierTo(at.dx, at.dy, at.dx - r, at.dy)
      ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - r)..close();
    c.drawPath(path, p);
  }

  // ── DocMind AI orb ─────────────────────────────────────────
  void _ai(Canvas c, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * 0.30;
    final pulse = 1 + (active ? 0.09 : 0.04) * wave();
    const violet = Color(0xFF6C5CE7);

    // halo
    c.drawCircle(center, r * 1.9 * pulse, Paint()
      ..shader = RadialGradient(colors: [violet.withValues(alpha: active ? 0.6 : 0.35), accent.withValues(alpha: active ? 0.18 : 0.08), Colors.transparent],
          stops: const [0, 0.55, 1]).createShader(Rect.fromCircle(center: center, radius: r * 1.9 * pulse)));

    // orbit ring (tilted ellipse) — back half first
    final ring = Rect.fromCenter(center: center, width: r * 3.0, height: r * 0.95);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * 0.035)
      ..color = accent.withValues(alpha: 0.35);
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(-0.35);
    c.translate(-center.dx, -center.dy);
    c.drawArc(ring, math.pi, math.pi, false, ringPaint);
    _particles(c, ring, back: true, r: r);
    c.restore();

    // sphere
    final sphere = Rect.fromCircle(center: center, radius: r * pulse);
    c.drawCircle(center + Offset(0, r * 1.25), r * 0.8, Paint()
      ..color = Colors.black.withValues(alpha: 0.5)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3));
    c.drawCircle(center, r * pulse, Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 1.0,
        colors: [const Color(0xFFFFF1C9), AppTheme.brandGold, violet, const Color(0xFF1B1440)],
        stops: const [0, 0.28, 0.72, 1],
      ).createShader(sphere));
    // swirling inner light
    final ang = v * 2 * math.pi;
    c.drawCircle(center + Offset(math.cos(ang), math.sin(ang)) * r * 0.35, r * 0.45, Paint()
      ..color = Colors.white.withValues(alpha: 0.18)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3));
    // specular
    c.drawOval(Rect.fromCenter(center: center + Offset(-r * 0.35, -r * 0.45), width: r * 0.55, height: r * 0.32),
        Paint()..color = Colors.white.withValues(alpha: 0.75)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06));
    // rim
    c.drawCircle(center, r * pulse, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = math.max(1, r * 0.04)
      ..color = AppTheme.brandGoldLight.withValues(alpha: 0.5));

    // front half of the ring
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(-0.35);
    c.translate(-center.dx, -center.dy);
    c.drawArc(ring, 0, math.pi, false, ringPaint..color = accent.withValues(alpha: 0.7));
    _particles(c, ring, back: false, r: r);
    c.restore();
  }

  void _particles(Canvas c, Rect ring, {required bool back, required double r}) {
    for (int i = 0; i < 3; i++) {
      final a = (v + i / 3) * 2 * math.pi;
      final isBack = math.sin(a) < 0;
      if (isBack != back) continue;
      final pos = ring.center + Offset(math.cos(a) * ring.width / 2, math.sin(a) * ring.height / 2);
      final pr = r * (back ? 0.09 : 0.14);
      c.drawCircle(pos, pr * 2.2, Paint()..color = AppTheme.brandGoldLight.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, pr));
      c.drawCircle(pos, pr, Paint()..color = back ? AppTheme.brandGold.withValues(alpha: 0.6) : AppTheme.brandGoldLight);
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.scene != scene || old.accent != accent || old.parallax != parallax || old.active != active;
}


// ══════════════════════════════════════════════════════════════════
// Small 3D parts
// ══════════════════════════════════════════════════════════════════

/// Round extruded key — toolbar buttons, send button.
class Key3D extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final bool gold;
  final bool active;
  const Key3D({super.key, required this.icon, required this.onTap, this.tooltip,
      this.size = 40, this.gold = false, this.active = false});

  @override
  Widget build(BuildContext context) {
    const depth = 4.0;
    final faceTop = gold ? AppTheme.brandGoldLight : const Color(0xFF2C2C37);
    final faceBottom = gold ? AppTheme.brandGold : const Color(0xFF16161D);
    final base = gold ? AppTheme.brandGoldDark : const Color(0xFF040406);
    final fg = gold ? const Color(0xFF1A1406) : (active ? AppTheme.brandGold : AppTheme.cream.withValues(alpha: 0.88));
    final key = Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Tilt3D(
        onTap: onTap,
        maxTilt: 0.3,
        builder: (context, pressed, tilt) {
          final sink = pressed ? depth - 1 : 0.0;
          return SizedBox(
            width: size, height: size + depth,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0, right: 0, top: depth, height: size,
                child: DecoratedBox(decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: base,
                  border: Border.all(color: AppTheme.brandGold.withValues(alpha: gold ? 0 : 0.18)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: pressed ? 4 : 10, offset: Offset(0, pressed ? 2 : 5))],
                )),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 100),
                left: 0, right: 0, top: sink, height: size,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment(-0.6 + tilt.dx * 0.4, -1), end: const Alignment(0.6, 1),
                      colors: [faceTop, faceBottom],
                    ),
                    border: Border.all(color: active
                        ? AppTheme.brandGold.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: gold ? 0.35 : 0.09)),
                  ),
                  foregroundDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.35, -0.6), radius: 0.7,
                      colors: [Colors.white.withValues(alpha: gold ? 0.35 : 0.10), Colors.white.withValues(alpha: 0)],
                    ),
                  ),
                  child: Icon(icon, size: size * 0.48, color: fg),
                ),
              ),
            ]),
          );
        },
      ),
    );
    return tooltip == null ? key : Tooltip(message: tooltip!, child: key);
  }
}

/// Obsidian slab card with real thickness (settings groups, AI results).
class Slab3D extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accent;
  final double radius;
  const Slab3D({super.key, required this.child, this.padding = const EdgeInsets.all(16),
      this.accent = AppTheme.brandGold, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    const depth = 5.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: depth),
      child: Stack(clipBehavior: Clip.none, fit: StackFit.passthrough, children: [
        Positioned.fill(
          top: depth, bottom: -depth,
          child: DecoratedBox(decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: const Color(0xFF050507),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 22, offset: const Offset(0, 12))],
          )),
        ),
        Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: const LinearGradient(
              begin: Alignment(-0.8, -1), end: Alignment(0.8, 1),
              colors: [Color(0xFF23232C), Color(0xFF15151C), Color(0xFF0F0F14)],
              stops: [0, 0.5, 1],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: const Alignment(0, -0.85),
              colors: [accent.withValues(alpha: 0.10), accent.withValues(alpha: 0)],
            ),
          ),
          child: child,
        ),
      ]),
    );
  }
}

/// Small extruded pill — suggestions, choices.
class Chip3D extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color accent;
  const Chip3D({super.key, required this.label, required this.onTap, this.selected = false,
      this.accent = AppTheme.brandGold});

  @override
  Widget build(BuildContext context) {
    const depth = 3.0;
    return Tilt3D(
      onTap: onTap,
      maxTilt: 0.2,
      builder: (context, pressed, tilt) {
        final sink = pressed || selected ? depth - 1 : 0.0;
        return Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 0, right: 0, top: depth, bottom: 0,
            child: DecoratedBox(decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: selected ? Color.lerp(accent, Colors.black, 0.55) : const Color(0xFF050507),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            )),
          ),
          AnimatedPadding(
            duration: const Duration(milliseconds: 100),
            padding: EdgeInsets.only(top: sink, bottom: depth - sink),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: selected
                      ? [Color.lerp(accent, Colors.white, 0.35)!, accent]
                      : const [Color(0xFF2A2A34), Color(0xFF17171E)],
                ),
                border: Border.all(color: selected ? Colors.white.withValues(alpha: 0.3) : accent.withValues(alpha: 0.3)),
              ),
              child: Text(label, style: AppTheme.body(12.5, weight: FontWeight.w600,
                  color: selected ? const Color(0xFF1A1406) : AppTheme.cream.withValues(alpha: 0.85))),
            ),
          ),
        ]);
      },
    );
  }
}

/// Embossed icon chip used in lists (settings rows).
class IconChip3D extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconChip3D({super.key, required this.icon, this.color = AppTheme.brandGold, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.15)!.withValues(alpha: 0.32), color.withValues(alpha: 0.08)],
        ),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 8, offset: const Offset(0, 4)),
          BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 12, spreadRadius: -2),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.center,
          colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0)],
        ),
      ),
      child: Icon(icon, size: size * 0.5, color: color, shadows: [
        Shadow(color: Colors.black.withValues(alpha: 0.6), offset: const Offset(0, 1.5), blurRadius: 2),
      ]),
    );
  }
}
