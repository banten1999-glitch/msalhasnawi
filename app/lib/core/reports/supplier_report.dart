/// تقرير الموردين: مشتريات التعبئة مجمّعة حسب المورد. المعتمدة فقط تدخل في المجاميع؛ المسودات والملغاة
/// تُعرض في أقسام مستقلة للعلم.
library;

import '../models/records.dart';
import 'report_document.dart';
import 'report_format.dart';
import 'report_totals.dart';

/// مشتريات مورد واحد.
class SupplierGroup {
  const SupplierGroup({required this.name, required this.purchases, required this.totals});

  /// الاسم كما يُعرض («بدون اسم مورد» إن كان فارغًا).
  final String name;

  /// كل مشتريات المورد بترتيب زمني (كل الحالات).
  final List<PackagingSummary> purchases;
  final PackagingTotals totals;

  Iterable<PackagingSummary> get approved => purchases.where((p) => p.status == PackagingStatus.approved);
}

class SupplierReport {
  SupplierReport._({
    required this.supplier,
    required this.from,
    required this.to,
    required this.groups,
    required this.totals,
    required this.items,
    required this.generatedAt,
    required this.currency,
  });

  /// [packaging]: packaging.list (كل الحالات). [details]: packaging.get للمشتريات المعتمدة (للأصناف).
  /// [supplier]: مورد واحد (مقارنة الاسم دون مسافات زائدة أو فرق حالة الأحرف)، أو null لكل الموردين.
  /// [from]/[to] (شاملان) بتاريخ الشراء.
  factory SupplierReport.build({
    required List<PackagingSummary> packaging,
    Iterable<PackagingDetail> details = const [],
    String? supplier,
    DateTime? from,
    DateTime? to,
    DateTime? generatedAt,
    String currency = kReportCurrency,
  }) {
    final wanted = supplier == null ? null : _norm(supplier);
    final list = [
      for (final p in packaging)
        if ((wanted == null || _norm(p.supplier ?? '') == wanted) && inDateRange(p.occurredAt, from: from, to: to)) p,
    ]..sort((a, b) => compareByTime(a.occurredAt, a.id, b.occurredAt, b.id));
    final byName = <String, List<PackagingSummary>>{};
    final display = <String, String>{};
    for (final p in list) {
      final key = _norm(p.supplier ?? '');
      byName.putIfAbsent(key, () => []).add(p);
      display.putIfAbsent(key, () => supplierName(p.supplier));
    }
    final groups = [
      for (final e in byName.entries)
        SupplierGroup(name: display[e.key]!, purchases: e.value, totals: PackagingTotals.of(e.value)),
    ]..sort((a, b) => a.name.compareTo(b.name));
    final approvedIds = {for (final p in list) if (p.status == PackagingStatus.approved) p.id};
    return SupplierReport._(
      supplier: supplier?.trim(),
      from: from,
      to: to,
      groups: groups,
      totals: PackagingTotals.of(list),
      items: {
        for (final d in details)
          if (approvedIds.contains(d.packaging.id))
            d.packaging.id: [for (final i in d.items) if (i.status != PackagingItemStatus.removed) i],
      },
      generatedAt: generatedAt ?? DateTime.now(),
      currency: currency,
    );
  }

  /// المورد المطلوب، أو null لكل الموردين.
  final String? supplier;
  final DateTime? from;
  final DateTime? to;

  /// الموردون مرتبين بالاسم.
  final List<SupplierGroup> groups;

  /// مجاميع كل الموردين (المعتمد فقط في التكلفة).
  final PackagingTotals totals;

  /// أصناف كل شراء معتمد: المعرّف ← الأصناف.
  final Map<String, List<PackagingItem>> items;
  final DateTime generatedAt;
  final String currency;

  static String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  bool get _single => supplier != null && supplier!.isNotEmpty;

