import 'package:rumman_calculator/core/models/dashboard.dart';
import 'package:rumman_calculator/core/models/records.dart';
import 'package:rumman_calculator/core/reports/report_format.dart';

/// بيانات اختبار التقارير: البراد 14 (مقفّل) بخمس عمليات فعّالة وعملية ملغاة، وتعبئة معتمدة ومتأخرة ومسودة
/// وملغاة، ودفعات بعضها بعد التقفيل وواحدة ملغاة. الأرقام محسوبة يدويًا في الاختبارات.

final generatedAt = DateTime(2026, 10, 3, 9, 15);

Purchase purchase(
  String id, {
  String coolerId = 'CL-0014',
  int coolerNo = 14,
  required String farmerId,
  required String farmerName,
  required String at,
  required int boxes,
  required int avgGrams,
  required int price,
  int paid = 0,
  bool active = true,
}) {
  final weight = boxes * avgGrams;
  final value = roundHalfUpDiv(weight * price, 1000);
  return Purchase(
    id: id,
    coolerId: coolerId,
    coolerNo: coolerNo,
    farmerId: farmerId,
    farmerName: farmerName,
    occurredAt: at,
    boxes: boxes,
    avgWeightGrams: avgGrams,
    weightMethod: WeightMethod.direct,
    totalWeightGrams: weight,
    pricePerKgPiasters: price,
    valuePiasters: value,
    paidPiasters: paid,
    remainingPiasters: value - paid,
    payStatus: paid == 0 ? PayStatus.unpaid : (paid >= value ? PayStatus.paid : PayStatus.partial),
    active: active,
    cancelReason: active ? null : 'خطأ في الإدخال',
  );
}

Payment payment(
  String id, {
  PayeeType payeeType = PayeeType.farmer,
  required String payeeName,
  String? payeeId,
  required String targetId,
  String? coolerId = 'CL-0014',
  int? coolerNo = 14,
  required int amount,
  PaymentMethod method = PaymentMethod.cash,
  required String at,
  bool active = true,
}) =>
    Payment(
      id: id,
      no: 'D-${id.substring(3)}',
      payeeType: payeeType,
      payeeName: payeeName,
      payeeId: payeeId,
      targetType: payeeType == PayeeType.farmer ? PaymentTarget.purchase : PaymentTarget.packaging,
      targetId: targetId,
      coolerId: coolerId,
      coolerNo: coolerNo,
      amountPiasters: amount,
      method: method,
      paidAt: at,
      active: active,
      cancelReason: active ? null : 'دفعة مكررة',
    );

PackagingSummary packaging(
  String id, {
  required String no,
  String? supplier,
  String? invoiceNo,
  String at = '2026-10-02T08:00:00+03:00',
  String? coolerId = 'CL-0014',
  int? coolerNo = 14,
  required PackagingStatus status,
  int total = 0,
  int paid = 0,
  bool late = false,
  int itemsCount = 1,
  int incompleteCount = 0,
}) =>
    PackagingSummary(
      id: id,
      no: no,
      supplier: supplier,
      invoiceNo: invoiceNo,
      occurredAt: at,
      coolerId: coolerId,
      coolerNo: coolerNo,
      status: status,
      itemsCount: itemsCount,
      incompleteCount: incompleteCount,
      completeTotalPiasters: total,
      paidPiasters: paid,
      remainingPiasters: status == PackagingStatus.approved ? total - paid : 0,
      late: late,
    );

PackagingItem item(String name, int quantity, String unit, int unitPrice) => PackagingItem(
      id: 'IT-$name',
      name: name,
      quantity: quantity,
      unit: unit,
      unitPricePiasters: unitPrice,
      totalPiasters: quantity * unitPrice,
      status: PackagingItemStatus.complete,
    );

// ---------------------------------------------------------------- البراد 14

