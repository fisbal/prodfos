import 'package:flutter_test/flutter_test.dart';
import 'package:prodfos/core/services/print/print_plan.dart';

List<int> nums(List entries) => [for (final e in entries) e.isBlank ? 0 : e.pageIndex + 1];

void main() {
  test('page ranges', () {
    expect(parsePageRange('1-4, 7', 14), [1, 2, 3, 4, 7]);
    expect(parsePageRange('9-', 11), [9, 10, 11]);
    expect(parsePageRange('-2', 5), [1, 2]);
    expect(parsePageRange('3', 2), isNull);
    expect(parsePageRange('a-b', 5), isNull);
    expect(parsePageRange('', 5), isNull);
  });

  test('all pages, 2 copies, collated', () {
    final jobs = planPrintJobs(const PrintPlan(copies: 2), pageCount: 3, currentPage: 1);
    expect(jobs.length, 1);
    expect(nums(jobs[0]), [1, 2, 3, 1, 2, 3]);
  });

  test('current page, odd, even, reverse', () {
    expect(nums(planPrintJobs(const PrintPlan(pages: PrintPages.current), pageCount: 5, currentPage: 4)[0]), [4]);
    expect(nums(planPrintJobs(const PrintPlan(pages: PrintPages.odd), pageCount: 5, currentPage: 1)[0]), [1, 3, 5]);
    expect(nums(planPrintJobs(const PrintPlan(pages: PrintPages.even), pageCount: 5, currentPage: 1)[0]), [2, 4]);
    expect(nums(planPrintJobs(const PrintPlan(reverse: true), pageCount: 3, currentPage: 1)[0]), [3, 2, 1]);
  });

  test('manual two-sided: fronts, then backs in reverse with a blank for an odd count', () {
    final jobs = planPrintJobs(const PrintPlan(manualDuplex: true), pageCount: 5, currentPage: 1);
    expect(jobs.length, 2);
    expect(nums(jobs[0]), [1, 3, 5]);
    expect(nums(jobs[1]), [0, 4, 2]); // sheet 3 has no back
  });

  test('manual two-sided, backs in normal order', () {
    final jobs = planPrintJobs(const PrintPlan(manualDuplex: true, reverseBacks: false), pageCount: 4, currentPage: 1);
    expect(nums(jobs[1]), [2, 4]);
  });

  test('a wrong range is refused', () {
    expect(() => planPrintJobs(const PrintPlan(pages: PrintPages.range, range: '0-3'), pageCount: 5, currentPage: 1),
        throwsFormatException);
  });
}
