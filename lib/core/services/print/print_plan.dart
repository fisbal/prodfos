import '../pdf_edit_service.dart';

/// Which pages to print (ProDFOS print panel).
enum PrintPages { all, current, range, odd, even }

/// What the user chose in the print panel.
class PrintPlan {
  final PrintPages pages;
  final String range; // e.g. "1-4, 7, 9-" (used when pages == range)
  final int copies;
  final bool manualDuplex; // fronts first, flip the stack, then backs
  final bool reverse; // last page first
  /// Manual two-sided: print the backs last-sheet-first (most printers, where
  /// the printed stack comes out face up and is flipped as a whole).
  final bool reverseBacks;
  const PrintPlan({
    this.reverseBacks = true,
    this.pages = PrintPages.all,
    this.range = '',
    this.copies = 1,
    this.manualDuplex = false,
    this.reverse = false,
  });
}

/// Parses "1-4, 7, 9-" into 1-based page numbers, in the order written,
/// clamped to [1, pageCount]. Returns null when the text is not a valid range.
List<int>? parsePageRange(String text, int pageCount) {
  final parts = text.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty);
  if (parts.isEmpty) return null;
  final out = <int>[];
  for (final p in parts) {
    final m = RegExp(r'^(\d*)\s*[-–]\s*(\d*)$').firstMatch(p);
    if (m != null) {
      final a = m.group(1)!.isEmpty ? 1 : int.parse(m.group(1)!);
      final b = m.group(2)!.isEmpty ? pageCount : int.parse(m.group(2)!);
      if (a < 1 || b < a || a > pageCount) return null;
      for (var i = a; i <= b && i <= pageCount; i++) {
        out.add(i);
      }
    } else if (RegExp(r'^\d+$').hasMatch(p)) {
      final n = int.parse(p);
      if (n < 1 || n > pageCount) return null;
      out.add(n);
    } else {
      return null;
    }
  }
  return out;
}

/// Turns the plan into print passes: one pass normally, two for manual
/// two-sided printing (fronts, then backs). Each pass is the list of pages to
/// send to the printer, 0-based, with blank pages where a sheet has no back.
/// Throws [FormatException] when the page range is invalid.
List<List<PageEntry>> planPrintJobs(PrintPlan plan, {required int pageCount, required int currentPage}) {
  List<int> pages; // 1-based
  switch (plan.pages) {
    case PrintPages.all:
      pages = [for (var i = 1; i <= pageCount; i++) i];
    case PrintPages.current:
      pages = [currentPage.clamp(1, pageCount)];
    case PrintPages.range:
      pages = parsePageRange(plan.range, pageCount) ?? (throw const FormatException('range'));
    case PrintPages.odd:
      pages = [for (var i = 1; i <= pageCount; i += 2) i];
    case PrintPages.even:
      pages = [for (var i = 2; i <= pageCount; i += 2) i];
  }
  if (pages.isEmpty) throw const FormatException('empty');
  if (plan.reverse) pages = pages.reversed.toList();

  PageEntry page(int n) => PageEntry(docIndex: 0, pageIndex: n - 1);
  PageEntry blank() => PageEntry(docIndex: -1, pageIndex: 0);
  final copies = plan.copies.clamp(1, 99);

  if (!plan.manualDuplex) {
    return [
      [for (var c = 0; c < copies; c++) ...pages.map(page)],
    ];
  }

  // Sheets: (front, back?) for each copy, so every copy stays a complete set.
  final fronts = <PageEntry>[];
  final backs = <PageEntry>[];
  for (var c = 0; c < copies; c++) {
    for (var i = 0; i < pages.length; i += 2) {
      fronts.add(page(pages[i]));
      backs.add(i + 1 < pages.length ? page(pages[i + 1]) : blank());
    }
  }
  // After flipping the printed stack, the last sheet is usually on top: backs
  // then go in reverse so each back lands on its own front.
  return [fronts, plan.reverseBacks ? backs.reversed.toList() : backs];
}
