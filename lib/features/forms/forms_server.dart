import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

/// Receives the filled PDF from the Forms engine, returns the saved file name.
typedef FormSaveHandler = Future<String> Function(Uint8List bytes);

class _FormDoc {
  final Uint8List bytes;
  final String name;
  final FormSaveHandler onSave;
  _FormDoc(this.bytes, this.name, this.onSave);
}

/// Private web server bound to 127.0.0.1 (never reachable from the network).
///
/// Serves the pdf.js Forms engine from the app's assets, the document being
/// viewed, and receives filled forms when the user taps Save. Every document
/// gets a random 128-bit token, so nothing else on the device can read it.
class FormsServer {
  FormsServer._();

  static HttpServer? _server;
  static final Map<String, _FormDoc> _docs = {};
  static final Random _rand = Random.secure();

  static Future<Uri> register({
    required Uint8List bytes,
    required String name,
    required FormSaveHandler onSave,
  }) async {
    final server = await _ensure();
    final token = List.generate(16, (_) => _rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    _docs[token] = _FormDoc(bytes, name, onSave);
    return Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: server.port,
      path: '/x/xfa_viewer.html',
      queryParameters: {'file': '/doc/$token', 'api': '/api/$token', 'name': name},
    );
  }

  static void unregister(Uri? uri) {
    final token = uri?.queryParameters['file']?.split('/').last;
    if (token != null) _docs.remove(token);
  }

  static Future<HttpServer> _ensure() async {
    final existing = _server;
    if (existing != null) return existing;
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    s.listen(_handle, onError: (_) {});
    return _server = s;
  }

  static Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final seg = req.uri.pathSegments;

      // Engine files: /x/<path inside assets/pdfjs>
      if (seg.length >= 2 && seg.first == 'x' && req.method == 'GET') {
        if (seg.contains('..')) return await _status(res, 404);
        final rel = seg.skip(1).join('/');
        final data = await rootBundle.load('assets/pdfjs/$rel');
        res.headers.contentType = _typeOf(rel);
        res.headers.set('Cache-Control', 'max-age=3600');
        res.add(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        await res.close();
        return;
      }

      // The document: /doc/<token>
      if (seg.length == 2 && seg.first == 'doc' && req.method == 'GET') {
        final doc = _docs[seg[1]];
        if (doc == null) return await _status(res, 404);
        res.headers.contentType = ContentType('application', 'pdf');
        res.headers.contentLength = doc.bytes.length;
        res.add(doc.bytes);
        await res.close();
        return;
      }

      // Callbacks: POST /api/<token>/save | /api/<token>/event
      if (seg.length == 3 && seg.first == 'api' && req.method == 'POST') {
        final doc = _docs[seg[1]];
        if (doc == null) return await _status(res, 404);
        final body = await _readBody(req);
        var reply = <String, dynamic>{};
        if (seg[2] == 'save') {
          reply = {'name': await doc.onSave(body)};
        }
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode(reply));
        await res.close();
        return;
      }

      return await _status(res, 404);
    } catch (e) {
      try {
        res.statusCode = 500;
        res.write('$e');
        await res.close();
      } catch (_) {}
    }
  }

  static Future<Uint8List> _readBody(HttpRequest req) async {
    final b = BytesBuilder(copy: false);
    await for (final chunk in req) {
      b.add(chunk);
    }
    return b.takeBytes();
  }

  static Future<void> _status(HttpResponse res, int code) async {
    res.statusCode = code;
    await res.close();
  }

  static ContentType _typeOf(String path) {
    if (path.endsWith('.html')) return ContentType.html;
    if (path.endsWith('.js')) return ContentType('application', 'javascript', charset: 'utf-8');
    if (path.endsWith('.css')) return ContentType('text', 'css', charset: 'utf-8');
    if (path.endsWith('.svg')) return ContentType('image', 'svg+xml');
    return ContentType.binary;
  }
}
