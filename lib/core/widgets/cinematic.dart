import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════════════
// BACKDROP — nebula + film grain behind any content
// ══════════════════════════════════════════════════════════════════════
class CinematicBackdrop extends StatelessWidget {
  final Widget child;
  const CinematicBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: CinematicBackground()),
      Positioned.fill(child: child),
    ]);
  }
}

class CinematicBackground extends StatelessWidget {
  const CinematicBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(children: [
        Positioned.fill(child: _Nebula()),
        Positioned.fill(child: FilmGrain()),
      ]),
    );
  }
}

// ── Breathing gold nebula ─────────────────────────────────────────────
class _Nebula extends StatefulWidget {
  const _Nebula();
  @override
  State<_Nebula> createState() => _NebulaState();
}

class _NebulaState extends State<_Nebula> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: CustomPaint(painter: _NebulaPainter(_c)));
  }
}

class _NebulaPainter extends CustomPainter {
  final Animation<double> t;
  _NebulaPainter(this.t) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final v = Curves.easeInOut.transform(t.value);
    final full = Offset.zero & size;
    final w = size.width, h = size.height;

    canvas.drawRect(full, Paint()..color = AppTheme.voidBlack);

    void glow(Offset c, double r, Color color) {
      canvas.drawRect(full, Paint()
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: c, radius: r)));
    }

    // Gold nebula — top right, breathing
    glow(Offset(w * 0.88, h * 0.06 + v * 24), w * (0.80 + 0.08 * v),
        AppTheme.brandGold.withValues(alpha: 0.10 + 0.05 * v));
    // Deep bronze — bottom left
    glow(Offset(w * 0.08, h * 0.92 - v * 30), w * 0.75,
        const Color(0xFF8A5A1C).withValues(alpha: 0.07 + 0.04 * v));
    // Faint cream haze — center
    glow(Offset(w * 0.5, h * 0.42), w * 0.95, AppTheme.cream.withValues(alpha: 0.018));

    // Vignette
    canvas.drawRect(full, Paint()
      ..shader = RadialGradient(
        radius: 1.05,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
        stops: const [0.55, 1.0],
      ).createShader(full));
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter old) => false;
}

// ── Film grain — tiny tiled noise texture, jittered ~11 fps ──────────
class FilmGrain extends StatefulWidget {
  final double opacity;
  const FilmGrain({super.key, this.opacity = 0.045});
  @override
  State<FilmGrain> createState() => _FilmGrainState();
}

class _FilmGrainState extends State<FilmGrain> {
  static ui.Image? _noise;
  static Future<ui.Image>? _loading;
  Timer? _timer;
  Offset _shift = Offset.zero;
  final _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _ensureNoise().then((_) { if (mounted) setState(() {}); });
    _timer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (mounted) setState(() => _shift = Offset(_rnd.nextDouble() * 160, _rnd.nextDouble() * 160));
    });
  }

  static Future<ui.Image> _ensureNoise() {
    if (_noise != null) return Future.value(_noise);
    return _loading ??= () {
      const n = 160;
      final r = math.Random(7);
      final px = Uint8List(n * n * 4);
      // Fully OPAQUE grey noise — no per-pixel alpha, so no premultiplied-alpha
      // ambiguity across renderers (Impeller/Vulkan). Subtlety comes from the
      // layer opacity below, which behaves identically everywhere.
      for (int i = 0; i < n * n; i++) {
        final v = 64 + r.nextInt(128); // mid-grey band 64–191
        px[i * 4] = v;
        px[i * 4 + 1] = v;
        px[i * 4 + 2] = v;
        px[i * 4 + 3] = 255;
      }
      final c = Completer<ui.Image>();
      ui.decodeImageFromPixels(px, n, n, ui.PixelFormat.rgba8888, (img) {
        _noise = img;
        c.complete(img);
      });
      return c.future;
    }();
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final img = _noise;
    if (img == null) return const SizedBox.expand();
    return RepaintBoundary(
      child: Opacity(
        opacity: widget.opacity,
        child: CustomPaint(painter: _GrainPainter(img, _shift)),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  final ui.Image img;
  final Offset shift;
  _GrainPainter(this.img, this.shift);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()
      ..shader = ImageShader(img, TileMode.repeated, TileMode.repeated,
          Matrix4.translationValues(shift.dx, shift.dy, 0).storage));
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.shift != shift;
}

// ══════════════════════════════════════════════════════════════════════
// BRAND
// ══════════════════════════════════════════════════════════════════════
class GoldText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const GoldText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (b) => AppTheme.goldGradient.createShader(b),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.goldGradient,
        borderRadius: BorderRadius.circular(size * 0.29),
        boxShadow: [
          BoxShadow(color: AppTheme.brandGold.withValues(alpha: 0.35),
              blurRadius: size * 0.45, offset: Offset(0, size * 0.1)),
        ],
      ),
      alignment: Alignment.center,
      child: Text('P', style: AppTheme.display(size * 0.55,
          weight: FontWeight.w800, color: Colors.black, letterSpacing: 0, height: 1)),
    );
  }
}

