/// تقرير فترة: ملخص مشتريات الرمان، والتفصيل حسب البراد، ومجاميع التعبئة، ومجاميع الدفعات حسب الطريقة
/// ونوع المستفيد. العمليات بوقت العملية، والدفعات بوقت الدفع، والتعبئة بتاريخ الشراء.
library;

import '../models/dashboard.dart';
import '../models/records.dart';
import 'report_document.dart';
import 'report_format.dart';
import 'report_totals.dart';

/// سطر براد في تقرير الفترة.
class PeriodCoolerLine {
  const PeriodCoolerLine({
    required this.coolerId,
    required this.no,
    required this.name,
    this.isOpen,
    required this.totals,
    required this.packagingPiasters,
  });

  /// '' لمشتريات تعبئة غير مرتبطة ببراد.
  final String coolerId;
  final int no;
  final String name;

  /// null إن لم يكن البراد في قائمة البرادات.
  final bool? isOpen;
  final PurchaseTotals totals;

  /// تكلفة التعبئة المعتمدة في الفترة لهذا البراد.
  final int packagingPiasters;

  int get totalCostPiasters => totals.valuePiasters + packagingPiasters;

  String get label {
    if (coolerId.isEmpty) return 'بدون براد';
    if (no <= 0) return coolerId;
    return name.isEmpty ? 'براد $no' : 'براد $no · $name';
  }
}

class PeriodReport {
  PeriodReport._({
    required this.from,
    required this.to,
    required this.purchases,
    required this.payments,
    required this.packaging,
    required this.totals,
    required this.coolers,
    required this.packagingTotals,
    required this.paymentTotals,
    required this.generatedAt,
    required this.currency,
  });

  /// [purchases]: purchases.list(from, to) — الملغاة إن وُجدت تُعدّ فقط ولا تُحتسب.
  /// [payments]: payments.list() (تُصفّى هنا بوقت الدفع). [packaging]: packaging.list() (تُصفّى بتاريخ الشراء).
  /// [coolers]: coolers.list(all) لأسماء البرادات وحالاتها.
  factory PeriodReport.build({
    DateTime? from,
    DateTime? to,
    required List<Purchase> purchases,
    required List<Payment> payments,
    required List<PackagingSummary> packaging,
    List<CoolerSummary> coolers = const [],
    DateTime? generatedAt,
    String currency = kReportCurrency,
  }) {
    final ps = [for (final p in purchases) if (inDateRange(p.occurredAt, from: from, to: to)) p]
      ..sort((a, b) => compareByTime(a.occurredAt, a.id, b.occurredAt, b.id));
    final pays = [for (final p in payments) if (inDateRange(p.paidAt, from: from, to: to)) p]
      ..sort((a, b) => compareByTime(a.paidAt, a.id, b.paidAt, b.id));
    final pk = [for (final p in packaging) if (inDateRange(p.occurredAt, from: from, to: to)) p]
      ..sort((a, b) => compareByTime(a.occurredAt, a.id, b.occurredAt, b.id));

    final known = {for (final c in coolers) c.id: c};
    final byCooler = <String, List<Purchase>>{};
    final numbers = <String, int>{};
    for (final p in ps) {
      if (!p.active) continue;
      byCooler.putIfAbsent(p.coolerId, () => []).add(p);
      numbers.putIfAbsent(p.coolerId, () => p.coolerNo);
    }
    final packagingByCooler = <String, int>{};
    for (final p in pk) {
      if (p.status != PackagingStatus.approved) continue;
      final id = p.coolerId ?? '';
      packagingByCooler[id] = (packagingByCooler[id] ?? 0) + p.completeTotalPiasters;
      if (p.coolerNo != null) numbers.putIfAbsent(id, () => p.coolerNo!);
    }
    final lines = [
      for (final id in {...byCooler.keys, ...packagingByCooler.keys})
        PeriodCoolerLine(
          coolerId: id,
          no: known[id]?.no ?? numbers[id] ?? 0,
          name: known[id]?.name ?? '',
          isOpen: known[id]?.isOpen,
          totals: PurchaseTotals.of(byCooler[id] ?? const []),
          packagingPiasters: packagingByCooler[id] ?? 0,
        ),
    ]..sort((a, b) {
        // البرادات بالرقم، و«بدون براد» في الآخر.
        if (a.coolerId.isEmpty != b.coolerId.isEmpty) return a.coolerId.isEmpty ? 1 : -1;
        final c = a.no.compareTo(b.no);
        return c != 0 ? c : a.coolerId.compareTo(b.coolerId);
      });

    return PeriodReport._(
      from: from,
      to: to,
      purchases: ps,
      payments: pays,
      packaging: pk,
      totals: PurchaseTotals.of(ps),
      coolers: lines,
      packagingTotals: PackagingTotals.of(pk),
      paymentTotals: PaymentTotals.of(pays),
      generatedAt: generatedAt ?? DateTime.now(),
      currency: currency,
    );
  }

