/// حسابات قسم المدفوعات: المستحقات حسب المستفيد، ملخص المدفوع والمتبقي، وفلاتر قائمة الدفعات.
library;

import '../../core/format/numbers.dart';
import '../../core/models/records.dart';
import '../farmers/text_search.dart';

/// عملية يمكن الدفع لها: شراء رمان من مزارع، أو شراء تعبئة معتمد من مورد.
class PayableOperation {
  const PayableOperation({
    required this.targetType,
    required this.targetId,
    required this.payeeType,
    required this.payeeKey,
    required this.payeeName,
    required this.title,
    required this.details,
    this.coolerId,
    this.coolerNo,
    this.occurredAt,
    required this.valuePiasters,
    required this.paidPiasters,
    required this.remainingPiasters,
  });

  factory PayableOperation.purchase(Purchase p) => PayableOperation(
        targetType: PaymentTarget.purchase,
        targetId: p.id,
        payeeType: PayeeType.farmer,
        payeeKey: p.farmerId,
        payeeName: p.farmerName,
        title: 'شراء رمان · براد ${p.coolerNo}',
        details: '${formatCount(p.boxes)} صندوق · ${formatWeight(p.totalWeightGrams)} كغ'
            ' · ${formatMoney(p.pricePerKgPiasters)} ج.م/كغ',
        coolerId: p.coolerId.isEmpty ? null : p.coolerId,
        coolerNo: p.coolerNo,
        occurredAt: p.occurredAt,
        valuePiasters: p.valuePiasters,
        paidPiasters: p.paidPiasters,
        remainingPiasters: p.remainingPiasters,
      );

  factory PayableOperation.packaging(PackagingSummary k) {
    final supplier = k.supplier?.trim() ?? '';
    return PayableOperation(
      targetType: PaymentTarget.packaging,
      targetId: k.id,
      payeeType: PayeeType.supplier,
      payeeKey: normalizeArabic(supplier),
      payeeName: supplier.isEmpty ? 'مورد غير محدد' : supplier,
      title: ['شراء تعبئة ${k.no}', if (k.coolerNo != null) 'براد ${k.coolerNo}'].join(' · '),
      details: [
        if (k.invoiceNo != null) 'فاتورة ${k.invoiceNo}',
        '${formatCount(k.itemsCount)} ${k.itemsCount == 1 ? 'عنصر' : 'عناصر'}',
        if (k.late) 'تكلفة متأخرة',
      ].join(' · '),
      coolerId: k.coolerId,
      coolerNo: k.coolerNo,
      occurredAt: k.occurredAt,
      valuePiasters: k.completeTotalPiasters,
      paidPiasters: k.paidPiasters,
      remainingPiasters: k.remainingPiasters,
    );
  }

  final PaymentTarget targetType;
  final String targetId;
  final PayeeType payeeType;

  /// معرّف المزارع، أو اسم المورد بعد التطبيع (للتجميع).
  final String payeeKey;
  final String payeeName;

  /// «شراء رمان · براد 14» أو «شراء تعبئة P-0004 · براد 14».
  final String title;

  /// «50 صندوق · 550 كغ · 15.00 ج.م/كغ» أو «فاتورة 77 · 3 عناصر».
  final String details;
  final String? coolerId;
  final int? coolerNo;
  final String? occurredAt;
  final int valuePiasters;
  final int paidPiasters;
  final int remainingPiasters;

  /// نسخة بمتبقٍ أحدث (من رد الخادم عند رفض المبلغ).
  PayableOperation withRemaining(int remaining) => PayableOperation(
        targetType: targetType,
        targetId: targetId,
        payeeType: payeeType,
        payeeKey: payeeKey,
        payeeName: payeeName,
        title: title,
        details: details,
        coolerId: coolerId,
        coolerNo: coolerNo,
        occurredAt: occurredAt,
        valuePiasters: valuePiasters,
        paidPiasters: valuePiasters - remaining,
        remainingPiasters: remaining,
      );
}

/// مستحقات مستفيد واحد (مزارع أو مورد): عملياته التي لها متبقٍ.
class PayeeDues {
  const PayeeDues({
    required this.payeeType,
    required this.payeeKey,
    required this.payeeName,
    required this.operations,
  });

  final PayeeType payeeType;
  final String payeeKey;
  final String payeeName;

  /// الأقدم أولًا.
  final List<PayableOperation> operations;

  int get remainingPiasters => operations.fold(0, (s, o) => s + o.remainingPiasters);
  int get valuePiasters => operations.fold(0, (s, o) => s + o.valuePiasters);
  int get paidPiasters => operations.fold(0, (s, o) => s + o.paidPiasters);
}

