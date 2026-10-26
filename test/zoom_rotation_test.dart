// Zoom and rotation, required in every app: nothing may lock the orientation or block pinch zoom.
// (Turning a phone and a tablet with every page open is in screens_test.dart.)

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Android app follows the device both ways', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final lock = RegExp(r'android:screenOrientation="(\w+)"').firstMatch(manifest)?.group(1);
    expect(lock == null || ['unspecified', 'sensor', 'fullSensor', 'fullUser', 'user'].contains(lock), isTrue,
        reason: 'AndroidManifest.xml locks the app to $lock');
  });

  test('the installed web app follows the device both ways', () {
    final o = jsonDecode(File('web/manifest.json').readAsStringSync())['orientation'];
    expect(o == null || o == 'any' || o == 'natural', isTrue, reason: 'web/manifest.json locks the app to $o');
  });

  test('no code locks the orientation', () {
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      expect(f.readAsStringSync().contains('setPreferredOrientations'), isFalse, reason: '${f.path} locks the orientation');
    }
  });

  test('every PDF view can be pinched and double-tapped to zoom', () {
    for (final path in ['lib/features/viewer/viewer_screen.dart', 'lib/features/editor/editor_screen.dart']) {
      final code = File(path).readAsStringSync();
      expect(code.contains('enableDoubleTapZooming: false'), isFalse, reason: '$path turns zoom off');
      expect(RegExp(r'maxZoomLevel: [1-2][,\s]').hasMatch(code), isFalse, reason: '$path barely zooms');
    }
  });

  test('no page blocks pinch zoom', () {
    for (final f in [...Directory('web').listSync(recursive: true), ...Directory('assets').listSync(recursive: true)]
        .whereType<File>().where((f) => f.path.endsWith('.html'))) {
      final meta = RegExp(r'<meta[^>]*name="viewport"[^>]*>').firstMatch(f.readAsStringSync())?.group(0) ?? '';
      expect(RegExp(r'user-scalable\s*=\s*(no|0)').hasMatch(meta), isFalse, reason: '${f.path} blocks pinch zoom');
    }
  });
}