  final DateTime? from;
  final DateTime? to;
  final List<Purchase> purchases;
  final List<Payment> payments;
  final List<PackagingSummary> packaging;
  final PurchaseTotals totals;

  /// التفصيل حسب البراد (مرتب بالرقم).
  final List<PeriodCoolerLine> coolers;
  final PackagingTotals packagingTotals;
  final PaymentTotals paymentTotals;
  final DateTime generatedAt;
  final String currency;

  /// قيمة المشتريات + تكلفة التعبئة المعتمدة في الفترة.
  int get totalCostPiasters => totals.valuePiasters + packagingTotals.approvedPiasters;

  ReportDocument toDocument() {
    final m = currency;
    final range = dateRangeText(from, to);
    final stemRange = from == null && to == null
        ? 'كل-الفترات'
        : [if (from != null) dateKey(from!), if (to != null) dateKey(to!)].join('-الى-');
    final asciiRange = [if (from != null) dateKey(from!), if (to != null) dateKey(to!)].join('_');
    return ReportDocument(
      title: 'تقرير الفترة',
      subtitle: range,
      generatedAt: generatedAt,
      fileStem: 'تقرير-الفترة-$stemRange',
      asciiFileStem: asciiRange.isEmpty ? 'period-report' : 'period-report-$asciiRange',
      meta: [ReportEntry.text('الفترة', range)],
      summary: [
        ReportEntry('عدد المزارعين', ReportCell.count(totals.farmers)),
        ReportEntry('عمليات الشراء', ReportCell.count(totals.operations)),
        ReportEntry('الصناديق', ReportCell.count(totals.boxes)),
        ReportEntry('إجمالي الوزن', ReportCell.weight(totals.weightGrams), unit: kReportWeightUnit),
        ReportEntry('قيمة المشتريات', ReportCell.money(totals.valuePiasters), unit: m),
        ReportEntry('متوسط سعر الكيلو', ReportCell.money(totals.avgPricePerKgPiasters), unit: '$m/$kReportWeightUnit'),
        ReportEntry('تكلفة التعبئة المعتمدة', ReportCell.money(packagingTotals.approvedPiasters), unit: m),
        ReportEntry('إجمالي التكلفة', ReportCell.money(totalCostPiasters), unit: m, highlight: true),
        ReportEntry('الدفعات في الفترة', ReportCell.money(paymentTotals.totalPiasters), unit: m),
        ReportEntry(
          'المتبقي على عمليات الفترة',
          ReportCell.money(totals.remainingPiasters + packagingTotals.remainingPiasters),
          unit: m,
          highlight: true,
        ),
      ],
      sections: [
        _purchasesSection(),
        _coolersSection(),
        _packagingSection(),
        _paymentsSection(),
      ],
    );
  }