/// قيم البراد 14 الحية المتوقعة (من العمليات الفعّالة فقط).
const coolerFarmers = 4;
const coolerOperations = 5;
const coolerBoxes = 198; // 40 + 55 + 30 + 48 + 25
const coolerWeight = 2242825; // 460000 + 599500 + 360000 + 540000 + 283325
const coolerValue = 3345179; // 690000 + 869275 + 558000 + 810000 + 417904
const coolerPaid = 2000000; // 690000 + 400000 + 0 + 810000 + 100000
const coolerApprovedPackaging = 450000; // 300000 + 150000 (متأخرة)
const coolerLatePackaging = 150000;

List<Purchase> cooler14Purchases() => [
      // ترتيب الخادم: الأحدث أولًا.
      purchase('PU-0006',
          farmerId: 'FR-0004', farmerName: 'سعيد عبد الله', at: '2026-10-02T10:20:00+03:00',
          boxes: 25, avgGrams: 11333, price: 1475, paid: 100000),
      purchase('PU-0005',
          farmerId: 'FR-0005', farmerName: 'خالد منصور', at: '2026-10-02T10:00:00+03:00',
          boxes: 20, avgGrams: 11000, price: 1500, active: false),
      purchase('PU-0004',
          farmerId: 'FR-0003', farmerName: 'عبد الرحمن فوزي', at: '2026-10-02T09:30:00+03:00',
          boxes: 48, avgGrams: 11250, price: 1500, paid: 810000),
      purchase('PU-0003',
          farmerId: 'FR-0001', farmerName: 'حسن البدري', at: '2026-10-02T08:05:00+03:00',
          boxes: 30, avgGrams: 12000, price: 1550),
      purchase('PU-0002',
          farmerId: 'FR-0002', farmerName: 'محمود سالم', at: '2026-10-02T07:15:00+03:00',
          boxes: 55, avgGrams: 10900, price: 1450, paid: 400000),
      purchase('PU-0001',
          farmerId: 'FR-0001', farmerName: 'حسن البدري', at: '2026-10-02T06:40:00+03:00',
          boxes: 40, avgGrams: 11500, price: 1500, paid: 690000),
    ];

List<PackagingSummary> cooler14Packaging() => [
      packaging('PK-0001',
          no: 'P-0001', supplier: 'مصنع الكرتون', invoiceNo: 'F-120', status: PackagingStatus.approved,
          total: 300000, paid: 300000, itemsCount: 2),
      packaging('PK-0002',
          no: 'P-0002', supplier: 'مصنع الكرتون', invoiceNo: 'F-133', at: '2026-10-03T08:00:00+03:00',
          status: PackagingStatus.approved, total: 150000, late: true),
      packaging('PK-0003',
          no: 'P-0003', supplier: 'الشبك الحديث', status: PackagingStatus.draft, total: 80000, itemsCount: 2,
          incompleteCount: 1),
      packaging('PK-0004', no: 'P-0004', supplier: 'الشبك الحديث', status: PackagingStatus.cancelled, total: 50000),
    ];

List<PackagingDetail> cooler14PackagingDetails() => [
      PackagingDetail(
        packaging: cooler14Packaging()[0],
        items: [item('كرتونة 10 كغ', 500, 'كرتونة', 500), item('شريط لاصق', 20, 'لفة', 2500)],
      ),
      PackagingDetail(packaging: cooler14Packaging()[1], items: [item('كرتونة 10 كغ', 300, 'كرتونة', 500)]),
    ];

List<Payment> cooler14Payments() => [
      payment('PY-0001',
          payeeName: 'حسن البدري', payeeId: 'FR-0001', targetId: 'PU-0001', amount: 690000,
          at: '2026-10-02T06:45:00+03:00'),
      payment('PY-0002',
          payeeName: 'محمود سالم', payeeId: 'FR-0002', targetId: 'PU-0002', amount: 400000,
          method: PaymentMethod.bank, at: '2026-10-02T07:20:00+03:00'),
      payment('PY-0003',
          payeeName: 'عبد الرحمن فوزي', payeeId: 'FR-0003', targetId: 'PU-0004', amount: 810000,
          at: '2026-10-02T09:35:00+03:00'),
      // بعد التقفيل.
      payment('PY-0004',
          payeeName: 'سعيد عبد الله', payeeId: 'FR-0004', targetId: 'PU-0006', amount: 100000,
          method: PaymentMethod.wallet, at: '2026-10-03T10:00:00+03:00'),
      payment('PY-0005',
          payeeType: PayeeType.supplier, payeeName: 'مصنع الكرتون', targetId: 'PK-0001', amount: 300000,
          method: PaymentMethod.bank, at: '2026-10-02T12:00:00+03:00'),
      payment('PY-0006',
          payeeName: 'محمود سالم', payeeId: 'FR-0002', targetId: 'PU-0002', amount: 50000,
          at: '2026-10-02T07:30:00+03:00', active: false),
    ];

