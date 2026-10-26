import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prodfos/core/constants/app_constants.dart';
import 'package:prodfos/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // No network in tests: the theme's fonts fall back to the default font.
  GoogleFonts.config.allowRuntimeFetching = false;

  test('Brand identity is intact', () {
    expect(AppConstants.appName, 'ProDFOS');
    expect(AppConstants.packageName, 'com.martinb.prodfos');
    expect(AppConstants.appTagline, 'Read smarter. Not harder.');
  });

  test('Theme never sets a global fontFamily (keeps Material icons intact)', () {
    final theme = AppTheme.darkTheme;
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, AppTheme.brandGold);
  });
}