  ReportSection _purchasesSection() {
    final m = currency;
    return ReportSection(
      title: 'مشتريات الرمان',
      entries: [
        ReportEntry('عمليات الشراء', ReportCell.count(totals.operations)),
        ReportEntry('عدد المزارعين', ReportCell.count(totals.farmers)),
        ReportEntry('الصناديق', ReportCell.count(totals.boxes)),
        ReportEntry('متوسط وزن الصندوق', ReportCell.weight(totals.avgBoxGrams, decimals: 2), unit: kReportWeightUnit),
        ReportEntry('إجمالي الوزن', ReportCell.weight(totals.weightGrams), unit: kReportWeightUnit),
        ReportEntry('قيمة المشتريات', ReportCell.money(totals.valuePiasters), unit: m),
        ReportEntry('متوسط سعر الكيلو', ReportCell.money(totals.avgPricePerKgPiasters), unit: '$m/$kReportWeightUnit'),
        ReportEntry('المدفوع على هذه العمليات', ReportCell.money(totals.paidPiasters), unit: m),
        ReportEntry('المتبقي للمزارعين', ReportCell.money(totals.remainingPiasters), unit: m, highlight: true),
      ],
      notes: [
        'المدفوع والمتبقي يخصان عمليات الفترة ويشملان كل دفعاتها حتى تاريخ التقرير.',
        if (totals.cancelled > 0) 'العمليات الملغاة (${totals.cancelled}) لا تدخل في أي مجموع.',
      ],
    );
  }

  ReportSection _coolersSection() {
    final m = currency;
    return ReportSection(
      title: 'حسب البراد',
      table: ReportTable(
        columns: [
          const ReportColumn('البراد', flex: 1.7),
          const ReportColumn('الحالة', flex: 0.7),
          const ReportColumn('المزارعون', numeric: true, flex: 0.75),
          const ReportColumn('العمليات', numeric: true, flex: 0.7),
          const ReportColumn('الصناديق', numeric: true, flex: 0.8),
          const ReportColumn('الوزن ($kReportWeightUnit)', numeric: true),
          ReportColumn('متوسط سعر الكيلو ($m)', numeric: true, flex: 0.9),
          ReportColumn('القيمة ($m)', numeric: true, flex: 1.15),
          ReportColumn('التعبئة المعتمدة ($m)', numeric: true, flex: 1.1),
          ReportColumn('إجمالي التكلفة ($m)', numeric: true, flex: 1.15),
        ],
        rows: [
          for (final c in coolers)
            ReportRow([
              ReportCell(c.label),
              ReportCell(c.isOpen == null ? '' : (c.isOpen! ? 'مفتوح' : 'مقفّل')),
              ReportCell.count(c.totals.farmers),
              ReportCell.count(c.totals.operations),
              ReportCell.count(c.totals.boxes),
              ReportCell.weight(c.totals.weightGrams),
              ReportCell.money(c.totals.avgPricePerKgPiasters),
              ReportCell.money(c.totals.valuePiasters),
              ReportCell.money(c.packagingPiasters),
              ReportCell.money(c.totalCostPiasters),
            ]),
        ],
        totals: [
          const ReportCell('الإجمالي'),
          ReportCell.empty,
          ReportCell.count(totals.farmers),
          ReportCell.count(totals.operations),
          ReportCell.count(totals.boxes),
          ReportCell.weight(totals.weightGrams),
          ReportCell.money(totals.avgPricePerKgPiasters),
          ReportCell.money(totals.valuePiasters),
          ReportCell.money(packagingTotals.approvedPiasters),
          ReportCell.money(totalCostPiasters),
        ],
        emptyText: 'لا توجد عمليات أو مشتريات تعبئة معتمدة في هذه الفترة.',
      ),
      notes: const ['عدد المزارعين في الإجمالي يعدّ كل مزارع مرة واحدة وإن ورّد لأكثر من براد.'],
    );
  }

