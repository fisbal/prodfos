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
