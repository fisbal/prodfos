import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import '../../core/theme/app_theme.dart';

/// Returns PNG bytes (transparent background) of the signature, or null.
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
  static const _storeKey = 'saved_signature_png';
  final _padKey = GlobalKey<SfSignaturePadState>();
  Color _ink = const Color(0xFF0D1B4C); // deep navy — reads as real pen ink
  bool _hasStrokes = false;
  Uint8List? _saved;

  @override
  void initState() {
    super.initState();
    final v = Hive.box('settings').get(_storeKey);
    if (v is Uint8List) _saved = v;
  }

  Future<Uint8List?> _export() async {
    final ui.Image img = await _padKey.currentState!.toImage(pixelRatio: 3.0);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _useDrawn() async {
    final png = await _export();
    if (png == null) return;
    await Hive.box('settings').put(_storeKey, png);
    if (mounted) Navigator.pop(context, png);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.darkBorder, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Your Signature',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Sign inside the box with your finger',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.45))),
            const SizedBox(height: 16),

            if (_saved != null) ...[
              GestureDetector(
                onTap: () => Navigator.pop(context, _saved),
                child: Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.brandGold, width: 1.5),
                  ),
                  child: Row(children: [
                    Expanded(child: Image.memory(_saved!, fit: BoxFit.contain)),
                    const SizedBox(width: 10),
                    const Text('Use saved',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
                    const Icon(Icons.chevron_right, color: Colors.black54),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Text('or draw a new one', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
              const SizedBox(height: 12),
            ],

            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(children: [
                  Positioned(left: 20, right: 20, bottom: 50,
                    child: Container(height: 1, color: Colors.black12)),
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
            const SizedBox(height: 14),

            Row(children: [
              for (final c in const [Color(0xFF0D1B4C), Colors.black, Color(0xFF1565C0)])
                GestureDetector(
                  onTap: () => setState(() => _ink = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: c, shape: BoxShape.circle,
                      border: Border.all(
                        color: _ink == c ? AppTheme.brandGold : Colors.white24,
                        width: _ink == c ? 2.5 : 1),
                    ),
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  _padKey.currentState?.clear();
                  setState(() => _hasStrokes = false);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Clear'),
              ),
            ]),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _hasStrokes ? _useDrawn : null,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Use this signature'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
