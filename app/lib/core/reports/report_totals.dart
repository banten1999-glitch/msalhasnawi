/// مجاميع مشتركة بين التقارير. القاعدة في كل مكان: العمليات الملغاة والمسودات لا تدخل في أي مجموع،
/// والحساب بأعداد صحيحة (قرش وجرام) فقط.
library;

import '../models/records.dart';
import 'report_format.dart';

/// العملة الافتراضية في التقارير (الإعدادات: currencySymbol).
const kReportCurrency = 'ج.م';

/// وحدة الوزن في التقارير.
const kReportWeightUnit = 'كغ';

/// تسمية العملية الملغاة في الجداول (تُعرض للعلم ولا تُحتسب).
const kCancelledLabel = 'ملغاة';

/// حالة عملية شراء الرمان في الجداول: حالة الدفع، أو «ملغاة».
String purchaseStatusText(Purchase p) => p.active ? p.payStatus.label : kCancelledLabel;

/// حالة الدفعة في الجداول.
String paymentStatusText(Payment p) => p.active ? 'فعّالة' : kCancelledLabel;

/// حالة شراء التعبئة في الجداول؛ المسودة لا تُحتسب.
String packagingStatusText(PackagingSummary p) => switch (p.status) {
      PackagingStatus.approved => PackagingStatus.approved.label,
      PackagingStatus.draft => 'مسودة (لا تُحتسب)',
      PackagingStatus.cancelled => PackagingStatus.cancelled.label,
    };

/// اسم المورد للعرض والتجميع.
String supplierName(String? supplier) {
  final s = supplier?.trim() ?? '';
  return s.isEmpty ? 'بدون اسم مورد' : s;
}

/// مجاميع عمليات شراء الرمان الفعّالة.
class PurchaseTotals {
  const PurchaseTotals({
    this.farmers = 0,
    this.operations = 0,
    this.boxes = 0,
    this.weightGrams = 0,
    this.valuePiasters = 0,
    this.paidPiasters = 0,
    this.cancelled = 0,
  });

  /// يتجاهل العمليات الملغاة (ويعدّها في [cancelled] فقط).
  factory PurchaseTotals.of(Iterable<Purchase> purchases) {
    final farmers = <String>{};
    var operations = 0, boxes = 0, weight = 0, value = 0, paid = 0, cancelled = 0;
    for (final p in purchases) {
      if (!p.active) {
        cancelled++;
        continue;
      }
      farmers.add(farmerKey(p));
      operations++;
      boxes += p.boxes;
      weight += p.totalWeightGrams;
      value += p.valuePiasters;
      paid += p.paidPiasters;
    }
    return PurchaseTotals(
      farmers: farmers.length,
      operations: operations,
      boxes: boxes,
      weightGrams: weight,
      valuePiasters: value,
      paidPiasters: paid,
      cancelled: cancelled,
    );
  }

  /// عدد المزارعين المختلفين.
  final int farmers;

  /// عدد عمليات الشراء الفعّالة.
  final int operations;
  final int boxes;
  final int weightGrams;
  final int valuePiasters;

  /// المدفوع على هذه العمليات (من الدفعات الفعّالة).
  final int paidPiasters;

  /// عدد العمليات الملغاة المعروضة للعلم.
  final int cancelled;

  int get remainingPiasters => valuePiasters - paidPiasters;

  /// Σ القيمة ÷ Σ الوزن.
  int get avgPricePerKgPiasters => weightedAvgPricePerKg(valuePiasters, weightGrams);

  /// Σ الوزن ÷ Σ الصناديق (بالجرام).
  int get avgBoxGrams => boxes > 0 ? roundHalfUpDiv(weightGrams, boxes) : 0;

  /// مفتاح المزارع لعدّ المزارعين المختلفين (المعرّف، أو الاسم إن غاب المعرّف).
  static String farmerKey(Purchase p) => p.farmerId.isNotEmpty ? p.farmerId : 'name:${p.farmerName.trim()}';
}

/// سطر مجمّع لمزارع واحد (أو براد واحد) من عمليات الشراء.
class PurchaseGroup {
  const PurchaseGroup({required this.key, required this.label, required this.totals, this.sortKey = ''});

  final String key;
  final String label;
  final PurchaseTotals totals;

  /// أول وقت عملية في المجموعة (للترتيب).
  final String sortKey;

