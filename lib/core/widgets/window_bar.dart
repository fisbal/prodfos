import 'package:flutter/material.dart';
import '../platform/window_actions.dart';

/// The gold MartinB window bar, shared by every MartinB app:
/// logo + name ("ProDF" white, "OS" gold) on the left,
/// minimize / full screen / close on the right.
///
/// Wraps the whole app (MaterialApp.router `builder`), so every screen gets it.
/// On platforms where [WindowActions.showBar] is false the app is unchanged.
class WindowFrame extends StatelessWidget {
  final Widget child;
  const WindowFrame({super.key, required this.child});

  static const barColor = Color(0xFF0B0A08);

  @override
  Widget build(BuildContext context) {
    if (!WindowActions.showBar) return child;
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: barColor,
      child: Column(
        children: [
          Padding(padding: EdgeInsets.only(top: top), child: const _WindowBar()),
          // The bar now sits under the status bar, so screens below must not pad for it again.
          Expanded(
            child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
          ),
        ],
      ),
    );
  }
}

class _WindowBar extends StatefulWidget {
  const _WindowBar();
  @override
  State<_WindowBar> createState() => _WindowBarState();
}

class _WindowBarState extends State<_WindowBar> {
  static const _gold = Color(0xFFD4AD62);
  static const _ink = Color(0xFFF3EFE6);
  bool _full = WindowActions.isFullScreen;

  Future<void> _toggleFull() async {
    final now = await WindowActions.toggleFullScreen();
    if (mounted) setState(() => _full = now);
  }

  Widget _button(IconData icon, String label, VoidCallback onTap, {Color? hover}) {
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        highlightColor: (hover ?? _gold).withValues(alpha: 0.18),
        splashColor: (hover ?? _gold).withValues(alpha: 0.22),
        child: SizedBox(width: 46, height: 44, child: Icon(icon, color: _gold, size: 22)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WindowFrame.barColor,
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 12, right: 2),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x38D4AD62))),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/icons/prodfos_logo.png', width: 24, height: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                const TextSpan(children: [
                  TextSpan(text: 'ProDF', style: TextStyle(color: _ink)),
                  TextSpan(text: 'OS', style: TextStyle(color: _gold)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
              ),
            ),
            if (WindowActions.canMinimize) _button(Icons.remove, 'Réduire', WindowActions.minimize),
            if (WindowActions.canFullScreen)
              _button(_full ? Icons.fullscreen_exit : Icons.fullscreen,
                  _full ? 'Quitter le plein écran' : 'Plein écran', _toggleFull),
            _button(Icons.close, 'Fermer', WindowActions.close, hover: const Color(0xFFC42B1C)),
          ],
        ),
      ),
    );
  }
}
