import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

/// Windows remembers a PDF app chosen with "Open with > Choose another app"
/// as Applications\prodfos.exe — the exact folder it was picked from. If that
/// was an old portable (zip) copy, double-clicked PDFs keep opening that old,
/// never-updated copy. Each start of the INSTALLED ProDFOS points that entry
/// back at itself. A portable copy never claims PDFs.
Future<void> repairPdfAssociation() async {
  if (!Platform.isWindows || !_isInstalledCopy) return;
  final exe = Platform.resolvedExecutable;
  const base = r'HKCU\Software\Classes\Applications\prodfos.exe';
  try {
    final q = await Process.run('reg', ['query', '$base\\shell\\open\\command', '/ve']);
    if (q.exitCode == 0 && '${q.stdout}'.toLowerCase().contains(exe.toLowerCase())) return;
    await Process.run('reg', ['add', '$base\\shell\\open\\command', '/ve', '/d', '"$exe" "%1"', '/f']);
    await Process.run('reg', ['add', '$base\\DefaultIcon', '/ve', '/d', '"$exe",0', '/f']);
    await Process.run('reg', ['add', base, '/v', 'FriendlyAppName', '/d', 'ProDFOS', '/f']);
  } catch (_) {
    // Best effort: the installer sets the same keys on every update.
  }
}

/// Settings shows "Open PDFs with ProDFOS" on the installed Windows app.
bool get canChoosePdfApp => Platform.isWindows && _isInstalledCopy;

/// Repairs the link, then opens Windows' default-apps page for ProDFOS.
Future<void> openDefaultAppsSettings() async {
  await repairPdfAssociation();
  final ok = await launchUrl(Uri.parse('ms-settings:defaultapps?registeredAppUser=ProDFOS'));
  if (!ok) await launchUrl(Uri.parse('ms-settings:defaultapps'));
}

bool get _isInstalledCopy {
  final local = Platform.environment['LOCALAPPDATA'];
  if (local == null) return false;
  final installed = '$local\\Programs\\ProDFOS\\'.toLowerCase();
  return Platform.resolvedExecutable.toLowerCase().startsWith(installed);
}
