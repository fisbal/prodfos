import 'package:flutter/foundation.dart';

/// On the web, the PDF viewer and printing hand the PDF bytes to pdf.js, which
/// MOVES them into its worker: the original buffer becomes empty ("ArrayBuffer
/// is already detached"), and the next use (Print, thumbnails…) fails.
/// Give pdf.js its own copy so ProDFOS keeps the original. No copy on native.
Uint8List pdfJsCopy(Uint8List bytes) => kIsWeb ? Uint8List.fromList(bytes) : bytes;
