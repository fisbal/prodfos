import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import 'update_install_io.dart' if (dart.library.js_interop) 'update_install_web.dart';

/// Keeps installed copies of ProDFOS up to date, so nobody has to reinstall by hand.
///
/// Every release on GitHub carries `version.json` ({"build": N, "version": "1.0.N"}) next to the
/// apps, always at the same address. The app compares it with its own build number:
/// - Windows downloads ProDFOS-Setup.exe and installs it quietly, then opens again;
/// - Android opens the new APK, and Android asks to install it over the old one (same key);
/// - Mac opens the new .dmg.
/// The web app needs none of this: GitHub Pages always serves the newest version.
class UpdateService extends ChangeNotifier {
  static const _base = 'https://github.com/fisbal/prodfos/releases/latest/download';

  /// The newer version found, like "1.0.42", or null.
  String? available;
  bool installing = false;

  /// Only release builds (stamped by CI) on Android, Windows and Mac look for updates.
  static bool get supported =>
      !kIsWeb &&
      AppConstants.buildNumber > 0 &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static String get _asset => switch (defaultTargetPlatform) {
        TargetPlatform.windows => 'ProDFOS-Setup.exe',
        TargetPlatform.macOS => 'ProDFOS.dmg',
        _ => 'ProDFOS-android.apk',
      };

  /// Looks for a newer release; quietly does nothing when offline.
  Future<void> check() async {
    if (!supported) return;
    try {
      final res = await http.get(Uri.parse('$_base/version.json')).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final info = jsonDecode(res.body) as Map<String, dynamic>;
      final build = (info['build'] as num?)?.toInt() ?? 0;
      if (build > AppConstants.buildNumber) {
        available = info['version'] as String? ?? '1.0.$build';
        notifyListeners();
      }
    } catch (_) {
      // Offline or GitHub unreachable: try again next time.
    }
  }

  Future<void> install() async {
    final url = '$_base/$_asset';
    installing = true;
    notifyListeners();
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await installWindowsUpdate(url);
      } else {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } finally {
      installing = false;
      notifyListeners();
    }
  }

  void dismiss() {
    available = null;
    notifyListeners();
  }
}