class Wordmark extends StatelessWidget {
  final double size;
  const Wordmark({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic, children: [
        Text('ProDF', style: AppTheme.display(size, weight: FontWeight.w700)),
        GoldText('OS', style: AppTheme.display(size, weight: FontWeight.w800)),
      ]);
  }
}

/// Small uppercase gold section label: "CONTINUE READING"
class Kicker extends StatelessWidget {
  final String text;
  const Kicker(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: AppTheme.kicker());
}

// ══════════════════════════════════════════════════════════════════════
// SURFACES
// ══════════════════════════════════════════════════════════════════════
/// Translucent card. [blur] = real backdrop blur (use sparingly — costly in lists).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool gold;
  final bool blur;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.gold = false,
    this.blur = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    Widget body = Container(
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: gold
              ? [AppTheme.brandGold.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.025)]
              : [Colors.white.withValues(alpha: 0.055), Colors.white.withValues(alpha: 0.02)],
        ),
        border: Border.all(
          color: gold ? AppTheme.goldHairline : Colors.white.withValues(alpha: 0.07)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: br,
          onTap: onTap,
          onLongPress: onLongPress,
          splashColor: AppTheme.brandGold.withValues(alpha: 0.08),
          highlightColor: Colors.white.withValues(alpha: 0.03),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (blur) {
      body = ClipRRect(borderRadius: br,
          child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: body));
    }
    return body;
  }
}

/// Round glass icon button for headers.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const GlassIconButton({super.key, required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, size: 20, color: AppTheme.cream.withValues(alpha: 0.85)),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Primary gold pill with glow.
class GoldPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const GoldPillButton({super.key, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.goldGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: AppTheme.brandGold.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 20, color: Colors.black),
              const SizedBox(width: 8),
              Text(label, style: AppTheme.body(15, weight: FontWeight.w800, color: Colors.black)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Secondary glass pill.
class GlassPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const GlassPillButton({super.key, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: AppTheme.goldHairline),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 19, color: AppTheme.brandGold),
            const SizedBox(width: 8),
            Text(label, style: AppTheme.body(15, weight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// FLOATING GLASS NAV
// ══════════════════════════════════════════════════════════════════════
class GlassNavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const GlassNavItem(this.icon, this.label, this.onTap);
}

class GlassNavBar extends StatelessWidget {
  final List<GlassNavItem> items;
  final int current;
  const GlassNavBar({super.key, required this.items, required this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF111117).withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(children: [
                for (int i = 0; i < items.length; i++)
                  Expanded(child: _navButton(items[i], i == current)),
              ]),
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }

  Widget _navButton(GlassNavItem it, bool active) {
    return InkWell(
      onTap: active ? null : it.onTap,
      borderRadius: BorderRadius.circular(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(it.icon, size: 22,
            color: active ? AppTheme.brandGold : AppTheme.cream.withValues(alpha: 0.45)),
        const SizedBox(height: 3),
        Text(it.label, style: AppTheme.body(11,
            weight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppTheme.brandGold : AppTheme.cream.withValues(alpha: 0.45))),
        const SizedBox(height: 2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: active ? 14 : 0, height: 2,
          decoration: BoxDecoration(
            color: AppTheme.brandGold, borderRadius: BorderRadius.circular(1),
            boxShadow: active
                ? [BoxShadow(color: AppTheme.brandGold.withValues(alpha: 0.8), blurRadius: 6)]
                : null,
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// ENTRANCE — cinematic blur-in
// ══════════════════════════════════════════════════════════════════════
extension CinematicEntrance on Widget {
  /// Fade + un-blur + rise. Use on headers & hero blocks (not long lists).
  Widget cinematicIn({int delayMs = 0, bool blur = true}) {
    var a = animate(delay: Duration(milliseconds: delayMs))
        .fadeIn(duration: 700.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.06, end: 0, duration: 700.ms, curve: Curves.easeOutCubic);
    if (blur) a = a.blurXY(begin: 10, end: 0, duration: 700.ms, curve: Curves.easeOutCubic);
    return a;
  }

  /// Lighter entrance for list items (no blur — keeps scrolling smooth).
  Widget riseIn(int index) => animate(delay: Duration(milliseconds: 60 * math.min(index, 8)))
      .fadeIn(duration: 450.ms)
      .slideY(begin: 0.08, end: 0, duration: 450.ms, curve: Curves.easeOutCubic);
}

// ══════════════════════════════════════════════════════════════════════
// CONTENT WIDTH — centered reading column on wide screens (desktop/tablet)
// Phones are narrower than maxWidth, so nothing changes there.
// ══════════════════════════════════════════════════════════════════════
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ContentWidth({super.key, required this.child, this.maxWidth = 760});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
