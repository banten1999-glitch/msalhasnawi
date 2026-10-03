/// تقرير البراد المفصّل: الرأس، الملخص، عمليات الشراء، التجميع حسب المزارع، التعبئة وأصنافها، الدفعات،
/// ومقارنة أرقام التقفيل بالأرقام الحالية. دوال نقية فوق السجلات (بلا خادم)، فتُختبر مباشرة.
library;

import '../models/dashboard.dart';
import '../models/records.dart';
import 'report_document.dart';
import 'report_format.dart';
import 'report_totals.dart';

/// بند في مقارنة «عند التقفيل» بـ«الآن».
class CloseComparisonLine {
  const CloseComparisonLine(this.label, this.atClose, this.now, this.kind);

  final String label;
  final int atClose;
  final int now;

  /// نوع القيمة: عدد، وزن بالجرام، أو مبلغ بالقرش.
  final ReportValueKind kind;

  int get difference => now - atClose;
}

enum ReportValueKind { count, weight, money }

ReportCell _valueCell(int v, ReportValueKind kind) => switch (kind) {
      ReportValueKind.count => ReportCell.count(v),
      ReportValueKind.weight => ReportCell.weight(v),
      ReportValueKind.money => ReportCell.money(v),
    };

/// الفرق بإشارة صريحة: «+1,000.00»، و«—» إن لم يوجد فرق.
ReportCell _diffCell(int diff, ReportValueKind kind) {
  if (diff == 0) return const ReportCell('—', rawValue: '0');
  final c = _valueCell(diff, kind);
  return diff > 0 ? ReportCell('+${c.text}', rawValue: c.raw) : c;
}

class CoolerReport {
  CoolerReport._({
    required this.cooler,
    required this.purchases,
    required this.totals,
    required this.farmers,
    required this.packaging,
    required this.packagingTotals,
    required this.approvedItems,
    required this.payments,
    required this.paymentTotals,
    required this.generatedAt,
    required this.currency,
  });

  /// [detail]: نتيجة coolers.get (كل العمليات بما فيها الملغاة، وكل مشتريات التعبئة المرتبطة).
  /// [payments]: payments.list(coolerId) بما فيها الملغاة. [packagingDetails]: packaging.get لمشتريات التعبئة
  /// المعتمدة المرتبطة (لأسطر الأصناف)؛ غيرها يُتجاهل.
  factory CoolerReport.build({
    required CoolerDetail detail,
    List<Payment> payments = const [],
    Iterable<PackagingDetail> packagingDetails = const [],
    DateTime? generatedAt,
    String currency = kReportCurrency,
  }) {
    final purchases = [...detail.purchases]
      ..sort((a, b) => compareByTime(a.occurredAt, a.id, b.occurredAt, b.id));
    final packaging = [...detail.packaging]..sort((a, b) => compareByTime(a.occurredAt, a.id, b.occurredAt, b.id));
    final approvedIds = {for (final p in packaging) if (p.status == PackagingStatus.approved) p.id};
    final items = <String, List<PackagingItem>>{
      for (final d in packagingDetails)
        if (approvedIds.contains(d.packaging.id))
          d.packaging.id: [for (final i in d.items) if (i.status != PackagingItemStatus.removed) i],
    };
    final pays = [...payments]..sort((a, b) => compareByTime(a.paidAt, a.id, b.paidAt, b.id));
    return CoolerReport._(
      cooler: detail.cooler,
      purchases: purchases,
      totals: PurchaseTotals.of(purchases),
      farmers: PurchaseGroup.byFarmer(purchases),
      packaging: packaging,
      packagingTotals: PackagingTotals.of(packaging),
      approvedItems: items,
      payments: pays,
      paymentTotals: PaymentTotals.of(pays),
      generatedAt: generatedAt ?? DateTime.now(),
      currency: currency,
    );
  }

  final CoolerSummary cooler;

  /// كل العمليات بترتيب زمني تصاعدي؛ الملغاة معروضة ولا تُحتسب.
  final List<Purchase> purchases;
  final PurchaseTotals totals;

  /// العمليات الفعّالة مجمّعة حسب المزارع.
  final List<PurchaseGroup> farmers;
  final List<PackagingSummary> packaging;
  final PackagingTotals packagingTotals;

  /// أصناف كل شراء تعبئة معتمد: المعرّف ← الأصناف.
  final Map<String, List<PackagingItem>> approvedItems;
  final List<Payment> payments;
  final PaymentTotals paymentTotals;
  final DateTime generatedAt;
  final String currency;

