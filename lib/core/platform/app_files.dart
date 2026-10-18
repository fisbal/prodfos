/// Cross-platform file access for ProDFOS.
///
/// Android / Windows → real files on disk (dart:io).
/// Web               → files live in the browser (IndexedDB via Hive);
///                     "save" and "share" become browser downloads.
///
/// Every screen and service goes through [AppFiles] instead of dart:io,
/// so the same code runs in the app and at the GitHub Pages link.
library;

export 'stored_file.dart';
export 'files_io.dart' if (dart.library.js_interop) 'files_web.dart';
