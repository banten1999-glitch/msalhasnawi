// سجلات العمل كما يعيدها الخادم (docs/API.md §6). المبالغ بالقرش والأوزان بالجرام، والأوقات نص ISO بتوقيت العمل.
import 'dashboard.dart';

int _i(Object? v) => (v as num?)?.toInt() ?? 0;
int? _in(Object? v) => (v as num?)?.toInt();
String? _s(Object? v) => v is String && v.isNotEmpty ? v : null;
String _str(Object? v) => v is String ? v : (v?.toString() ?? '');
Map<String, dynamic> _m(Object? v) => (v as Map).cast<String, dynamic>();
List<Map<String, dynamic>> _list(Object? v) => [for (final e in (v as List?) ?? const []) _m(e)];

// ---------------------------------------------------------------- المزارعون

class Farmer {
  const Farmer({
    required this.id,
    required this.no,
    required this.name,
    this.phone,
    this.village,
    this.notes,
    this.active = true,
    this.version = 1,
  });

  factory Farmer.fromJson(Map<String, dynamic> j) => Farmer(
        id: _str(j['id']),
        no: _i(j['no']),
        name: _str(j['name']),
        phone: _s(j['phone']),
        village: _s(j['village']),
        notes: _s(j['notes']),
        active: j['status'] != 'inactive',
        version: _in(j['version']) ?? 1,
      );

  final String id;
  final int no;
  final String name;
  final String? phone;
  final String? village;
  final String? notes;

  /// false = «موقوف»: لا يظهر في اختيار المزارع لعمليات جديدة.
  final bool active;
  final int version;
}

// ---------------------------------------------------------------- مشتريات الرمان

enum WeightMethod {
  direct('direct', 'إدخال المتوسط مباشرة'),
  sample('sample', 'حساب من عينة');

  const WeightMethod(this.wire, this.label);
  final String wire;
  final String label;

  static WeightMethod fromWire(String? v) => v == 'sample' ? sample : direct;
}

enum PayStatus {
  paid('paid', 'مدفوع'),
  partial('partial', 'جزئي'),
  unpaid('unpaid', 'غير مدفوع');

  const PayStatus(this.wire, this.label);
  final String wire;
  final String label;

  static PayStatus fromWire(String? v) =>
      PayStatus.values.firstWhere((s) => s.wire == v, orElse: () => PayStatus.unpaid);
}

class Purchase {
  const Purchase({
    required this.id,
    required this.coolerId,
    required this.coolerNo,
    required this.farmerId,
    required this.farmerName,
    required this.occurredAt,
    required this.boxes,
    required this.avgWeightGrams,
    required this.weightMethod,
    this.sampleWeightsGrams = const [],
    this.tareGrams,
    required this.totalWeightGrams,
    required this.pricePerKgPiasters,
    required this.valuePiasters,
    required this.paidPiasters,
    required this.remainingPiasters,
    required this.payStatus,
    required this.active,
    this.cancelReason,
    this.notes,
    this.createdAt,
    this.createdBy,
    this.createdByEmail,
    this.updatedAt,
    this.updatedBy,
    this.version = 1,
  });

  factory Purchase.fromJson(Map<String, dynamic> j) => Purchase(
        id: _str(j['id']),
        coolerId: _str(j['coolerId']),
        coolerNo: _i(j['coolerNo']),
        farmerId: _str(j['farmerId']),
        farmerName: _str(j['farmerName']),
        occurredAt: _str(j['occurredAt']),
        boxes: _i(j['boxes']),
        avgWeightGrams: _i(j['avgWeightGrams']),
        weightMethod: WeightMethod.fromWire(j['weightMethod'] as String?),
        sampleWeightsGrams: [for (final g in (j['sampleWeightsGrams'] as List?) ?? const []) (g as num).toInt()],
        tareGrams: _in(j['tareGrams']),
        totalWeightGrams: _i(j['totalWeightGrams']),
        pricePerKgPiasters: _i(j['pricePerKgPiasters']),
        valuePiasters: _i(j['valuePiasters']),
        paidPiasters: _i(j['paidPiasters']),
        remainingPiasters: _i(j['remainingPiasters']),
        payStatus: PayStatus.fromWire(j['payStatus'] as String?),
        active: j['status'] != 'cancelled',
        cancelReason: _s(j['cancelReason']),
        notes: _s(j['notes']),
        createdAt: _s(j['createdAt']),
        createdBy: _s(j['createdBy']),
        createdByEmail: _s(j['createdByEmail']),
        updatedAt: _s(j['updatedAt']),
        updatedBy: _s(j['updatedBy']),
        version: _in(j['version']) ?? 1,
      );

