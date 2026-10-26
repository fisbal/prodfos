class AppConstants {
  AppConstants._();
  static const String appName = 'ProDFOS';
  static const String appTagline = 'Read smarter. Not harder.';
  /// The build number CI stamps into every release (`--dart-define=PRODFOS_BUILD=<run number>`); 0 in local builds.
  static const int buildNumber = int.fromEnvironment('PRODFOS_BUILD');
  static const String appVersion = buildNumber > 0 ? '1.0.$buildNumber' : '1.0.0';
  static const String packageName = 'com.martinb.prodfos';
}
