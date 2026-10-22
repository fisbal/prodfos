import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:web/web.dart' as web;
import 'stored_file.dart';

/// Web implementation — files live inside the browser.
///
/// • `web://…` paths are persisted in IndexedDB (Hive box "webfs") so the
///   Library and "Created files" survive a page reload.
/// • `mem://…` paths are kept in memory only (tool inputs, scratch images).
/// • Saving / sharing triggers a normal browser download.
class AppFiles {
  AppFiles._();

  static const bool isWeb = true;
  static final Map<String, Uint8List> _mem = {};
  static Box? _box;
  static int _counter = 0;

  /// Browser storage is already private to this browser.
  static Future<String?> privateDataDir() async => null;

  static Future<void> init() async {
    _box = await Hive.openBox('webfs');
    // Drop stored documents that are no longer in the Library.
    try {
      final docs = Hive.box('documents');
      final stale = _box!.keys
          .whereType<String>()
          .where((k) => k.startsWith('web://in/') && !docs.containsKey(k))
          .toList();
      await _box!.deleteAll(stale);
    } catch (_) {}
  }

  static Uint8List? _get(String path) {
    final m = _mem[path];
    if (m != null) return m;
    final v = _box?.get(path);
    if (v is Map) {
      final b = v['b'];
      if (b is Uint8List) return b;
      if (b is List) return Uint8List.fromList(b.cast<int>());
    }
    return null;
  }

  static Future<Uint8List> readBytes(String path) async {
    final b = _get(path);
    if (b == null) throw Exception('File is no longer available in this browser: ${fileNameOf(path)}');
    return b;
  }

  static Future<String> readString(String path) async =>
      const Utf8Codec().decode(await readBytes(path), allowMalformed: true);

  static Future<void> writeBytes(String path, List<int> bytes) async {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    if (path.startsWith('web://')) {
      await _box?.put(path, {'b': data, 'm': DateTime.now().millisecondsSinceEpoch});
    } else {
      _mem[path] = data;
    }
  }

  static Future<void> writeString(String path, String content) =>
      writeBytes(path, const Utf8Codec().encode(content));

  static Future<bool> exists(String path) async => _get(path) != null;

  static Future<String> outputDir() async => 'web://out';

  static String join(String dir, String name) => '$dir/$name';

  static Future<String> tempPath(String name) async => 'mem://tmp/${_counter++}/$name';

  static Future<List<StoredFile>> listOutputs() async {
    final out = <StoredFile>[];
    for (final k in (_box?.keys ?? const []).whereType<String>()) {
      if (!k.startsWith('web://out/')) continue;
      final v = _box!.get(k);
      if (v is! Map) continue;
      final b = v['b'];
      out.add(StoredFile(
        path: k,
        name: fileNameOf(k),
        modified: DateTime.fromMillisecondsSinceEpoch((v['m'] ?? 0) as int),
        size: b is List ? b.length : 0,
      ));
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  static Future<void> delete(String path) async {
    _mem.remove(path);
    await _box?.delete(path);
  }

  /// file_picker returns no path on web, only bytes — so ask for them.
  static const bool pickWithData = true;

  /// Stores a picked file in the browser and returns its ProDFOS path.
  /// [persist] keeps it across reloads (used for documents opened in the Library).
  static Future<String?> fromPicked(PlatformFile f, {bool persist = false}) async {
    final bytes = f.bytes;
    if (bytes == null) return null;
    final id = '${DateTime.now().millisecondsSinceEpoch}${_counter++}';
    final path = persist ? 'web://in/$id/${f.name}' : 'mem://in/$id/${f.name}';
    await writeBytes(path, bytes);
    return path;
  }

  static Future<String> fromBytes(Uint8List bytes, String name) async {
    final path = await tempPath(name);
    _mem[path] = bytes;
    return path;
  }

  /// Web has no "other apps" — opening a file downloads it.
  static Future<void> open(String path) => download(path);
  static Future<void> share(String path, {String? text}) => download(path);

  static Future<void> download(String path) async {
    final bytes = await readBytes(path);
    downloadBytes(bytes, fileNameOf(path));
  }

  static void downloadBytes(Uint8List bytes, String name) {
    final lower = name.toLowerCase();
    final mime = lower.endsWith('.pdf')
        ? 'application/pdf'
        : lower.endsWith('.txt') ? 'text/plain' : 'application/octet-stream';
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
    final url = web.URL.createObjectURL(blob);
    final a = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = name
      ..style.display = 'none';
    web.document.body?.appendChild(a);
    a.click();
    a.remove();
    Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  }

  static ImageProvider image(String path) => MemoryImage(_get(path) ?? Uint8List(0));
}
