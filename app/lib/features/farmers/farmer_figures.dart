import '../../core/models/records.dart';

/// أرقام المزارع في الموسم من عمليات الشراء الفعّالة: العدد، الوزن، القيمة، المدفوع، المتبقي.
class FarmerFigures {
  const FarmerFigures({
    this.operations = 0,
    this.weightGrams = 0,
    this.valuePiasters = 0,
    this.paidPiasters = 0,
    this.remainingPiasters = 0,
  });

  static const zero = FarmerFigures();

  final int operations;
  final int weightGrams;
  final int valuePiasters;
  final int paidPiasters;
  final int remainingPiasters;

  FarmerFigures operator +(Purchase p) => FarmerFigures(
        operations: operations + 1,
        weightGrams: weightGrams + p.totalWeightGrams,
        valuePiasters: valuePiasters + p.valuePiasters,
        paidPiasters: paidPiasters + p.paidPiasters,
        remainingPiasters: remainingPiasters + p.remainingPiasters,
      );
}

/// يجمع أرقام كل مزارع (بمعرّفه) مرة واحدة من قائمة المشتريات. الملغاة لا تدخل في الأرقام.
Map<String, FarmerFigures> farmerFiguresFrom(Iterable<Purchase> purchases) {
  final out = <String, FarmerFigures>{};
  for (final p in purchases) {
    if (!p.active) continue;
    out[p.farmerId] = (out[p.farmerId] ?? FarmerFigures.zero) + p;
  }
  return out;
}