  ReportSection _packagingSection() {
    final m = currency;
    final t = packagingTotals;
    final bySupplier = <String, List<PackagingSummary>>{};
    for (final p in packaging) {
      if (p.status != PackagingStatus.approved) continue;
      bySupplier.putIfAbsent(supplierName(p.supplier), () => []).add(p);
    }
    final names = bySupplier.keys.toList()..sort();
    final perSupplier = {for (final n in names) n: PackagingTotals.of(bySupplier[n]!)};
    return ReportSection(
      title: 'مشتريات التعبئة',
      entries: [
        ReportEntry('مشتريات معتمدة', ReportCell.count(t.approvedCount)),
        ReportEntry('التكلفة المعتمدة', ReportCell.money(t.approvedPiasters), unit: m, highlight: true),
        if (t.latePiasters > 0) ReportEntry('منها تكلفة متأخرة', ReportCell.money(t.latePiasters), unit: m),
        ReportEntry('المدفوع للموردين', ReportCell.money(t.paidPiasters), unit: m),
        ReportEntry('المتبقي للموردين', ReportCell.money(t.remainingPiasters), unit: m),
        if (t.draftCount > 0) ReportEntry('مسودات غير محتسبة', ReportCell.count(t.draftCount)),
      ],
      table: ReportTable(
        columns: [
          const ReportColumn('المورد', flex: 2),
          const ReportColumn('المشتريات المعتمدة', numeric: true, flex: 0.9),
          ReportColumn('الإجمالي ($m)', numeric: true, flex: 1.2),
          ReportColumn('المدفوع ($m)', numeric: true, flex: 1.2),
          ReportColumn('المتبقي ($m)', numeric: true, flex: 1.2),
        ],
        rows: [
          for (final e in perSupplier.entries)
            ReportRow([
              ReportCell(e.key),
              ReportCell.count(e.value.approvedCount),
              ReportCell.money(e.value.approvedPiasters),
              ReportCell.money(e.value.paidPiasters),
              ReportCell.money(e.value.remainingPiasters),
            ]),
        ],
        totals: [
          const ReportCell('الإجمالي'),
          ReportCell.count(t.approvedCount),
          ReportCell.money(t.approvedPiasters),
          ReportCell.money(t.paidPiasters),
          ReportCell.money(t.remainingPiasters),
        ],
        emptyText: 'لا توجد مشتريات تعبئة معتمدة في هذه الفترة.',
      ),
      notes: [
        if (t.draftCount > 0) 'المسودات (${t.draftCount}) لا تدخل في التكلفة حتى تُعتمد.',
        if (t.cancelledCount > 0) 'المشتريات الملغاة (${t.cancelledCount}) لا تدخل في أي مجموع.',
      ],
    );
  }

  ReportSection _paymentsSection() {
    final m = currency;
    final t = paymentTotals;
    return ReportSection(
      title: 'الدفعات حسب الطريقة والمستفيد',
      entries: [
        ReportEntry('للمزارعين', ReportCell.money(t.amount(payee: PayeeType.farmer)), unit: m),
        ReportEntry('للموردين', ReportCell.money(t.amount(payee: PayeeType.supplier)), unit: m),
        ReportEntry('إجمالي الدفعات', ReportCell.money(t.totalPiasters), unit: m, highlight: true),
      ],
      table: ReportTable(
        columns: [
          const ReportColumn('طريقة الدفع', flex: 1.3),
          ReportColumn('للمزارعين ($m)', numeric: true, flex: 1.2),
          ReportColumn('للموردين ($m)', numeric: true, flex: 1.2),
          ReportColumn('الإجمالي ($m)', numeric: true, flex: 1.2),
          const ReportColumn('عدد الدفعات', numeric: true, flex: 0.8),
        ],
        rows: [
          for (final method in PaymentMethod.values)
            ReportRow([
              ReportCell(method.label),
              ReportCell.money(t.amount(method: method, payee: PayeeType.farmer)),
              ReportCell.money(t.amount(method: method, payee: PayeeType.supplier)),
              ReportCell.money(t.amount(method: method)),
              ReportCell.count(t.count(method: method)),
            ]),
        ],
        totals: [
          const ReportCell('الإجمالي'),
          ReportCell.money(t.amount(payee: PayeeType.farmer)),
          ReportCell.money(t.amount(payee: PayeeType.supplier)),
          ReportCell.money(t.totalPiasters),
          ReportCell.count(t.activeCount),
        ],
      ),
      notes: [
        'الدفعات بوقت الدفع: قد تخص عمليات من فترات سابقة.',
        if (t.cancelledCount > 0) 'الدفعات الملغاة (${t.cancelledCount}) لا تدخل في المجاميع.',
      ],
    );
  }
}
