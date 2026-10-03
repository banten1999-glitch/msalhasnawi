import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/models/records.dart';
import 'package:rumman_calculator/core/reports/cooler_report.dart';
import 'package:rumman_calculator/core/reports/farmer_statement.dart';
import 'package:rumman_calculator/core/reports/period_report.dart';
import 'package:rumman_calculator/core/reports/report_document.dart';
import 'package:rumman_calculator/core/reports/report_pdf.dart';
import 'package:rumman_calculator/core/reports/supplier_report.dart';

import 'report_fixtures.dart';

/// الخطوط من ملفات المشروع مباشرة (rootBundle غير متاح خارج التطبيق).
ReportFonts testFonts() => ReportFonts.fromBytes(
      File('assets/fonts/IBMPlexSansArabic-Regular.ttf').readAsBytesSync(),
      File('assets/fonts/IBMPlexSansArabic-Bold.ttf').readAsBytesSync(),
    );

/// عند ضبط REPORT_PDF_OUT يُكتب الملف هناك للفحص البصري (pdftoppm).
void _maybeWrite(String name, List<int> bytes) {
  final dir = Platform.environment['REPORT_PDF_OUT'];
  if (dir == null || dir.isEmpty) return;
  File('$dir/$name').writeAsBytesSync(bytes);
}

CoolerReport _bigCoolerReport(int rows) {
  final purchases = [
    for (var i = 0; i < rows; i++)
      purchase('PU-${(i + 1).toString().padLeft(4, '0')}',
          farmerId: 'FR-${(i % 37 + 1).toString().padLeft(4, '0')}',
          farmerName: 'مزارع رقم ${i % 37 + 1}',
          at: '2026-10-02T${(6 + i ~/ 60).toString().padLeft(2, '0')}:${(i % 60).toString().padLeft(2, '0')}:00+03:00',
          boxes: 10 + i % 40,
          avgGrams: 10500 + i % 900,
          price: 1400 + i % 200,
          paid: i.isEven ? 100000 : 0,
          active: i % 17 != 5),
  ];
  return CoolerReport.build(
    detail: CoolerDetail(cooler: cooler14(), purchases: purchases, packaging: cooler14Packaging()),
    payments: cooler14Payments(),
    packagingDetails: cooler14PackagingDetails(),
    generatedAt: generatedAt,
  );
}

void main() {
  late ReportFonts fonts;
  setUpAll(() => fonts = testFonts());

  test('ملف PDF صالح يبدأ بـ %PDF', () async {
    final doc = CoolerReport.build(
      detail: cooler14Detail(),
      payments: cooler14Payments(),
      packagingDetails: cooler14PackagingDetails(),
      generatedAt: generatedAt,
    ).toDocument();
    final bytes = await buildReportPdf(doc, businessName: 'حاسبة الحسناوي', fonts: fonts);
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
    expect(bytes.length, greaterThan(10000));
    _maybeWrite('cooler-14.pdf', bytes);
  });

  test('كشف حساب المزارع يُصدَّر PDF', () async {
    final doc = FarmerStatement.build(
      farmer: farmer1,
      purchases: farmer1Purchases(),
      payments: farmer1Payments(),
      generatedAt: generatedAt,
    ).toDocument();
    final bytes = await buildReportPdf(doc, businessName: 'حاسبة الحسناوي', fonts: fonts);
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
    _maybeWrite('farmer-1.pdf', bytes);
  });

  test('تقرير الموردين وتقرير الفترة يُصدَّران PDF', () async {
    final supplier = SupplierReport.build(
      packaging: cooler14Packaging(),
      details: cooler14PackagingDetails(),
      generatedAt: generatedAt,
    ).toDocument();
    final period = PeriodReport.build(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 3),
      purchases: [...cooler14Purchases(), ...farmer1Purchases().where((p) => p.coolerNo == 13)],
      payments: cooler14Payments(),
      packaging: cooler14Packaging(),
      coolers: [cooler14()],
      generatedAt: generatedAt,
    ).toDocument();
    for (final (name, doc) in [('suppliers.pdf', supplier), ('period.pdf', period)]) {
      final bytes = await buildReportPdf(doc, businessName: 'حاسبة الحسناوي', fonts: fonts);
      expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
      _maybeWrite(name, bytes);
    }
  });

  test('جدول كبير ينقسم على عدة صفحات', () async {
    final doc = _bigCoolerReport(260).toDocument();
    final pdf = await buildReportPdfDocument(doc, businessName: 'حاسبة الحسناوي', fonts: fonts);
    final bytes = await pdf.save();
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
    expect(pdf.document.pdfPageList.pages.length, greaterThan(4));
    _maybeWrite('cooler-big.pdf', bytes);
  });

  test('جدول فارغ لا يكسر التصدير', () async {
    final doc = ReportDocument(
      title: 'تقرير فارغ',
      generatedAt: generatedAt,
      fileStem: 'x',
      asciiFileStem: 'x',
      sections: const [ReportSection(title: 'قسم', table: ReportTable(columns: [ReportColumn('عمود')]))],
    );
    final bytes = await buildReportPdf(doc, businessName: 'حاسبة الحسناوي', fonts: fonts);
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
  });
}