  /// إجمالي تكلفة البراد = قيمة المشتريات + تكلفة التعبئة المعتمدة.
  int get totalCostPiasters => totals.valuePiasters + packagingTotals.approvedPiasters;

  /// مقارنة أرقام التقفيل بالأرقام الحالية؛ null لبراد مفتوح أو بلا أرقام تقفيل.
  List<CloseComparisonLine>? get closeComparison {
    final s = cooler.closeSnapshot;
    if (cooler.isOpen || s == null) return null;
    return [
      CloseComparisonLine('عدد المزارعين', s.farmers, totals.farmers, ReportValueKind.count),
      CloseComparisonLine('عمليات الشراء', s.purchases, totals.operations, ReportValueKind.count),
      CloseComparisonLine('الصناديق', s.boxes, totals.boxes, ReportValueKind.count),
      CloseComparisonLine('الوزن ($kReportWeightUnit)', s.weightGrams, totals.weightGrams, ReportValueKind.weight),
      CloseComparisonLine('قيمة المشتريات', s.valuePiasters, totals.valuePiasters, ReportValueKind.money),
      CloseComparisonLine('المدفوع للمزارعين', s.paidPiasters, totals.paidPiasters, ReportValueKind.money),
      CloseComparisonLine('المتبقي للمزارعين', s.remainingPiasters, totals.remainingPiasters, ReportValueKind.money),
      CloseComparisonLine(
          'تكلفة التعبئة المعتمدة', s.packagingPiasters, packagingTotals.approvedPiasters, ReportValueKind.money),
      CloseComparisonLine('إجمالي تكلفة البراد', s.totalCostPiasters, totalCostPiasters, ReportValueKind.money),
    ];
  }

  String get _statusText => cooler.isOpen ? 'مفتوح' : 'مقفّل';

  ReportDocument toDocument() {
    final c = cooler;
    final money = currency;
    return ReportDocument(
      title: 'تقرير البراد ${c.no}',
      subtitle: [if (c.name.isNotEmpty) c.name, _statusText].join(' · '),
      generatedAt: generatedAt,
      fileStem: 'تقرير-البراد-${c.no}',
      asciiFileStem: 'cooler-report-${c.no}',
      meta: [
        ReportEntry('رقم البراد', ReportCell.count(c.no)),
        if (c.name.isNotEmpty) ReportEntry.text('اسم البراد', c.name),
        ReportEntry.text('الحالة', _statusText),
        ReportEntry('وقت الفتح', ReportCell.time(c.openedAt)),
        if (c.openedBy != null) ReportEntry.text('فتحه', c.openedBy!),
        if (!c.isOpen) ReportEntry('وقت التقفيل', ReportCell.time(c.closedAt)),
        if (!c.isOpen && c.closedBy != null) ReportEntry.text('قفّله', c.closedBy!),
        ReportEntry.text('رقم السيارة', c.carNo ?? '—'),
        ReportEntry.text('السائق', c.driver ?? '—'),
        if (c.notes != null) ReportEntry.text('ملاحظات', c.notes!),
      ],
      summary: [
        ReportEntry('عدد المزارعين', ReportCell.count(totals.farmers)),
        ReportEntry('عمليات الشراء', ReportCell.count(totals.operations)),
        ReportEntry('الصناديق', ReportCell.count(totals.boxes)),
        ReportEntry('إجمالي الوزن', ReportCell.weight(totals.weightGrams), unit: kReportWeightUnit),
        ReportEntry('قيمة المشتريات', ReportCell.money(totals.valuePiasters), unit: money),
        ReportEntry('المدفوع للمزارعين', ReportCell.money(totals.paidPiasters), unit: money),
        ReportEntry('المتبقي للمزارعين', ReportCell.money(totals.remainingPiasters), unit: money, highlight: true),
        ReportEntry('تكلفة التعبئة المعتمدة', ReportCell.money(packagingTotals.approvedPiasters), unit: money),
        if (packagingTotals.latePiasters > 0)
          ReportEntry('منها تكلفة متأخرة', ReportCell.money(packagingTotals.latePiasters), unit: money),
        ReportEntry('إجمالي تكلفة البراد', ReportCell.money(totalCostPiasters), unit: money, highlight: true),
        ReportEntry('متوسط سعر الكيلو', ReportCell.money(totals.avgPricePerKgPiasters), unit: '$money/$kReportWeightUnit'),
      ],
      sections: [
        _purchasesSection(),
        _farmersSection(),
        _packagingSection(),
        if (approvedItems.values.any((l) => l.isNotEmpty)) _itemsSection(),
        _paymentsSection(),
        if (closeComparison != null) _closeSection(closeComparison!),
      ],
    );
  }