  final String id;
  final String coolerId;
  final int coolerNo;
  final String farmerId;
  final String farmerName;

  /// وقت العملية كما اختاره المستخدم (قد يختلف عن [createdAt]، وقت الحفظ الفعلي).
  final String occurredAt;
  final int boxes;
  final int avgWeightGrams;
  final WeightMethod weightMethod;
  final List<int> sampleWeightsGrams;
  final int? tareGrams;
  final int totalWeightGrams;
  final int pricePerKgPiasters;
  final int valuePiasters;

  /// من الدفعات الفعّالة فقط.
  final int paidPiasters;
  final int remainingPiasters;
  final PayStatus payStatus;

  /// false = ملغاة (لا تُحذف السجلات أبدًا).
  final bool active;
  final String? cancelReason;
  final String? notes;
  final String? createdAt;
  final String? createdBy;
  final String? createdByEmail;
  final String? updatedAt;
  final String? updatedBy;
  final int version;
}

/// بيانات عملية شراء جديدة (purchases.create). قابلة للتخزين في قائمة «بانتظار المزامنة».
class PurchaseInput {
  const PurchaseInput({
    required this.coolerId,
    this.farmerId,
    this.newFarmerName,
    required this.boxes,
    required this.avgWeightGrams,
    this.weightMethod = WeightMethod.direct,
    this.sampleWeightsGrams = const [],
    this.tareGrams,
    required this.pricePerKgPiasters,
    this.occurredAt,
    this.notes,
    required this.payment,
  });

  factory PurchaseInput.fromJson(Map<String, dynamic> j) => PurchaseInput(
        coolerId: _str(j['coolerId']),
        farmerId: _s(j['farmerId']),
        newFarmerName: _s(j['newFarmerName']),
        boxes: _i(j['boxes']),
        avgWeightGrams: _i(j['avgWeightGrams']),
        weightMethod: WeightMethod.fromWire(j['weightMethod'] as String?),
        sampleWeightsGrams: [for (final g in (j['sampleWeightsGrams'] as List?) ?? const []) (g as num).toInt()],
        tareGrams: _in(j['tareGrams']),
        pricePerKgPiasters: _i(j['pricePerKgPiasters']),
        occurredAt: _s(j['occurredAt']),
        notes: _s(j['notes']),
        payment: PaymentModeInput.fromJson(j['payment'] is Map ? _m(j['payment']) : const {}),
      );

  final String coolerId;

  /// مزارع موجود، أو [newFarmerName] لإضافة مزارع جديد مع العملية.
  final String? farmerId;
  final String? newFarmerName;
  final int boxes;
  final int avgWeightGrams;
  final WeightMethod weightMethod;
  final List<int> sampleWeightsGrams;
  final int? tareGrams;
  final int pricePerKgPiasters;

  /// null ⇒ الخادم يستخدم «الآن».
  final String? occurredAt;
  final String? notes;
  final PaymentModeInput payment;

  Map<String, dynamic> toJson() => {
        'coolerId': coolerId,
        if (farmerId != null) 'farmerId': farmerId,
        if (newFarmerName != null) 'newFarmerName': newFarmerName,
        'boxes': boxes,
        'avgWeightGrams': avgWeightGrams,
        'weightMethod': weightMethod.wire,
        if (weightMethod == WeightMethod.sample) 'sampleWeightsGrams': sampleWeightsGrams,
        if (weightMethod == WeightMethod.sample && tareGrams != null) 'tareGrams': tareGrams,
        'pricePerKgPiasters': pricePerKgPiasters,
        if (occurredAt != null) 'occurredAt': occurredAt,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
        'payment': payment.toJson(),
      };
}

enum PaymentMode {
  full('full', 'مدفوع بالكامل'),
  partial('partial', 'دفع جزئي'),
  none('none', 'لم يُدفع بعد');

  const PaymentMode(this.wire, this.label);
  final String wire;
  final String label;

