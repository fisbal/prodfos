import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'stored_file.dart';

/// Native (Android / Windows) implementation — real files on disk.
class AppFiles {
  AppFiles._();

  static const bool isWeb = false;
  static int _tmpCounter = 0;

  static Future<void> init() async {}

  static Future<Uint8List> readBytes(String path) => File(path).readAsBytes();
  static Future<String> readString(String path) => File(path).readAsString();

  static Future<void> writeBytes(String path, List<int> bytes) async {
    final f = File(path);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
  }

  static Future<void> writeString(String path, String content) async {
    final f = File(path);
    await f.parent.create(recursive: true);
    await f.writeAsString(content, flush: true);
  }

  static Future<bool> exists(String path) => File(path).exists();

  /// Android: Download/ProDFOS (visible in the Files app).
  /// Windows & others: Documents\ProDFOS.
  static Future<String> outputDir() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download/ProDFOS');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}ProDFOS');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// Joins a directory and a file name with the platform separator.
  static String join(String dir, String name) => '$dir${Platform.pathSeparator}$name';

  /// A fresh scratch path for intermediate files (enhanced scans, etc.).
  static Future<String> tempPath(String name) async {
    final tmp = await getTemporaryDirectory();
    _tmpCounter++;
    return '${tmp.path}${Platform.pathSeparator}prodfos_${DateTime.now().microsecondsSinceEpoch}_${_tmpCounter}_$name';
  }

  static Future<List<StoredFile>> listOutputs() async {
    final dir = Directory(await outputDir());
    if (!await dir.exists()) return [];
    final out = <StoredFile>[];
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final stat = await e.stat();
      out.add(StoredFile(path: e.path, name: fileNameOf(e.path), modified: stat.modified, size: stat.size));
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  static Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  /// file_picker must load bytes into memory only on web.
  static const bool pickWithData = false;

  /// Turns a picked file into a ProDFOS path (on native it already is one).
  static Future<String?> fromPicked(PlatformFile f, {bool persist = false}) async => f.path;

  /// Stores raw bytes as a temporary file and returns its path.
  static Future<String> fromBytes(Uint8List bytes, String name) async {
    final path = await tempPath(name);
    await writeBytes(path, bytes);
    return path;
  }

  /// Opens a file with the system's default app.
  static Future<void> open(String path) async { await OpenFilex.open(path); }

  /// Shares a file through the system share sheet.
  static Future<void> share(String path, {String? text}) async {
    await Share.shareXFiles([XFile(path)], text: text);
  }

  /// Native: same as [share]. Web: downloads to the computer.
  static Future<void> download(String path) => share(path);

  /// Saves raw bytes to the ProDFOS folder (web: browser download). Returns the path.
  static Future<String> downloadBytes(Uint8List bytes, String name) async {
    final path = join(await outputDir(), name);
    await writeBytes(path, bytes);
    return path;
  }

  static ImageProvider image(String path) => FileImage(File(path));
}