  ReportSection _purchasesSection() {
    final m = currency;
    return ReportSection(
      title: 'عمليات الشراء',
      table: ReportTable(
        columns: [
          const ReportColumn('الوقت', flex: 1.75),
          const ReportColumn('المزارع', flex: 1.45),
          const ReportColumn('الصناديق', numeric: true, flex: 0.8),
          const ReportColumn('متوسط الصندوق ($kReportWeightUnit)', numeric: true, flex: 0.9),
          const ReportColumn('الوزن ($kReportWeightUnit)', numeric: true),
          ReportColumn('سعر الكيلو ($m)', numeric: true, flex: 0.85),
          ReportColumn('القيمة ($m)', numeric: true, flex: 1.15),
          ReportColumn('المدفوع ($m)', numeric: true, flex: 1.15),
          ReportColumn('المتبقي ($m)', numeric: true, flex: 1.15),
          const ReportColumn('الحالة', flex: 0.8),
        ],
        rows: [
          for (final p in purchases)
            ReportRow([
              ReportCell.time(p.occurredAt),
              ReportCell(p.farmerName),
              ReportCell.count(p.boxes),
              ReportCell.weight(p.avgWeightGrams, decimals: 2),
              ReportCell.weight(p.totalWeightGrams),
              ReportCell.money(p.pricePerKgPiasters),
              ReportCell.money(p.valuePiasters),
              ReportCell.money(p.active ? p.paidPiasters : 0),
              ReportCell.money(p.active ? p.remainingPiasters : 0),
              ReportCell(purchaseStatusText(p)),
            ], muted: !p.active),
        ],
        totals: [
          const ReportCell('الإجمالي'),
          ReportCell.empty,
          ReportCell.count(totals.boxes),
          ReportCell.weight(totals.avgBoxGrams, decimals: 2),
          ReportCell.weight(totals.weightGrams),
          ReportCell.money(totals.avgPricePerKgPiasters),
          ReportCell.money(totals.valuePiasters),
          ReportCell.money(totals.paidPiasters),
          ReportCell.money(totals.remainingPiasters),
          ReportCell.empty,
        ],
        emptyText: 'لا توجد عمليات شراء في هذا البراد.',
      ),
      notes: [
        'سعر الكيلو في الإجمالي متوسط مرجّح = مجموع القيمة ÷ مجموع الوزن.',
        if (totals.cancelled > 0) 'العمليات الملغاة (${totals.cancelled}) معروضة للعلم ولا تدخل في أي مجموع.',
      ],
    );
  }

  ReportSection _farmersSection() {
    final m = currency;
    return ReportSection(
      title: 'حسب المزارع',
      table: ReportTable(
        columns: [
          const ReportColumn('المزارع', flex: 1.8),
          const ReportColumn('العمليات', numeric: true, flex: 0.7),
          const ReportColumn('الصناديق', numeric: true, flex: 0.8),
          const ReportColumn('الوزن ($kReportWeightUnit)', numeric: true),
          ReportColumn('متوسط سعر الكيلو ($m)', numeric: true, flex: 0.9),
          ReportColumn('القيمة ($m)', numeric: true, flex: 1.15),
          ReportColumn('المدفوع ($m)', numeric: true, flex: 1.15),
          ReportColumn('المتبقي ($m)', numeric: true, flex: 1.15),
        ],
        rows: [
          for (final f in farmers)
            ReportRow([
              ReportCell(f.label),
              ReportCell.count(f.totals.operations),
              ReportCell.count(f.totals.boxes),
              ReportCell.weight(f.totals.weightGrams),
              ReportCell.money(f.totals.avgPricePerKgPiasters),
              ReportCell.money(f.totals.valuePiasters),
              ReportCell.money(f.totals.paidPiasters),
              ReportCell.money(f.totals.remainingPiasters),
            ]),
        ],
        totals: [
          const ReportCell('الإجمالي'),
          ReportCell.count(totals.operations),
          ReportCell.count(totals.boxes),
          ReportCell.weight(totals.weightGrams),
          ReportCell.money(totals.avgPricePerKgPiasters),
          ReportCell.money(totals.valuePiasters),
          ReportCell.money(totals.paidPiasters),
          ReportCell.money(totals.remainingPiasters),
        ],
        emptyText: 'لا توجد عمليات شراء فعّالة.',
      ),
    );
  }