  static PaymentMode fromWire(String? v) =>
      PaymentMode.values.firstWhere((m) => m.wire == v, orElse: () => PaymentMode.none);
}

enum PaymentMethod {
  cash('cash', 'نقدًا'),
  bank('bank', 'تحويل بنكي'),
  wallet('wallet', 'محفظة إلكترونية');

  const PaymentMethod(this.wire, this.label);
  final String wire;
  final String label;

  static PaymentMethod fromWire(String? v) =>
      PaymentMethod.values.firstWhere((m) => m.wire == v, orElse: () => PaymentMethod.cash);
}

class PaymentModeInput {
  const PaymentModeInput({required this.mode, this.amountPiasters, this.method = PaymentMethod.cash});

  factory PaymentModeInput.fromJson(Map<String, dynamic> j) => PaymentModeInput(
        mode: PaymentMode.fromWire(j['mode'] as String?),
        amountPiasters: _in(j['amountPiasters']),
        method: PaymentMethod.fromWire(j['method'] as String?),
      );

  final PaymentMode mode;

  /// مطلوب فقط مع [PaymentMode.partial].
  final int? amountPiasters;
  final PaymentMethod method;

  Map<String, dynamic> toJson() => {
        'mode': mode.wire,
        if (mode == PaymentMode.partial) 'amountPiasters': amountPiasters,
        if (mode != PaymentMode.none) 'method': method.wire,
      };
}

class PurchaseResult {
  const PurchaseResult({required this.purchase, this.payment, this.farmer, this.replayed = false});

  factory PurchaseResult.fromJson(Map<String, dynamic> j) => PurchaseResult(
        purchase: Purchase.fromJson(_m(j['purchase'])),
        payment: j['payment'] is Map ? Payment.fromJson(_m(j['payment'])) : null,
        farmer: j['farmer'] is Map ? Farmer.fromJson(_m(j['farmer'])) : null,
        replayed: j['replayed'] == true,
      );

  final Purchase purchase;
  final Payment? payment;

  /// المزارع الجديد إن أُضيف مع العملية.
  final Farmer? farmer;

  /// true إذا كانت إعادة إرسال لطلب حُفظ من قبل (لم يُنشأ سجل جديد).
  final bool replayed;
}

// ---------------------------------------------------------------- المدفوعات

class Payment {
  const Payment({
    required this.id,
    required this.no,
    required this.payeeType,
    required this.payeeName,
    this.payeeId,
    required this.targetType,
    required this.targetId,
    this.coolerId,
    this.coolerNo,
    required this.amountPiasters,
    required this.method,
    required this.paidAt,
    required this.active,
    this.cancelReason,
    this.notes,
    this.createdAt,
    this.createdBy,
    this.version = 1,
  });

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: _str(j['id']),
        no: _str(j['no']),
        payeeType: j['payeeType'] == 'supplier' ? PayeeType.supplier : PayeeType.farmer,
        payeeName: _str(j['payeeName']),
        payeeId: _s(j['payeeId']),
        targetType: j['targetType'] == 'packaging' ? PaymentTarget.packaging : PaymentTarget.purchase,
        targetId: _str(j['targetId']),
        coolerId: _s(j['coolerId']),
        coolerNo: _in(j['coolerNo']),
        amountPiasters: _i(j['amountPiasters']),
        method: PaymentMethod.fromWire(j['method'] as String?),
        paidAt: _str(j['paidAt']),
        active: j['status'] != 'cancelled',
        cancelReason: _s(j['cancelReason']),
        notes: _s(j['notes']),
        createdAt: _s(j['createdAt']),
        createdBy: _s(j['createdBy']),
        version: _in(j['version']) ?? 1,
      );

  final String id;
  final String no;
  final PayeeType payeeType;
  final String payeeName;
  final String? payeeId;
  final PaymentTarget targetType;
  final String targetId;
  final String? coolerId;
  final int? coolerNo;
  final int amountPiasters;
  final PaymentMethod method;
  final String paidAt;
  final bool active;
  final String? cancelReason;
  final String? notes;
  final String? createdAt;
  final String? createdBy;
  final int version;
}

enum PayeeType {
  farmer('farmer', 'مزارع'),
  supplier('supplier', 'مورد');

  const PayeeType(this.wire, this.label);
  final String wire;
  final String label;
}

enum PaymentTarget {
  purchase('purchase', 'شراء رمان'),
  packaging('packaging', 'شراء تعبئة');

