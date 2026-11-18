/// Windows: make double-clicked PDFs open THIS installed, self-updating ProDFOS.
library;

export 'pdf_association_io.dart' if (dart.library.js_interop) 'pdf_association_web.dart';
