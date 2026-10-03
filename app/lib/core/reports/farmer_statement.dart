/// كشف حساب مزارع: كل عمليات الشراء في كل البرادات، وكل الدفعات، والمجاميع (القيمة، المدفوع، المتبقي)،
/// مع فترة اختيارية.
library;

import '../format/numbers.dart';
import '../models/records.dart';
import 'report_document.dart';
import 'report_format.dart';
import 'report_totals.dart';

class FarmerStatement {
  FarmerStatement._({
    required this.farmer,
    required this.from,
    required this.to,
    required this.purchases,
    required this.payments,
    required this.totals,
    required this.paymentTotals,
    required this.generatedAt,
    required this.currency,
  });

  /// [purchases]: purchases.list(farmerId) بما فيها الملغاة؛ [payments]: payments.list(payeeId: farmerId).
  /// [from]/[to] (شاملان، بتاريخ العمل): العمليات بوقت العملية، والدفعات بوقت الدفع.
  factory FarmerStatement.build({
    required Farmer farmer,
    required List<Purchase> purchases,
    required List<Payment> payments,
    DateTime? from,
    DateTime? to,
    DateTime? generatedAt,
    String currency = kReportCurrency,
  }) {
    final ps = [
      for (final p in purchases)
        if (p.farmerId == farmer.id && inDateRange(p.occurredAt, from: from, to: to)) p,
    ]..sort((a, b) => compareByTime(a.occurredAt, a.id, b.occurredAt, b.id));
    final pays = [
      for (final p in payments)
        if (p.payeeType == PayeeType.farmer && p.payeeId == farmer.id && inDateRange(p.paidAt, from: from, to: to)) p,
    ]..sort((a, b) => compareByTime(a.paidAt, a.id, b.paidAt, b.id));
    return FarmerStatement._(
      farmer: farmer,
      from: from,
      to: to,
      purchases: ps,
      payments: pays,
      totals: PurchaseTotals.of(ps),
      paymentTotals: PaymentTotals.of(pays),
      generatedAt: generatedAt ?? DateTime.now(),
      currency: currency,
    );
  }

  final Farmer farmer;
  final DateTime? from;
  final DateTime? to;

  /// عمليات المزارع في الفترة بترتيب زمني تصاعدي؛ الملغاة معروضة ولا تُحتسب.
  final List<Purchase> purchases;

  /// دفعات المزارع في الفترة؛ الملغاة معروضة ولا تُحتسب.
  final List<Payment> payments;
  final PurchaseTotals totals;
  final PaymentTotals paymentTotals;
  final DateTime generatedAt;
  final String currency;

  bool get hasRange => from != null || to != null;

  /// إجمالي قيمة العمليات الفعّالة.
  int get valuePiasters => totals.valuePiasters;

  /// المدفوع على هذه العمليات (كل دفعاتها الفعّالة حتى الآن).
  int get paidPiasters => totals.paidPiasters;

  /// المتبقي للمزارع = القيمة − المدفوع.
  int get remainingPiasters => totals.remainingPiasters;

