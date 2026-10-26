import 'dart:io';

import 'package:http/http.dart' as http;

/// Downloads the Windows installer and runs it quietly; it closes ProDFOS, installs the
/// new version over the old one (files and settings stay) and opens it again.
Future<void> installWindowsUpdate(String url) async {
  final res = await http.get(Uri.parse(url));
  if (res.statusCode != 200) throw HttpException('Download failed (${res.statusCode})', uri: Uri.parse(url));
  final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}ProDFOS-Setup.exe');
  await file.writeAsBytes(res.bodyBytes, flush: true);
  await Process.start(file.path, ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART'], mode: ProcessStartMode.detached);
  exit(0);
}