  const PaymentTarget(this.wire, this.label);
  final String wire;
  final String label;
}

/// نتيجة تسجيل دفعة أو إلغائها: الدفعة والعملية المرتبطة بعد تحديث المدفوع والمتبقي.
class PaymentResult {
  const PaymentResult({required this.payment, this.purchase, this.packaging});

  factory PaymentResult.fromJson(Map<String, dynamic> j) {
    final payment = Payment.fromJson(_m(j['payment']));
    final target = j['target'] is Map ? _m(j['target']) : null;
    return PaymentResult(
      payment: payment,
      purchase: target != null && payment.targetType == PaymentTarget.purchase ? Purchase.fromJson(target) : null,
      packaging:
          target != null && payment.targetType == PaymentTarget.packaging ? PackagingSummary.fromJson(target) : null,
    );
  }

  final Payment payment;
  final Purchase? purchase;
  final PackagingSummary? packaging;
}

// ---------------------------------------------------------------- مشتريات التعبئة

enum PackagingStatus {
  draft('draft', 'مسودة'),
  approved('approved', 'معتمد'),
  cancelled('cancelled', 'ملغى');

  const PackagingStatus(this.wire, this.label);
  final String wire;
  final String label;

  static PackagingStatus fromWire(String? v) =>
      PackagingStatus.values.firstWhere((s) => s.wire == v, orElse: () => PackagingStatus.draft);
}

class PackagingSummary {
  const PackagingSummary({
    required this.id,
    required this.no,
    this.supplier,
    this.invoiceNo,
    this.occurredAt,
    this.coolerId,
    this.coolerNo,
    required this.status,
    this.itemsCount = 0,
    this.incompleteCount = 0,
    this.completeTotalPiasters = 0,
    this.paidPiasters = 0,
    this.remainingPiasters = 0,
    this.late = false,
    this.notes,
    this.createdAt,
    this.createdBy,
    this.version = 1,
  });

  factory PackagingSummary.fromJson(Map<String, dynamic> j) => PackagingSummary(
        id: _str(j['id']),
        no: _str(j['no']),
        supplier: _s(j['supplier']),
        invoiceNo: _s(j['invoiceNo']),
        occurredAt: _s(j['occurredAt']),
        coolerId: _s(j['coolerId']),
        coolerNo: _in(j['coolerNo']),
        status: PackagingStatus.fromWire(j['status'] as String?),
        itemsCount: _i(j['itemsCount']),
        incompleteCount: _i(j['incompleteCount']),
        completeTotalPiasters: _i(j['completeTotalPiasters']),
        paidPiasters: _i(j['paidPiasters']),
        remainingPiasters: _i(j['remainingPiasters']),
        late: j['late'] == true,
        notes: _s(j['notes']),
        createdAt: _s(j['createdAt']),
        createdBy: _s(j['createdBy']),
        version: _in(j['version']) ?? 1,
      );

  final String id;
  final String no;
  final String? supplier;
  final String? invoiceNo;
  final String? occurredAt;
  final String? coolerId;
  final int? coolerNo;
  final PackagingStatus status;
  final int itemsCount;

  /// عناصر تنقصها الكمية أو السعر. المسودة لا تُعتمد قبل أن يصبح صفرًا.
  final int incompleteCount;

  /// مجموع العناصر المكتملة فقط.
  final int completeTotalPiasters;
  final int paidPiasters;
  final int remainingPiasters;

  /// «تكلفة متأخرة»: اعتُمدت بعد تقفيل البراد المرتبط.
  final bool late;
  final String? notes;
  final String? createdAt;
  final String? createdBy;
  final int version;
}

enum PackagingItemStatus {
  complete('complete', 'مكتمل'),
  incomplete('incomplete', 'غير مكتمل'),
  removed('removed', 'محذوف');

  const PackagingItemStatus(this.wire, this.label);
  final String wire;
  final String label;

  static PackagingItemStatus fromWire(String? v) =>
      PackagingItemStatus.values.firstWhere((s) => s.wire == v, orElse: () => PackagingItemStatus.incomplete);
}

class PackagingItem {
  const PackagingItem({
    this.id,
    required this.name,
    this.quantity,
    required this.unit,
    this.unitPricePiasters,
    this.totalPiasters,
    this.status = PackagingItemStatus.incomplete,
    this.notes,
    this.version = 1,
  });

