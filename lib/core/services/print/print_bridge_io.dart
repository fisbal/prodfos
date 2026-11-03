import 'dart:typed_data';

/// Android, Windows, Mac: no page around the app, so nothing to listen to.
void listen(void Function() onPrint) {}

/// Only the web build can be shown inside Office In 1.
bool get insideOfficeIn1 => false;

/// Nothing to hand over outside the web.
void sendPagesToPrint(String name, List<Uint8List> pngs) {}
