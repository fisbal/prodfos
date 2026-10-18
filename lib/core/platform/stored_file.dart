/// A file produced by ProDFOS tools (merge, split, scan, edits…).
class StoredFile {
  final String path;
  final String name;
  final DateTime modified;
  final int size;
  const StoredFile({required this.path, required this.name, required this.modified, required this.size});
}

/// File name from any ProDFOS path (handles / and \ separators and web:// keys).
String fileNameOf(String path) => path.split(RegExp(r'[/\\]')).last;