  ReportSection _packagingSection() {
    final m = currency;
    final t = packagingTotals;
    return ReportSection(
      title: 'مشتريات التعبئة',
      entries: [
        ReportEntry('التكلفة المعتمدة', ReportCell.money(t.approvedPiasters), unit: m, highlight: true),
        if (t.latePiasters > 0) ReportEntry('منها تكلفة متأخرة', ReportCell.money(t.latePiasters), unit: m),
        ReportEntry('المدفوع للموردين', ReportCell.money(t.paidPiasters), unit: m),
        ReportEntry('المتبقي للموردين', ReportCell.money(t.remainingPiasters), unit: m),
      ],
      table: ReportTable(
        columns: [
          const ReportColumn('رقم الشراء', flex: 0.8),
          const ReportColumn('التاريخ', flex: 0.9),
          const ReportColumn('المورد', flex: 1.4),
          const ReportColumn('رقم الفاتورة', flex: 0.9),
          const ReportColumn('الحالة', flex: 1.1),
          ReportColumn('الإجمالي ($m)', numeric: true, flex: 1.1),
          ReportColumn('المدفوع ($m)', numeric: true, flex: 1.1),
          ReportColumn('المتبقي ($m)', numeric: true, flex: 1.1),
          const ReportColumn('تكلفة متأخرة', align: ReportAlign.center, flex: 0.8),
        ],
        rows: [
          for (final p in packaging)
            ReportRow([
              ReportCell(p.no),
              ReportCell.date(p.occurredAt),
              ReportCell(supplierName(p.supplier)),
              ReportCell(p.invoiceNo ?? ''),
              ReportCell(packagingStatusText(p)),
              ReportCell.money(p.completeTotalPiasters),
              p.status == PackagingStatus.approved ? ReportCell.money(p.paidPiasters) : ReportCell.empty,
              p.status == PackagingStatus.approved ? ReportCell.money(p.remainingPiasters) : ReportCell.empty,
              ReportCell(p.status == PackagingStatus.approved && p.late ? 'نعم' : ''),
            ], muted: p.status != PackagingStatus.approved),
        ],
        totals: [
          const ReportCell('الإجمالي المعتمد'),
          ReportCell.empty,
          ReportCell.empty,
          ReportCell.empty,
          ReportCell.empty,
          ReportCell.money(t.approvedPiasters),
          ReportCell.money(t.paidPiasters),
          ReportCell.money(t.remainingPiasters),
          t.latePiasters > 0 ? ReportCell.money(t.latePiasters) : ReportCell.empty,
        ],
        emptyText: 'لا توجد مشتريات تعبئة مرتبطة بهذا البراد.',
      ),
      notes: [
        if (t.latePiasters > 0)
          'التكلفة المتأخرة: مشتريات تعبئة اعتُمدت بعد تقفيل البراد، وهي داخلة في التكلفة المعتمدة وإجمالي التكلفة.',
        if (t.draftCount > 0) 'المسودات (${t.draftCount}) معروضة للعلم ولا تدخل في التكلفة حتى تُعتمد.',
        if (t.cancelledCount > 0) 'المشتريات الملغاة (${t.cancelledCount}) لا تدخل في أي مجموع.',
      ],
    );
  }

  ReportSection _itemsSection() {
    final m = currency;
    var total = 0;
    final rows = <ReportRow>[];
    for (final p in packaging) {
      final items = approvedItems[p.id];
      if (items == null) continue;
      for (final i in items) {
        total += i.totalPiasters ?? 0;
        rows.add(ReportRow([
          ReportCell(p.no),
          ReportCell(i.name),
          i.quantity == null ? ReportCell.empty : ReportCell.count(i.quantity!),
          ReportCell(i.unit),
          i.unitPricePiasters == null ? ReportCell.empty : ReportCell.money(i.unitPricePiasters!),
          i.totalPiasters == null ? ReportCell.empty : ReportCell.money(i.totalPiasters!),
        ]));
      }
    }
    return ReportSection(
      title: 'أصناف التعبئة المعتمدة',
      table: ReportTable(
        columns: [
          const ReportColumn('رقم الشراء', flex: 0.8),
          const ReportColumn('الصنف', flex: 2),
          const ReportColumn('الكمية', numeric: true, flex: 0.8),
          const ReportColumn('الوحدة', flex: 0.8),
          ReportColumn('سعر الوحدة ($m)', numeric: true),
          ReportColumn('الإجمالي ($m)', numeric: true, flex: 1.2),
        ],
        rows: rows,
        totals: [
          const ReportCell('الإجمالي'),
          ReportCell.empty,
          ReportCell.empty,
          ReportCell.empty,
          ReportCell.empty,
          ReportCell.money(total),
        ],
      ),
    );
  }