  ReportDocument toDocument() {
    final m = currency;
    final f = farmer;
    return ReportDocument(
      title: 'كشف حساب المزارع',
      subtitle: [f.name, if (hasRange) dateRangeText(from, to)].join(' · '),
      generatedAt: generatedAt,
      fileStem: 'كشف-حساب-${fileSafeName(f.name, fallback: 'مزارع')}',
      asciiFileStem: 'farmer-statement-${f.no > 0 ? f.no : fileSafeName(f.id, fallback: 'farmer')}',
      meta: [
        ReportEntry.text('المزارع', f.name),
        if (f.no > 0) ReportEntry('رقم المزارع', ReportCell.count(f.no)),
        if (f.phone != null) ReportEntry.text('الهاتف', f.phone!),
        if (f.village != null) ReportEntry.text('القرية', f.village!),
        if (!f.active) ReportEntry.text('الحالة', 'موقوف'),
        ReportEntry.text('الفترة', dateRangeText(from, to)),
      ],
      summary: [
        ReportEntry('عمليات الشراء', ReportCell.count(totals.operations)),
        ReportEntry('الصناديق', ReportCell.count(totals.boxes)),
        ReportEntry('إجمالي الوزن', ReportCell.weight(totals.weightGrams), unit: kReportWeightUnit),
        ReportEntry('متوسط سعر الكيلو', ReportCell.money(totals.avgPricePerKgPiasters), unit: '$m/$kReportWeightUnit'),
        ReportEntry('إجمالي القيمة', ReportCell.money(valuePiasters), unit: m),
        ReportEntry('المدفوع', ReportCell.money(paidPiasters), unit: m),
        ReportEntry('المتبقي للمزارع', ReportCell.money(remainingPiasters), unit: m, highlight: true),
      ],
      sections: [
        ReportSection(
          title: 'عمليات الشراء',
          table: ReportTable(
            columns: [
              const ReportColumn('التاريخ', flex: 1.5),
              const ReportColumn('البراد', flex: 0.6, align: ReportAlign.center),
              const ReportColumn('الصناديق', numeric: true, flex: 0.8),
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
                  p.coolerNo > 0 ? ReportCell.count(p.coolerNo) : ReportCell.empty,
                  ReportCell.count(p.boxes),
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
              ReportCell.weight(totals.weightGrams),
              ReportCell.money(totals.avgPricePerKgPiasters),
              ReportCell.money(valuePiasters),
              ReportCell.money(paidPiasters),
              ReportCell.money(remainingPiasters),
              ReportCell.empty,
            ],
            emptyText: 'لا توجد عمليات شراء لهذا المزارع${hasRange ? ' في هذه الفترة' : ''}.',
          ),
          notes: [
            if (totals.cancelled > 0) 'العمليات الملغاة (${totals.cancelled}) معروضة للعلم ولا تدخل في المجاميع.',
            if (hasRange) 'المدفوع والمتبقي لكل عملية يشملان كل دفعاتها حتى تاريخ التقرير.',
          ],
        ),
        ReportSection(
          title: 'الدفعات',
          table: ReportTable(
            columns: [
              const ReportColumn('رقم الدفعة', flex: 0.8),
              const ReportColumn('الوقت', flex: 1.5),
              const ReportColumn('البراد', flex: 0.6, align: ReportAlign.center),
              const ReportColumn('الطريقة', flex: 0.9),
              ReportColumn('المبلغ ($m)', numeric: true, flex: 1.15),
              const ReportColumn('الحالة', flex: 0.7),
              const ReportColumn('ملاحظات', flex: 1.4),
            ],
            rows: [
              for (final p in payments)
                ReportRow([
                  ReportCell(p.no),
                  ReportCell.time(p.paidAt),
                  p.coolerNo != null && p.coolerNo! > 0 ? ReportCell.count(p.coolerNo!) : ReportCell.empty,
                  ReportCell(p.method.label),
                  ReportCell.money(p.amountPiasters),
                  ReportCell(paymentStatusText(p)),
                  ReportCell(p.active ? (p.notes ?? '') : (p.cancelReason ?? p.notes ?? '')),
                ], muted: !p.active),
            ],
            totals: [
              const ReportCell('الإجمالي'),
              ReportCell.empty,
              ReportCell.empty,
              ReportCell.empty,
              ReportCell.money(paymentTotals.totalPiasters),
              ReportCell.empty,
              ReportCell.empty,
            ],
            emptyText: 'لا توجد دفعات${hasRange ? ' في هذه الفترة' : ''}.',
          ),
          notes: [
            if (paymentTotals.cancelledCount > 0)
              'الدفعات الملغاة (${paymentTotals.cancelledCount}) معروضة للعلم ولا تدخل في المجموع.',
            if (hasRange && paymentTotals.totalPiasters != paidPiasters)
              'مجموع الدفعات في الفترة (${formatMoney(paymentTotals.totalPiasters)} $m) يختلف عن المدفوع على '
                  'عمليات الفترة لأن بعض الدفعات تخص عمليات خارجها أو سُجّلت بعدها.',
          ],
        ),
      ],
    );
  }
}