  factory PackagingItem.fromJson(Map<String, dynamic> j) => PackagingItem(
        id: _s(j['id']),
        name: _str(j['name']),
        quantity: _in(j['quantity']),
        unit: _str(j['unit']),
        unitPricePiasters: _in(j['unitPricePiasters']),
        totalPiasters: _in(j['totalPiasters']),
        status: PackagingItemStatus.fromWire(j['status'] as String?),
        notes: _s(j['notes']),
        version: _in(j['version']) ?? 1,
      );

  /// null لعنصر جديد لم يُحفظ بعد.
  final String? id;
  final String name;

  /// null = لم تُكتب بعد (ليست صفرًا).
  final int? quantity;
  final String unit;

  /// null = لم يُسعَّر بعد (ليس صفرًا).
  final int? unitPricePiasters;
  final int? totalPiasters;
  final PackagingItemStatus status;
  final String? notes;
  final int version;

  bool get isComplete => quantity != null && unitPricePiasters != null;

  /// شكل العنصر في packaging.save.
  Map<String, dynamic> toSaveJson() => {
        if (id != null) 'id': id,
        'name': name,
        if (quantity != null) 'quantity': quantity,
        'unit': unit,
        if (unitPricePiasters != null) 'unitPricePiasters': unitPricePiasters,
      };
}

/// بيانات مسودة التعبئة (packaging.save). القائمة كاملة دائمًا: العناصر غير المرسلة تُحذف من المسودة.
class PackagingDraftInput {
  const PackagingDraftInput({
    this.id,
    this.expectedVersion,
    this.supplier,
    this.invoiceNo,
    this.coolerId,
    this.occurredAt,
    this.notes,
    required this.items,
  });

  final String? id;
  final int? expectedVersion;
  final String? supplier;
  final String? invoiceNo;
  final String? coolerId;
  final String? occurredAt;
  final String? notes;
  final List<PackagingItem> items;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (expectedVersion != null) 'expectedVersion': expectedVersion,
        if (supplier != null) 'supplier': supplier,
        if (invoiceNo != null) 'invoiceNo': invoiceNo,
        if (coolerId != null) 'coolerId': coolerId,
        if (occurredAt != null) 'occurredAt': occurredAt,
        if (notes != null) 'notes': notes,
        'items': [for (final i in items) i.toSaveJson()],
      };
}

class PackagingDetail {
  const PackagingDetail({required this.packaging, required this.items});

  factory PackagingDetail.fromJson(Map<String, dynamic> j) => PackagingDetail(
        packaging: PackagingSummary.fromJson(_m(j['packaging'])),
        items: [for (final i in _list(j['items'])) PackagingItem.fromJson(i)],
      );

  final PackagingSummary packaging;

  /// دون العناصر المحذوفة من المسودة.
  final List<PackagingItem> items;
}

class ItemType {
  const ItemType({this.id, required this.name, required this.unit, this.order = 0, this.active = true});

  factory ItemType.fromJson(Map<String, dynamic> j) => ItemType(
        id: _s(j['id']),
        name: _str(j['name']),
        unit: _str(j['unit']),
        order: _i(j['order']),
        active: j['active'] != false,
      );

  final String? id;
  final String name;
  final String unit;
  final int order;
  final bool active;
}

/// الوحدات المسموح بها في صفحة «تفاصيل التعبئة».
const packagingUnits = ['قطعة', 'رزمة', 'لفة', 'رول', 'كرتونة', 'كغ'];

// ---------------------------------------------------------------- البراد بالتفصيل

class CoolerDetail {
  const CoolerDetail({required this.cooler, this.purchases = const [], this.packaging = const []});

  factory CoolerDetail.fromJson(Map<String, dynamic> j) => CoolerDetail(
        cooler: CoolerSummary.fromJson(_m(j['cooler'])),
        purchases: [for (final p in _list(j['purchases'])) Purchase.fromJson(p)],
        packaging: [for (final p in _list(j['packaging'])) PackagingSummary.fromJson(p)],
      );

  final CoolerSummary cooler;

  /// كل العمليات، بما فيها الملغاة (مميزة بـ [Purchase.active]).
  final List<Purchase> purchases;
  final List<PackagingSummary> packaging;
}