CoolerSummary cooler14({bool open = false, bool snapshot = true}) => CoolerSummary(
      id: 'CL-0014',
      no: 14,
      name: 'شحنة دمياط',
      isOpen: open,
      carNo: 'ن ق ر 7316',
      driver: 'سامي عطية',
      openedAt: '2026-10-02T06:30:00+03:00',
      openedBy: 'محمد الحسناوي',
      closedAt: open ? null : '2026-10-02T17:30:00+03:00',
      closedBy: open ? null : 'كريم عبد الله',
      farmers: coolerFarmers,
      purchases: coolerOperations,
      boxes: coolerBoxes,
      weightGrams: coolerWeight,
      valuePiasters: coolerValue,
      paidPiasters: coolerPaid,
      remainingPiasters: coolerValue - coolerPaid,
      packagingApprovedPiasters: coolerApprovedPackaging,
      packagingLatePiasters: coolerLatePackaging,
      totalCostPiasters: coolerValue + coolerApprovedPackaging,
      avgPricePerKgPiasters: 1492,
      // عند التقفيل: قبل دفعة PY-0004 وقبل اعتماد التعبئة المتأخرة PK-0002.
      closeSnapshot: snapshot
          ? const CloseSnapshot(
              farmers: coolerFarmers,
              purchases: coolerOperations,
              boxes: coolerBoxes,
              weightGrams: coolerWeight,
              valuePiasters: coolerValue,
              paidPiasters: coolerPaid - 100000,
              remainingPiasters: coolerValue - coolerPaid + 100000,
              packagingPiasters: 300000,
              totalCostPiasters: coolerValue + 300000,
            )
          : null,
    );

CoolerDetail cooler14Detail({bool open = false}) =>
    CoolerDetail(cooler: cooler14(open: open), purchases: cooler14Purchases(), packaging: cooler14Packaging());

// ---------------------------------------------------------------- كشف المزارع حسن البدري (FR-0001)

const farmer1 = Farmer(id: 'FR-0001', no: 1, name: 'حسن البدري', phone: '01001234567', village: 'كفر سعد');

List<Purchase> farmer1Purchases() => [
      ...cooler14Purchases().where((p) => p.farmerId == 'FR-0001'),
      purchase('PU-0007',
          coolerId: 'CL-0013', coolerNo: 13, farmerId: 'FR-0001', farmerName: 'حسن البدري',
          at: '2026-10-01T15:40:00+03:00', boxes: 20, avgGrams: 11000, price: 1500, paid: 330000),
      purchase('PU-0008',
          coolerId: 'CL-0013', coolerNo: 13, farmerId: 'FR-0001', farmerName: 'حسن البدري',
          at: '2026-10-01T16:00:00+03:00', boxes: 10, avgGrams: 10000, price: 1000, active: false),
    ];

List<Payment> farmer1Payments() => [
      ...cooler14Payments().where((p) => p.payeeId == 'FR-0001'),
      payment('PY-0007',
          payeeName: 'حسن البدري', payeeId: 'FR-0001', targetId: 'PU-0007', coolerId: 'CL-0013', coolerNo: 13,
          amount: 330000, at: '2026-10-01T16:10:00+03:00'),
      payment('PY-0008',
          payeeName: 'حسن البدري', payeeId: 'FR-0001', targetId: 'PU-0007', coolerId: 'CL-0013', coolerNo: 13,
          amount: 20000, at: '2026-10-01T16:20:00+03:00', active: false),
    ];