  /// يجمع العمليات الفعّالة حسب المزارع، مرتبة بالاسم.
  static List<PurchaseGroup> byFarmer(Iterable<Purchase> purchases) {
    final groups = <String, List<Purchase>>{};
    for (final p in purchases) {
      if (!p.active) continue;
      groups.putIfAbsent(PurchaseTotals.farmerKey(p), () => []).add(p);
    }
    final list = [
      for (final e in groups.entries)
        PurchaseGroup(key: e.key, label: e.value.first.farmerName, totals: PurchaseTotals.of(e.value)),
    ]..sort((a, b) {
        final c = a.label.compareTo(b.label);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return list;
  }
}

/// مجاميع مشتريات التعبئة: المعتمد فقط يُحتسب؛ المسودات والملغاة تُعدّ للعلم.
class PackagingTotals {
  const PackagingTotals({
    this.approvedCount = 0,
    this.approvedPiasters = 0,
    this.latePiasters = 0,
    this.lateCount = 0,
    this.paidPiasters = 0,
    this.draftCount = 0,
    this.draftPiasters = 0,
    this.cancelledCount = 0,
  });

  factory PackagingTotals.of(Iterable<PackagingSummary> packaging) {
    var approvedCount = 0, approved = 0, late = 0, lateCount = 0, paid = 0;
    var draftCount = 0, draft = 0, cancelledCount = 0;
    for (final p in packaging) {
      switch (p.status) {
        case PackagingStatus.approved:
          approvedCount++;
          approved += p.completeTotalPiasters;
          paid += p.paidPiasters;
          if (p.late) {
            lateCount++;
            late += p.completeTotalPiasters;
          }
        case PackagingStatus.draft:
          draftCount++;
          draft += p.completeTotalPiasters;
        case PackagingStatus.cancelled:
          cancelledCount++;
      }
    }
    return PackagingTotals(
      approvedCount: approvedCount,
      approvedPiasters: approved,
      latePiasters: late,
      lateCount: lateCount,
      paidPiasters: paid,
      draftCount: draftCount,
      draftPiasters: draft,
      cancelledCount: cancelledCount,
    );
  }

  final int approvedCount;

  /// تكلفة التعبئة المعتمدة.
  final int approvedPiasters;

  /// منها «تكلفة متأخرة» (اعتُمدت بعد تقفيل البراد المرتبط).
  final int latePiasters;
  final int lateCount;

  /// المدفوع للموردين على المشتريات المعتمدة.
  final int paidPiasters;

  /// المسودات: معروضة للعلم ولا تُحتسب ([draftPiasters] = مجموع أصنافها المكتملة حتى الآن).
  final int draftCount;
  final int draftPiasters;
  final int cancelledCount;

  int get remainingPiasters => approvedPiasters - paidPiasters;
}

/// مجاميع الدفعات الفعّالة، حسب نوع المستفيد وطريقة الدفع.
class PaymentTotals {
  const PaymentTotals._(this._amounts, this._counts, this.cancelledCount);

  factory PaymentTotals.of(Iterable<Payment> payments) {
    final amounts = <String, int>{};
    final counts = <String, int>{};
    var cancelled = 0;
    for (final p in payments) {
      if (!p.active) {
        cancelled++;
        continue;
      }
      final k = _key(p.method, p.payeeType);
      amounts[k] = (amounts[k] ?? 0) + p.amountPiasters;
      counts[k] = (counts[k] ?? 0) + 1;
    }
    return PaymentTotals._(amounts, counts, cancelled);
  }

  final Map<String, int> _amounts;
  final Map<String, int> _counts;

  /// عدد الدفعات الملغاة (لا تُحتسب).
  final int cancelledCount;

  static String _key(PaymentMethod m, PayeeType t) => '${m.wire}/${t.wire}';

  /// المبلغ لطريقة و/أو نوع مستفيد (null = الكل).
  int amount({PaymentMethod? method, PayeeType? payee}) {
    var sum = 0;
    for (final m in PaymentMethod.values) {
      if (method != null && m != method) continue;
      for (final t in PayeeType.values) {
        if (payee != null && t != payee) continue;
        sum += _amounts[_key(m, t)] ?? 0;
      }
    }
    return sum;
  }

  /// عدد الدفعات الفعّالة لطريقة و/أو نوع مستفيد (null = الكل).
  int count({PaymentMethod? method, PayeeType? payee}) {
    var sum = 0;
    for (final m in PaymentMethod.values) {
      if (method != null && m != method) continue;
      for (final t in PayeeType.values) {
        if (payee != null && t != payee) continue;
        sum += _counts[_key(m, t)] ?? 0;
      }
    }
    return sum;
  }

  int get totalPiasters => amount();
  int get activeCount => count();
}
