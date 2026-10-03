import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/reports/reports.dart';

import 'report_fixtures.dart';

void main() {
  final doc = ReportDocument(
    title: 'تقرير تجريبي',
    subtitle: 'فرعي',
    generatedAt: generatedAt,
    fileStem: 'x',
    asciiFileStem: 'x',
    meta: [ReportEntry.text('المزارع', 'أحمد "الكبير", الصعيدي')],
    summary: [ReportEntry('القيمة', ReportCell.money(825000), unit: 'ج.م')],
    sections: [
      ReportSection(
        title: 'العمليات',
        table: ReportTable(
          columns: const [ReportColumn('المزارع'), ReportColumn('الوزن (كغ)', numeric: true), ReportColumn('القيمة', numeric: true)],
          rows: [
            ReportRow([const ReportCell('حسن'), ReportCell.weight(2718200), ReportCell.money(123456789)]),
            ReportRow([const ReportCell('=HYPERLINK("x")'), ReportCell.weight(550000), ReportCell.money(-5000)], muted: true),
          ],
          totals: [const ReportCell('الإجمالي'), ReportCell.weight(3268200), ReportCell.money(123451789)],
        ),
        notes: const ['ملاحظة\nبسطرين'],
      ),
      const ReportSection(title: 'فارغ', table: ReportTable(columns: [ReportColumn('عمود')], emptyText: 'لا شيء')),
    ],
  );

  late String csv;
  setUp(() => csv = buildReportCsv(doc));

  test('يبدأ بـ BOM وتُرمَّز البايتات UTF-8 (EF BB BF)', () {
    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csvBytes(csv).sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    expect(csvBytes(csv).sublist(3), utf8.encode(csv.substring(1)));
  });

  test('أسطر CRLF، والأقسام يفصلها سطر فارغ ثم سطر العنوان', () {
    final lines = csv.substring(1).split('\r\n');
    expect(lines.first, 'تقرير تجريبي');
    expect(lines[1], 'فرعي');
    expect(lines[2], 'تاريخ الإنشاء,2026-10-03 09:15');
    final i = lines.indexOf('العمليات');
    expect(lines[i - 1], '');
    expect(lines[i + 1], 'المزارع,الوزن (كغ),القيمة');
    final j = lines.indexOf('فارغ');
    expect(lines[j - 1], '');
    expect(lines[j + 2], 'لا شيء');
    expect(csv.endsWith('\r\n'), isTrue);
  });

  test('الأرقام خام دون فواصل الآلاف حتى تُجمع', () {
    expect(csv, contains('القيمة,8250.00,ج.م\r\n'));
    expect(csv, contains('حسن,2718.200,1234567.89\r\n'));
    expect(csv, contains('الإجمالي,3268.200,1234517.89\r\n'));
    expect(csv, contains(',-50.00\r\n'));
    expect(csv, isNot(contains('8,250.00')));
  });

  test('اقتباس RFC 4180: الفاصلة وعلامة الاقتباس وسطر جديد', () {
    expect(csv, contains('المزارع,"أحمد ""الكبير"", الصعيدي"\r\n'));
    expect(csv, contains('"ملاحظة\nبسطرين"\r\n'));
    expect(csvField('a,b'), '"a,b"');
    expect(csvField('قال "نعم"'), '"قال ""نعم"""');
    expect(csvField('بسيط'), 'بسيط');
  });

  test('النص الذي يبدأ بـ = + - @ لا يُفسَّر معادلة، والأرقام السالبة تبقى أرقامًا', () {
    expect(csv, contains('"\'=HYPERLINK(""x"")"'));
    expect(csvField('-12.50'), '-12.50');
    expect(csvField('+1'), "'+1");
    expect(csvField('@SUM(A1)'), "'@SUM(A1)");
  });

  test('تقرير البراد كاملًا: مبالغ وأوزان خام وكل الأقسام', () {
    final full = buildReportCsv(CoolerReport.build(
      detail: cooler14Detail(),
      payments: cooler14Payments(),
      packagingDetails: cooler14PackagingDetails(),
      generatedAt: generatedAt,
    ).toDocument());
    for (final title in ['عمليات الشراء', 'حسب المزارع', 'مشتريات التعبئة', 'أصناف التعبئة المعتمدة', 'الدفعات']) {
      expect(full, contains('\r\n\r\n$title\r\n'));
    }
    expect(full, contains('قيمة المشتريات,33451.79,ج.م'));
    expect(full, contains('إجمالي الوزن,2242.825,كغ'));
    expect(full, contains('2026-10-02 06:40,حسن البدري,40,11.500,460.000,15.00,6900.00,6900.00,0.00,مدفوع'));
  });
}
