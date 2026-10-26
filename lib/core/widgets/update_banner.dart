import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// A small card at the bottom of every page when a newer ProDFOS is out: Update now / Later.
class UpdateBanner extends StatefulWidget {
  final Widget child;
  const UpdateBanner({super.key, required this.child});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  @override
  void initState() {
    super.initState();
    // A few seconds after start, so opening the app stays fast.
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) context.read<UpdateService>().check();
    });
  }

  @override
  Widget build(BuildContext context) {
    final updates = context.watch<UpdateService>();
    final version = updates.available;
    return Stack(children: [
      widget.child,
      if (version != null)
        Positioned(
          left: 12, right: 12, bottom: 12,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Material(
                  color: AppTheme.darkCard,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.goldHairline),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    child: Row(children: [
                      const Icon(Icons.system_update_rounded, color: AppTheme.brandGold),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('ProDFOS $version is ready',
                            style: AppTheme.body(14, weight: FontWeight.w600)),
                      ),
                      TextButton(
                        onPressed: updates.installing ? null : updates.dismiss,
                        child: Text('Later', style: AppTheme.body(13, color: AppTheme.creamMuted)),
                      ),
                      FilledButton(
                        onPressed: updates.installing ? null : () => updates.install(),
                        child: Text(updates.installing ? 'Installing…' : 'Update now'),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}