  ReportDocument toDocument() {
    final m = currency;
    final t = totals;
    final drafts = [for (final g in groups) ...g.purchases.where((p) => p.status == PackagingStatus.draft)];
    final cancelled = [for (final g in groups) ...g.purchases.where((p) => p.status == PackagingStatus.cancelled)];
    return ReportDocument(
      title: _single ? 'تقرير المورد' : 'تقرير الموردين',
      subtitle: [if (_single) supplier!, if (from != null || to != null) dateRangeText(from, to)].join(' · '),
      generatedAt: generatedAt,
      fileStem: _single ? 'تقرير-المورد-${fileSafeName(supplier!, fallback: 'مورد')}' : 'تقرير-الموردين',
      asciiFileStem: _single ? 'supplier-report' : 'suppliers-report',
      meta: [
        if (_single) ReportEntry.text('المورد', supplier!),
        ReportEntry.text('الفترة', dateRangeText(from, to)),
      ],
      summary: [
        if (!_single) ReportEntry('عدد الموردين', ReportCell.count(groups.where((g) => g.totals.approvedCount > 0).length)),
        ReportEntry('مشتريات معتمدة', ReportCell.count(t.approvedCount)),
        ReportEntry('إجمالي المعتمد', ReportCell.money(t.approvedPiasters), unit: m),
        if (t.latePiasters > 0) ReportEntry('منها تكلفة متأخرة', ReportCell.money(t.latePiasters), unit: m),
        ReportEntry('المدفوع', ReportCell.money(t.paidPiasters), unit: m),
        ReportEntry('المتبقي للموردين', ReportCell.money(t.remainingPiasters), unit: m, highlight: true),
        if (t.draftCount > 0) ReportEntry('مسودات غير محتسبة', ReportCell.count(t.draftCount)),
      ],
      sections: [
        if (!_single) _bySupplierSection(),
        for (final g in groups)
          if (g.totals.approvedCount > 0) ...[_purchasesSection(g), if (_hasItems(g)) _itemsSection(g)],
        if (drafts.isNotEmpty) _draftsSection(drafts),
        if (cancelled.isNotEmpty) _cancelledSection(cancelled),
      ],
    );
  }

  bool _hasItems(SupplierGroup g) => g.approved.any((p) => (items[p.id] ?? const []).isNotEmpty);

  ReportSection _bySupplierSection() {
    final m = currency;
    return ReportSection(
      title: 'ملخص حسب المورد',
      table: ReportTable(
        columns: [
          const ReportColumn('المورد', flex: 2),
          const ReportColumn('المشتريات المعتمدة', numeric: true, flex: 0.9),
          ReportColumn('الإجمالي ($m)', numeric: true, flex: 1.2),
          ReportColumn('المدفوع ($m)', numeric: true, flex: 1.2),
          ReportColumn('المتبقي ($m)', numeric: true, flex: 1.2),
        ],
        rows: [
          for (final g in groups)
            if (g.totals.approvedCount > 0)
              ReportRow([
                ReportCell(g.name),
                ReportCell.count(g.totals.approvedCount),
                ReportCell.money(g.totals.approvedPiasters),
                ReportCell.money(g.totals.paidPiasters),
                ReportCell.money(g.totals.remainingPiasters),
              ]),
        ],
        totals: [
          const ReportCell('الإجمالي'),
          ReportCell.count(totals.approvedCount),
          ReportCell.money(totals.approvedPiasters),
          ReportCell.money(totals.paidPiasters),
          ReportCell.money(totals.remainingPiasters),
        ],
        emptyText: 'لا توجد مشتريات تعبئة معتمدة.',
      ),
    );
  }

