import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class RecentDoc {
  final String filePath, fileName;
  final DateTime openedAt;
  final int lastPage;
  RecentDoc({required this.filePath, required this.fileName, required this.openedAt, this.lastPage = 1});
  Map<String, dynamic> toJson() => {'filePath': filePath, 'fileName': fileName, 'openedAt': openedAt.toIso8601String(), 'lastPage': lastPage};
  factory RecentDoc.fromJson(Map<dynamic, dynamic> json) => RecentDoc(
    filePath: json['filePath'] ?? '', fileName: json['fileName'] ?? '',
    openedAt: DateTime.tryParse(json['openedAt'] ?? '') ?? DateTime.now(), lastPage: json['lastPage'] ?? 1,
  );
}

class DocumentManager extends ChangeNotifier {
  final Box _box = Hive.box('documents');
  Uint8List? pendingFileBytes;
  String? pendingFileName;

  List<RecentDoc> get recentDocs {
    final list = <RecentDoc>[];
    for (final key in _box.keys) { final d = _box.get(key); if (d is Map) list.add(RecentDoc.fromJson(d)); }
    list.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return list;
  }

  void addToRecent(String filePath, String fileName) {
    // Keep the saved reading position when a document is reopened
    final existing = _box.get(filePath);
    final lastPage = (existing is Map) ? (existing['lastPage'] ?? 1) as int : 1;
    _box.put(filePath, RecentDoc(filePath: filePath, fileName: fileName,
        openedAt: DateTime.now(), lastPage: lastPage).toJson());
    notifyListeners();
  }
  void saveReadingProgress(String filePath, int page) { final e = _box.get(filePath); if (e is Map) { final u = Map<String, dynamic>.from(e); u['lastPage'] = page; _box.put(filePath, u); } }
  int getLastPage(String filePath) { final e = _box.get(filePath); return (e is Map) ? (e['lastPage'] ?? 1) : 1; }
  void removeFromRecent(String filePath) { _box.delete(filePath); notifyListeners(); }
  void clearAll() { _box.clear(); notifyListeners(); }
}
