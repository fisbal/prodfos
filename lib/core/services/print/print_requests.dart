/// Printing in ProDFOS: Ctrl+P (⌘P on Mac) or the Print key prints the open PDF itself, with the
/// system print dialog, on Android, Windows, Mac and the web, including inside Office In 1.
library;

import 'package:flutter/foundation.dart';
import 'print_bridge_io.dart' if (dart.library.js_interop) 'print_bridge_web.dart' as bridge;

/// Ticks each time the page around ProDFOS asks to print (Office In 1 sends {type: 'oi1-print'}
/// when Ctrl+P is pressed while its own bar has the focus). The viewer on screen listens.
final ValueNotifier<int> printRequests = ValueNotifier<int>(0);

/// Starts listening to the page around ProDFOS (web build only; nothing elsewhere).
void listenForPrintRequests() => bridge.listen(() => printRequests.value++);

/// True for the web build shown inside Office In 1.
bool get insideOfficeIn1 => bridge.insideOfficeIn1;

/// Hands the pages, as pictures, to Office In 1, which prints them from its own window.
void sendPagesToPrint(String name, List<Uint8List> pngs) => bridge.sendPagesToPrint(name, pngs);