  ReportSection _purchasesSection(SupplierGroup g) {
    final m = currency;
    final t = g.totals;
    return ReportSection(
      title: 'المورد: ${g.name}',
      table: ReportTable(
        columns: [
          const ReportColumn('رقم الشراء', flex: 0.8),
          const ReportColumn('التاريخ', flex: 0.9),
          const ReportColumn('رقم الفاتورة', flex: 0.9),
          const ReportColumn('البراد', align: ReportAlign.center, flex: 0.6),
          const ReportColumn('الأصناف', numeric: true, flex: 0.6),
          ReportColumn('الإجمالي ($m)', numeric: true, flex: 1.15),
          ReportColumn('المدفوع ($m)', numeric: true, flex: 1.15),
          ReportColumn('المتبقي ($m)', numeric: true, flex: 1.15),
          const ReportColumn('تكلفة متأخرة', align: ReportAlign.center, flex: 0.7),
        ],
        rows: [
          for (final p in g.approved)
            ReportRow([
              ReportCell(p.no),
              ReportCell.date(p.occurredAt),
              ReportCell(p.invoiceNo ?? ''),
              p.coolerNo != null && p.coolerNo! > 0 ? ReportCell.count(p.coolerNo!) : ReportCell.empty,
              ReportCell.count(p.itemsCount),
              ReportCell.money(p.completeTotalPiasters),
              ReportCell.money(p.paidPiasters),
              ReportCell.money(p.remainingPiasters),
              ReportCell(p.late ? 'نعم' : ''),
            ]),
        ],
        totals: [
          const ReportCell('الإجمالي'),
          ReportCell.empty,
          ReportCell.empty,
          ReportCell.empty,
          ReportCell.empty,
          ReportCell.money(t.approvedPiasters),
          ReportCell.money(t.paidPiasters),
          ReportCell.money(t.remainingPiasters),
          t.latePiasters > 0 ? ReportCell.money(t.latePiasters) : ReportCell.empty,
        ],
      ),
    );
  }

  ReportSection _itemsSection(SupplierGroup g) {
    final m = currency;
    var total = 0;
    final rows = <ReportRow>[];
    for (final p in g.approved) {
      for (final i in items[p.id] ?? const <PackagingItem>[]) {
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
      title: 'أصناف ${g.name}',
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

  ReportSection _draftsSection(List<PackagingSummary> drafts) {
    final m = currency;
    return ReportSection(
      title: 'مسودات (لا تدخل في المجاميع)',
      table: ReportTable(
        columns: [
          const ReportColumn('رقم الشراء', flex: 0.8),
          const ReportColumn('التاريخ', flex: 0.9),
          const ReportColumn('المورد', flex: 1.6),
          const ReportColumn('البراد', align: ReportAlign.center, flex: 0.6),
          const ReportColumn('الأصناف', numeric: true, flex: 0.6),
          const ReportColumn('غير المكتملة', numeric: true, flex: 0.7),
          ReportColumn('المكتمل حتى الآن ($m)', numeric: true, flex: 1.2),
        ],
        rows: [
          for (final p in drafts)
            ReportRow([
              ReportCell(p.no),
              ReportCell.date(p.occurredAt),
              ReportCell(supplierName(p.supplier)),
              p.coolerNo != null && p.coolerNo! > 0 ? ReportCell.count(p.coolerNo!) : ReportCell.empty,
              ReportCell.count(p.itemsCount),
              ReportCell.count(p.incompleteCount),
              ReportCell.money(p.completeTotalPiasters),
            ], muted: true),
        ],
      ),
      notes: const ['المسودة لا تدخل في التكلفة ولا في المتبقي للموردين حتى تُعتمد.'],
    );
  }

  ReportSection _cancelledSection(List<PackagingSummary> cancelled) {
    final m = currency;
    return ReportSection(
      title: 'مشتريات ملغاة (لا تدخل في المجاميع)',
      table: ReportTable(
        columns: [
          const ReportColumn('رقم الشراء', flex: 0.8),
          const ReportColumn('التاريخ', flex: 0.9),
          const ReportColumn('المورد', flex: 1.6),
          const ReportColumn('رقم الفاتورة', flex: 0.9),
          ReportColumn('الإجمالي ($m)', numeric: true, flex: 1.2),
        ],
        rows: [
          for (final p in cancelled)
            ReportRow([
              ReportCell(p.no),
              ReportCell.date(p.occurredAt),
              ReportCell(supplierName(p.supplier)),
              ReportCell(p.invoiceNo ?? ''),
              ReportCell.money(p.completeTotalPiasters),
            ], muted: true),
        ],
      ),
    );
  }
}