/// المستحقات من شراء الرمان الفعّال والتعبئة المعتمدة، مجمّعة حسب المستفيد (الأكبر متبقيًا أولًا).
List<PayeeDues> groupDues({required Iterable<Purchase> purchases, required Iterable<PackagingSummary> packaging}) {
  final ops = <PayableOperation>[
    for (final p in purchases)
      if (p.active && p.remainingPiasters > 0) PayableOperation.purchase(p),
    for (final k in packaging)
      if (k.status == PackagingStatus.approved && k.remainingPiasters > 0) PayableOperation.packaging(k),
  ];
  final groups = <String, List<PayableOperation>>{};
  for (final o in ops) {
    groups.putIfAbsent('${o.payeeType.wire}:${o.payeeKey}', () => []).add(o);
  }
  final out = [
    for (final list in groups.values)
      PayeeDues(
        payeeType: list.first.payeeType,
        payeeKey: list.first.payeeKey,
        payeeName: list.first.payeeName,
        operations: list..sort((a, b) => (a.occurredAt ?? '').compareTo(b.occurredAt ?? '')),
      ),
  ];
  out.sort((a, b) {
    final c = b.remainingPiasters.compareTo(a.remainingPiasters);
    return c != 0 ? c : normalizeArabic(a.payeeName).compareTo(normalizeArabic(b.payeeName));
  });
  return out;
}

/// مؤشرات أعلى صفحة المدفوعات.
class PaymentsSummary {
  const PaymentsSummary({
    required this.paidPiasters,
    required this.activeCount,
    required this.remainingFarmersPiasters,
    required this.remainingSuppliersPiasters,
  });

  factory PaymentsSummary.from({
    required Iterable<Payment> payments,
    required Iterable<Purchase> purchases,
    required Iterable<PackagingSummary> packaging,
  }) {
    var paid = 0;
    var count = 0;
    for (final p in payments) {
      if (!p.active) continue;
      paid += p.amountPiasters;
      count++;
    }
    var farmers = 0;
    for (final p in purchases) {
      if (p.active && p.remainingPiasters > 0) farmers += p.remainingPiasters;
    }
    var suppliers = 0;
    for (final k in packaging) {
      if (k.status == PackagingStatus.approved && k.remainingPiasters > 0) suppliers += k.remainingPiasters;
    }
    return PaymentsSummary(
      paidPiasters: paid,
      activeCount: count,
      remainingFarmersPiasters: farmers,
      remainingSuppliersPiasters: suppliers,
    );
  }

  /// مجموع الدفعات الفعّالة فقط.
  final int paidPiasters;
  final int activeCount;
  final int remainingFarmersPiasters;
  final int remainingSuppliersPiasters;
}

/// فلتر حالة الدفعة.
enum PaymentStatusFilter {
  all('الكل'),
  active('فعّالة'),
  cancelled('ملغاة');

  const PaymentStatusFilter(this.label);
  final String label;
}

/// قيمة فلتر البراد للدفعات غير المرتبطة ببراد.
const noCoolerFilter = 'none';

/// هل تطابق الدفعة الفلاتر؟ [cooler]: '' = الكل، [noCoolerFilter] = دون براد، أو معرّف البراد.
bool paymentMatches(
  Payment p, {
  PayeeType? payee,
  String cooler = '',
  PaymentStatusFilter status = PaymentStatusFilter.all,
  String query = '',
}) {
  if (payee != null && p.payeeType != payee) return false;
  if (cooler == noCoolerFilter && p.coolerId != null) return false;
  if (cooler.isNotEmpty && cooler != noCoolerFilter && p.coolerId != cooler) return false;
  if (status == PaymentStatusFilter.active && !p.active) return false;
  if (status == PaymentStatusFilter.cancelled && p.active) return false;
  return matchesAllWords([
    p.payeeName,
    p.no,
    p.targetId,
    p.createdBy,
    p.notes,
    p.cancelReason,
    p.method.label,
    if (p.coolerNo != null) 'براد ${p.coolerNo}',
    '${p.amountPiasters ~/ 100}',
  ], query);
}

/// «شراء رمان · براد 14»
String paymentOperationLabel(Payment p) =>
    [p.targetType.label, if (p.coolerNo != null) 'براد ${p.coolerNo}'].join(' · ');

/// مبلغ بالقرش كنص قابل للتعديل دون فواصل: 1752540 ← «17525.40»، 150000 ← «1500».
String editableMoney(int piasters) {
  final whole = piasters ~/ 100;
  final frac = piasters % 100;
  return frac == 0 ? '$whole' : '$whole.${frac.toString().padLeft(2, '0')}';
}

/// ينتظر [f] ويعيد (القيمة، null) أو (null، الخطأ) دون رمي، لتحميل عدة قوائم معًا وعرض خطأ كل منها.
Future<(T?, Object?)> settle<T>(Future<T> f) async {
  try {
    return (await f, null);
  } catch (e) {
    return (null, e);
  }
}
