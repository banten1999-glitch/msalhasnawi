import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/models/dashboard.dart';
import 'package:rumman_calculator/core/models/records.dart';
import 'package:rumman_calculator/core/reports/reports.dart';

import 'report_fixtures.dart';

ReportSection section(ReportDocument doc, String title) => doc.sections.firstWhere((s) => s.title == title);

ReportEntry entry(List<ReportEntry> list, String label) => list.firstWhere((e) => e.label == label);

List<String> totalsRow(ReportSection s) => [for (final c in s.table!.totals!) c.text];

void main() {
  group('حساب مشترك', () {
    test('round_half_up بأعداد صحيحة', () {
      expect(roundHalfUpDiv(5, 2), 3);
      expect(roundHalfUpDiv(4, 3), 1);
      expect(roundHalfUpDiv(-5, 2), -3);
      expect(weightedAvgPricePerKg(3345179, 2242825), 1492);
      expect(weightedAvgPricePerKg(100, 0), 0);
    });

    test('plainMinor دون فواصل الآلاف', () {
      expect(plainMinor(825000, 2), '8250.00');
      expect(plainMinor(5, 2), '0.05');
      expect(plainMinor(-123456, 2), '-1234.56');
      expect(plainMinor(2718200, 3), '2718.200');
      expect(plainMinor(42, 0), '42');
    });

    test('الفترة شاملة لليومين بتاريخ العمل', () {
      final from = DateTime(2026, 10, 2);
      final to = DateTime(2026, 10, 2, 23);
      expect(inDateRange('2026-10-02T00:00:00+03:00', from: from, to: to), isTrue);
      expect(inDateRange('2026-10-02T23:59:00+03:00', from: from, to: to), isTrue);
      expect(inDateRange('2026-10-01T23:59:00+03:00', from: from, to: to), isFalse);
      expect(inDateRange('2026-10-03T00:00:00+03:00', from: from), isTrue);
      expect(inDateRange(null, from: from), isFalse);
      expect(inDateRange(null), isTrue);
    });
  });

  group('تقرير البراد', () {
    late CoolerReport report;
    setUp(() {
      report = CoolerReport.build(
        detail: cooler14Detail(),
        payments: cooler14Payments(),
        packagingDetails: cooler14PackagingDetails(),
        generatedAt: generatedAt,
      );
    });

    test('المجاميع من العمليات الفعّالة فقط (الملغاة لا تُحتسب)', () {
      final t = report.totals;
      expect(t.operations, coolerOperations);
      expect(t.cancelled, 1);
      expect(t.boxes, coolerBoxes);
      expect(t.weightGrams, coolerWeight);
      expect(t.valuePiasters, coolerValue);
      expect(t.paidPiasters, coolerPaid);
      expect(t.remainingPiasters, coolerValue - coolerPaid);
    });

    test('المزارعون المختلفون: المكرر يُعدّ مرة، وصاحب العملية الملغاة فقط لا يُعدّ', () {
      // حسن البدري له عمليتان، وخالد منصور له عملية ملغاة فقط.
      expect(report.totals.farmers, 4);
      expect(report.farmers.map((f) => f.label), isNot(contains('خالد منصور')));
      final hassan = report.farmers.firstWhere((f) => f.key == 'FR-0001');
      expect(hassan.totals.operations, 2);
      expect(hassan.totals.boxes, 70);
      expect(hassan.totals.valuePiasters, 690000 + 558000);
      expect(hassan.totals.avgPricePerKgPiasters, 1522); // (690000 + 558000) × 1000 ÷ 820000
    });

    test('متوسط سعر الكيلو مرجّح = Σ القيمة ÷ Σ الوزن (لا متوسط الأسعار)', () {
      expect(report.totals.avgPricePerKgPiasters, 1492);
      // متوسط الأسعار البسيط (1500 + 1450 + 1550 + 1500 + 1475) ÷ 5 = 1495 ليس هو المطلوب.
      expect(report.totals.avgPricePerKgPiasters, isNot(1495));
      final doc = report.toDocument();
      expect(entry(doc.summary, 'متوسط سعر الكيلو').value.text, '14.92');
      expect(totalsRow(section(doc, 'عمليات الشراء'))[5], '14.92');
    });

    test('التعبئة: المعتمد فقط في التكلفة، والمتأخرة مميزة، والمسودة والملغاة خارج المجاميع', () {
      final p = report.packagingTotals;
      expect(p.approvedCount, 2);
      expect(p.approvedPiasters, coolerApprovedPackaging);
      expect(p.latePiasters, coolerLatePackaging);
      expect(p.lateCount, 1);
      expect(p.paidPiasters, 300000);
      expect(p.remainingPiasters, 150000);
      expect(p.draftCount, 1);
      expect(p.cancelledCount, 1);
      expect(report.totalCostPiasters, coolerValue + coolerApprovedPackaging);

      final doc = report.toDocument();
      expect(entry(doc.summary, 'تكلفة التعبئة المعتمدة').value.raw, '4500.00');
      expect(entry(doc.summary, 'منها تكلفة متأخرة').value.raw, '1500.00');
      expect(entry(doc.summary, 'إجمالي تكلفة البراد').value.raw, plainMinor(coolerValue + coolerApprovedPackaging, 2));

      final table = section(doc, 'مشتريات التعبئة').table!;
      final muted = {for (final r in table.rows) r.cells.first.text: r.muted};
      expect(muted, {'P-0001': false, 'P-0003': true, 'P-0004': true, 'P-0002': false});
      final late = table.rows.firstWhere((r) => r.cells.first.text == 'P-0002');
      expect(late.cells.last.text, 'نعم');
      expect(totalsRow(section(doc, 'مشتريات التعبئة'))[5], '4,500.00');
    });

    test('أصناف التعبئة للمعتمدة فقط', () {
      expect(report.approvedItems.keys, {'PK-0001', 'PK-0002'});
      final items = section(report.toDocument(), 'أصناف التعبئة المعتمدة').table!;
      expect(items.rows, hasLength(3));
      expect(items.totals!.last.raw, '4500.00');
    });

    test('مسودة لها تفاصيل لا تظهر أصنافها', () {
      final r = CoolerReport.build(
        detail: cooler14Detail(),
        packagingDetails: [
          PackagingDetail(packaging: cooler14Packaging()[2], items: [item('شبك', 10, 'قطعة', 100)]),
        ],
        generatedAt: generatedAt,
      );
      expect(r.approvedItems, isEmpty);
      expect(r.toDocument().sections.map((s) => s.title), isNot(contains('أصناف التعبئة المعتمدة')));
    });

    test('العمليات بترتيب زمني تصاعدي، والملغاة معروضة باهتة بحالة «ملغاة» وأصفار في المدفوع والمتبقي', () {
      expect(report.purchases.map((p) => p.id), ['PU-0001', 'PU-0002', 'PU-0003', 'PU-0004', 'PU-0005', 'PU-0006']);
      final table = section(report.toDocument(), 'عمليات الشراء').table!;
      final cancelled = table.rows[4];
      expect(cancelled.muted, isTrue);
      expect(cancelled.cells.last.text, 'ملغاة');
      expect(table.rows.where((r) => r.muted), hasLength(1));
      expect(
        totalsRow(section(report.toDocument(), 'عمليات الشراء')).sublist(6, 9),
        ['33,451.79', '20,000.00', '13,451.79'],
      );
    });

    test('الدفعات: الملغاة لا تُحتسب، والمجموع حسب نوع المستفيد', () {
      final t = report.paymentTotals;
      expect(t.cancelledCount, 1);
      expect(t.totalPiasters, 2300000);
      expect(t.amount(payee: PayeeType.farmer), 2000000);
      expect(t.amount(payee: PayeeType.supplier), 300000);
      expect(t.amount(method: PaymentMethod.bank), 700000);
      expect(t.count(), 5);
    });

    test('بعد التقفيل: مقارنة أرقام التقفيل بالحالية وتفسير الفروق', () {
      final lines = report.closeComparison!;
      int diff(String label) => lines.firstWhere((l) => l.label == label).difference;
      expect(diff('المدفوع للمزارعين'), 100000);
      expect(diff('المتبقي للمزارعين'), -100000);
      expect(diff('تكلفة التعبئة المعتمدة'), 150000);
      expect(diff('إجمالي تكلفة البراد'), 150000);
      expect(diff('قيمة المشتريات'), 0);

      final s = section(report.toDocument(), 'أرقام التقفيل مقارنة بالأرقام الحالية');
      final paidRow = s.table!.rows.firstWhere((r) => r.cells.first.text == 'المدفوع للمزارعين');
      expect(paidRow.cells.map((c) => c.text), ['المدفوع للمزارعين', '19,000.00', '20,000.00', '+1,000.00']);
      expect(paidRow.cells.last.raw, '1000.00');
      expect(s.table!.rows.first.cells.last.text, '—');
      expect(s.notes.join('\n'), contains('دفعات سُجّلت بعد التقفيل'));
      expect(s.notes.join('\n'), contains('تكلفة تعبئة متأخرة'));
    });

    test('براد مفتوح: لا مقارنة تقفيل ولا بيانات تقفيل في الرأس', () {
      final open = CoolerReport.build(detail: cooler14Detail(open: true), generatedAt: generatedAt);
      expect(open.closeComparison, isNull);
      final doc = open.toDocument();
      expect(doc.meta.map((e) => e.label), isNot(contains('وقت التقفيل')));
      expect(doc.subtitle, 'شحنة دمياط · مفتوح');
    });

    test('الرأس واسم الملف', () {
      final doc = report.toDocument();
      expect(doc.title, 'تقرير البراد 14');
      expect(doc.fileStem, 'تقرير-البراد-14');
      expect(doc.asciiFileStem, 'cooler-report-14');
      expect(entry(doc.meta, 'السائق').text, 'سامي عطية');
      expect(entry(doc.meta, 'قفّله').text, 'كريم عبد الله');
      expect(doc.generatedAtText, '2026-10-03 · 09:15\u00A0ص');
    });

    test('لا أرقام أرباح في أي مكان', () {
      final doc = report.toDocument();
      final labels = [
        ...doc.summary.map((e) => e.label),
        for (final s in doc.sections) ...[
          s.title,
          ...s.entries.map((e) => e.label),
          ...?s.table?.columns.map((c) => c.title),
        ],
      ];
      expect(labels.where((l) => l.contains('ربح') || l.contains('أرباح')), isEmpty);
    });

    test('العملة من الإعدادات تظهر في العناوين والملخص', () {
      final doc = CoolerReport.build(detail: cooler14Detail(), currency: 'EGP', generatedAt: generatedAt).toDocument();
      expect(entry(doc.summary, 'قيمة المشتريات').text, '33,451.79 EGP');
      expect(section(doc, 'عمليات الشراء').table!.columns[6].title, 'القيمة (EGP)');
    });
  });

  group('كشف حساب المزارع', () {
    test('كل العمليات في كل البرادات: القيمة والمدفوع والمتبقي (دون الملغاة)', () {
      final s = FarmerStatement.build(
        farmer: farmer1,
        purchases: farmer1Purchases(),
        payments: farmer1Payments(),
        generatedAt: generatedAt,
      );
      expect(s.purchases, hasLength(4));
      expect(s.totals.operations, 3);
      expect(s.valuePiasters, 690000 + 558000 + 330000);
      expect(s.paidPiasters, 690000 + 330000);
      expect(s.remainingPiasters, 558000);
      expect(s.paymentTotals.totalPiasters, 1020000);
      expect(s.paymentTotals.cancelledCount, 1);

      final doc = s.toDocument();
      expect(entry(doc.summary, 'المتبقي للمزارع').value.raw, '5580.00');
      expect(entry(doc.summary, 'متوسط سعر الكيلو').value.text, '15.17');
      final table = section(doc, 'عمليات الشراء').table!;
      expect(table.rows.map((r) => r.cells[1].text), ['13', '13', '14', '14']);
      expect(totalsRow(section(doc, 'عمليات الشراء')).sublist(5, 8), ['15,780.00', '10,200.00', '5,580.00']);
      expect(doc.fileStem, 'كشف-حساب-حسن-البدري');
      expect(doc.asciiFileStem, 'farmer-statement-1');
    });

    test('الفترة تقصر العمليات والدفعات على تاريخها', () {
      final s = FarmerStatement.build(
        farmer: farmer1,
        purchases: farmer1Purchases(),
        payments: farmer1Payments(),
        from: DateTime(2026, 10, 2),
        to: DateTime(2026, 10, 2),
        generatedAt: generatedAt,
      );
      expect(s.purchases.map((p) => p.id), ['PU-0001', 'PU-0003']);
      expect(s.payments.map((p) => p.id), ['PY-0001']);
      expect(s.valuePiasters, 1248000);
      expect(s.remainingPiasters, 558000);
      final doc = s.toDocument();
      expect(doc.subtitle, 'حسن البدري · 2026-10-02');
      expect(entry(doc.meta, 'الفترة').text, '2026-10-02');
    });

    test('سجلات مزارع آخر تُتجاهل', () {
      final s = FarmerStatement.build(
        farmer: farmer1,
        purchases: cooler14Purchases(),
        payments: cooler14Payments(),
        generatedAt: generatedAt,
      );
      expect(s.purchases.every((p) => p.farmerId == 'FR-0001'), isTrue);
      expect(s.payments.map((p) => p.id), ['PY-0001']);
    });
  });

  group('تقرير الموردين', () {
    late SupplierReport report;
    setUp(() {
      report = SupplierReport.build(
        packaging: [
          ...cooler14Packaging(),
          packaging('PK-0005',
              no: 'P-0005', supplier: '  مصنع  الكرتون ', status: PackagingStatus.approved, total: 70000,
              paid: 20000, coolerId: null, coolerNo: null),
        ],
        details: cooler14PackagingDetails(),
        generatedAt: generatedAt,
      );
    });

    test('التجميع حسب المورد: المعتمد فقط في المجاميع', () {
      expect(report.groups.map((g) => g.name), ['الشبك الحديث', 'مصنع الكرتون']);
      final carton = report.groups.last;
      expect(carton.totals.approvedCount, 3);
      expect(carton.totals.approvedPiasters, 520000);
      expect(carton.totals.paidPiasters, 320000);
      expect(carton.totals.remainingPiasters, 200000);
      final net = report.groups.first;
      expect(net.totals.approvedPiasters, 0);
      expect(net.totals.draftCount, 1);
      expect(report.totals.approvedPiasters, 520000);
    });

    test('المسودات والملغاة في أقسام مستقلة لا تدخل في المجاميع', () {
      final doc = report.toDocument();
      final drafts = section(doc, 'مسودات (لا تدخل في المجاميع)').table!;
      expect(drafts.rows.single.cells.first.text, 'P-0003');
      expect(drafts.rows.single.muted, isTrue);
      expect(drafts.totals, isNull);
      expect(section(doc, 'مشتريات ملغاة (لا تدخل في المجاميع)').table!.rows.single.cells.first.text, 'P-0004');
      expect(entry(doc.summary, 'إجمالي المعتمد').value.raw, '5200.00');
      expect(entry(doc.summary, 'المتبقي للموردين').value.raw, '2000.00');
      expect(entry(doc.summary, 'مسودات غير محتسبة').value.text, '1');
      expect(doc.sections.map((s) => s.title), contains('المورد: مصنع الكرتون'));
      expect(doc.sections.map((s) => s.title), isNot(contains('المورد: الشبك الحديث')));
      expect(section(doc, 'أصناف مصنع الكرتون').table!.rows, hasLength(3));
    });

    test('مورد واحد: مطابقة الاسم دون مسافات زائدة', () {
      final one = SupplierReport.build(
        packaging: [
          ...cooler14Packaging(),
          packaging('PK-0006', no: 'P-0006', supplier: 'آخر', status: PackagingStatus.approved, total: 1),
        ],
        supplier: 'مصنع الكرتون ',
        generatedAt: generatedAt,
      );
      expect(one.groups.single.name, 'مصنع الكرتون');
      final doc = one.toDocument();
      expect(doc.title, 'تقرير المورد');
      expect(doc.subtitle, 'مصنع الكرتون');
      expect(doc.sections.map((s) => s.title), isNot(contains('ملخص حسب المورد')));
    });
  });

  group('تقرير الفترة', () {
    late PeriodReport report;
    setUp(() {
      report = PeriodReport.build(
        from: DateTime(2026, 10, 2),
        to: DateTime(2026, 10, 2),
        purchases: [...cooler14Purchases(), ...farmer1Purchases().where((p) => p.coolerNo == 13)],
        payments: [...cooler14Payments(), ...farmer1Payments().where((p) => p.coolerNo == 13)],
        packaging: [
          ...cooler14Packaging(),
          packaging('PK-0007',
              no: 'P-0007', supplier: 'الشبك الحديث', status: PackagingStatus.approved, total: 25000,
              coolerId: 'CL-0012', coolerNo: 12),
          packaging('PK-0008',
              no: 'P-0008', supplier: 'مخزن عام', status: PackagingStatus.approved, total: 10000, coolerId: null,
              coolerNo: null),
        ],
        coolers: [cooler14(), CoolerSummary(id: 'CL-0012', no: 12, name: 'شحنة بورسعيد', isOpen: false)],
        generatedAt: generatedAt,
      );
    });

    test('العمليات بوقت العملية، والدفعات بوقت الدفع، والتعبئة بتاريخ الشراء', () {
      expect(report.purchases.every((p) => p.occurredAt.startsWith('2026-10-02')), isTrue);
      expect(report.totals.operations, coolerOperations);
      expect(report.totals.valuePiasters, coolerValue);
      // PY-0004 (3 أكتوبر) وPY-0007 وPY-0008 (1 أكتوبر) خارج الفترة، وPY-0006 ملغاة.
      expect(report.paymentTotals.totalPiasters, 690000 + 400000 + 810000 + 300000);
      expect(report.paymentTotals.cancelledCount, 1);
      // PK-0002 (3 أكتوبر) خارج الفترة.
      expect(report.packagingTotals.approvedPiasters, 300000 + 25000 + 10000);
    });

    test('التفصيل حسب البراد مع براد له تعبئة فقط و«بدون براد» في الآخر', () {
      expect(report.coolers.map((c) => c.label), ['براد 12 · شحنة بورسعيد', 'براد 14 · شحنة دمياط', 'بدون براد']);
      final c14 = report.coolers[1];
      expect(c14.totals.farmers, 4);
      expect(c14.packagingPiasters, 300000);
      expect(c14.totalCostPiasters, coolerValue + 300000);
      expect(report.coolers.first.totals.operations, 0);
      expect(report.coolers.first.packagingPiasters, 25000);
    });

    test('الدفعات حسب الطريقة ونوع المستفيد', () {
      final s = section(report.toDocument(), 'الدفعات حسب الطريقة والمستفيد');
      final rows = {for (final r in s.table!.rows) r.cells.first.text: r.cells.map((c) => c.raw).toList()};
      expect(rows['نقدًا'], ['نقدًا', '15000.00', '0.00', '15000.00', '2']);
      expect(rows['تحويل بنكي'], ['تحويل بنكي', '4000.00', '3000.00', '7000.00', '2']);
      expect(rows['محفظة إلكترونية'], ['محفظة إلكترونية', '0.00', '0.00', '0.00', '0']);
      expect([for (final c in s.table!.totals!) c.raw], ['الإجمالي', '19000.00', '3000.00', '22000.00', '4']);
    });

    test('الملخص واسم الملف', () {
      final doc = report.toDocument();
      expect(doc.subtitle, '2026-10-02');
      expect(doc.fileStem, 'تقرير-الفترة-2026-10-02-الى-2026-10-02');
      expect(doc.asciiFileStem, 'period-report-2026-10-02_2026-10-02');
      expect(entry(doc.summary, 'عدد المزارعين').value.text, '4');
      expect(entry(doc.summary, 'إجمالي التكلفة').value.raw, plainMinor(coolerValue + 335000, 2));
    });
  });
}