  ReportSection _paymentsSection() {
    final m = currency;
    final t = paymentTotals;
    return ReportSection(
      title: 'الدفعات',
      entries: [
        ReportEntry('للمزارعين', ReportCell.money(t.amount(payee: PayeeType.farmer)), unit: m),
        ReportEntry('للموردين', ReportCell.money(t.amount(payee: PayeeType.supplier)), unit: m),
      ],
      table: ReportTable(
        columns: [
          const ReportColumn('رقم الدفعة', flex: 0.8),
          const ReportColumn('الوقت', flex: 1.5),
          const ReportColumn('المستفيد', flex: 1.6),
          const ReportColumn('النوع', flex: 0.7),
          const ReportColumn('مقابل', flex: 0.9),
          const ReportColumn('الطريقة', flex: 0.9),
          ReportColumn('المبلغ ($m)', numeric: true, flex: 1.15),
          const ReportColumn('الحالة', flex: 0.7),
        ],
        rows: [
          for (final p in payments)
            ReportRow([
              ReportCell(p.no),
              ReportCell.time(p.paidAt),
              ReportCell(p.payeeName),
              ReportCell(p.payeeType.label),
              ReportCell(p.targetType.label),
              ReportCell(p.method.label),
              ReportCell.money(p.amountPiasters),
              ReportCell(paymentStatusText(p)),
            ], muted: !p.active),
        ],
        totals: [
          const ReportCell('الإجمالي'),
          ReportCell.empty,
          ReportCell.empty,
          ReportCell.empty,
          ReportCell.empty,
          ReportCell.empty,
          ReportCell.money(t.totalPiasters),
          ReportCell.empty,
        ],
        emptyText: 'لا توجد دفعات مسجّلة لهذا البراد.',
      ),
      notes: [
        if (t.cancelledCount > 0) 'الدفعات الملغاة (${t.cancelledCount}) معروضة للعلم ولا تدخل في المجموع.',
      ],
    );
  }

  ReportSection _closeSection(List<CloseComparisonLine> lines) {
    final m = currency;
    String diffMoney(int v) => '${ReportCell.money(v.abs()).text} $m';
    final byLabel = {for (final l in lines) l.label: l};
    final paid = byLabel['المدفوع للمزارعين']!;
    final pack = byLabel['تكلفة التعبئة المعتمدة']!;
    final purchasesChanged = lines.take(5).any((l) => l.difference != 0);
    return ReportSection(
      title: 'أرقام التقفيل مقارنة بالأرقام الحالية',
      entries: [
        ReportEntry('وقت التقفيل', ReportCell.time(cooler.closedAt)),
        if (cooler.closedBy != null) ReportEntry.text('قفّله', cooler.closedBy!),
      ],
      table: ReportTable(
        columns: const [
          ReportColumn('البند', flex: 1.6),
          ReportColumn('عند التقفيل', numeric: true),
          ReportColumn('الآن', numeric: true),
          ReportColumn('الفرق', numeric: true),
        ],
        rows: [
          for (final l in lines)
            ReportRow([
              ReportCell(l.label),
              _valueCell(l.atClose, l.kind),
              _valueCell(l.now, l.kind),
              _diffCell(l.difference, l.kind),
            ]),
        ],
      ),
      notes: [
        if (lines.every((l) => l.difference == 0)) 'لا فروق: الأرقام الحالية مطابقة لأرقام التقفيل.',
        if (paid.difference > 0)
          'دفعات سُجّلت بعد التقفيل بمبلغ ${diffMoney(paid.difference)}، فانخفض المتبقي للمزارعين بالمقدار نفسه.',
        if (paid.difference < 0)
          'أُلغيت دفعات بعد التقفيل بمبلغ ${diffMoney(paid.difference)}، فزاد المتبقي للمزارعين بالمقدار نفسه.',
        if (pack.difference != 0)
          'تكلفة تعبئة متأخرة اعتُمدت بعد التقفيل: ${diffMoney(pack.difference)}'
              '${pack.difference < 0 ? ' (بالنقص)' : ''}، فتغيّر إجمالي تكلفة البراد.',
        if (purchasesChanged) 'تغيّرت أرقام المشتريات بعد التقفيل؛ راجع سجل التعديلات.',
      ],
    );
  }
}
