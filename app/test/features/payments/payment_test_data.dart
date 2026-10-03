import '../../support/fake_backend_api.dart';
import '../farmers/farmer_test_data.dart';

/// بيانات المدفوعات والمستحقات بصيغة docs/API.md §6.

Map<String, dynamic> paymentJson({
  required String id,
  required String no,
  String payeeType = 'farmer',
  required String payeeName,
  String payeeId = '',
  String targetType = 'purchase',
  required String targetId,
  String? coolerId = 'CL-0014',
  int? coolerNo = 14,
  required int amountPiasters,
  String method = 'cash',
  String paidAt = '2026-10-02T10:42:00+03:00',
  String status = 'active',
  String cancelReason = '',
  String notes = '',
  String createdBy = 'كريم عبد الله',
}) =>
    {
      'id': id,
      'no': no,
      'payeeType': payeeType,
      'payeeName': payeeName,
      'payeeId': payeeId,
      'targetType': targetType,
      'targetId': targetId,
      'coolerId': coolerId ?? '',
      'coolerNo': coolerNo,
      'amountPiasters': amountPiasters,
      'method': method,
      'paidAt': paidAt,
      'status': status,
      'cancelReason': cancelReason,
      'notes': notes,
      'createdAt': paidAt,
      'createdBy': createdBy,
      'version': 1,
    };

/// الفعّالة: 5,000.00 + 1,550.00 + 4,125.00 + 2,000.00 = 12,675.00. وواحدة ملغاة بمبلغ 1,000.00.
List<Map<String, dynamic>> samplePaymentsJson() => [
      paymentJson(
        id: 'PY-0005',
        no: 'D-0005',
        payeeName: 'حسن البدري',
        payeeId: 'FR-0001',
        targetId: 'PU-0001',
        amountPiasters: 100000,
        paidAt: '2026-10-02T11:05:00+03:00',
        status: 'cancelled',
        cancelReason: 'سُجّلت مرتين بالخطأ',
      ),
      paymentJson(
        id: 'PY-0004',
        no: 'D-0004',
        payeeType: 'supplier',
        payeeName: 'الوادي للتغليف',
        targetType: 'packaging',
        targetId: 'PK-0004',
        amountPiasters: 200000,
        paidAt: '2026-10-02T09:50:00+03:00',
      ),
      paymentJson(
        id: 'PY-0003',
        no: 'D-0003',
        payeeName: 'أحمد الشافعى',
        payeeId: 'FR-0002',
        targetId: 'PU-0003',
        coolerId: 'CL-0013',
        coolerNo: 13,
        amountPiasters: 412500,
        method: 'wallet',
        paidAt: '2026-10-01T16:30:00+03:00',
        createdBy: 'يوسف ناصر',
      ),
      paymentJson(
        id: 'PY-0002',
        no: 'D-0002',
        payeeName: 'حسن البدري',
        payeeId: 'FR-0001',
        targetId: 'PU-0002',
        coolerId: 'CL-0013',
        coolerNo: 13,
        amountPiasters: 155000,
        method: 'bank',
        paidAt: '2026-10-01T15:00:00+03:00',
      ),
      paymentJson(
        id: 'PY-0001',
        no: 'D-0001',
        payeeName: 'حسن البدري',
        payeeId: 'FR-0001',
        targetId: 'PU-0001',
        amountPiasters: 500000,
        paidAt: '2026-10-01T10:00:00+03:00',
      ),
    ];

/// حسن: PU-0001 (براد 14، المتبقي 3,250.00) وPU-0002 (براد 13، المتبقي 1,750.00). أحمد: مدفوع بالكامل.
List<Map<String, dynamic>> paymentPurchasesJson() => [
      purchaseJson(
        id: 'PU-0001',
        farmerId: 'FR-0001',
        farmerName: 'حسن البدري',
        occurredAt: '2026-10-02T06:40:00+03:00',
        valuePiasters: 825000,
        paidPiasters: 500000,
      ),
      purchaseJson(
        id: 'PU-0002',
        farmerId: 'FR-0001',
        farmerName: 'حسن البدري',
        coolerId: 'CL-0013',
        coolerNo: 13,
        occurredAt: '2026-10-01T14:00:00+03:00',
        boxes: 20,
        valuePiasters: 330000,
        paidPiasters: 155000,
      ),
      purchaseJson(
        id: 'PU-0003',
        farmerId: 'FR-0002',
        farmerName: 'أحمد الشافعى',
        coolerId: 'CL-0013',
        coolerNo: 13,
        valuePiasters: 412500,
        paidPiasters: 412500,
      ),
    ];

Map<String, dynamic> packagingJson({
  required String id,
  required String no,
  String? supplier,
  String? invoiceNo,
  String? coolerId,
  int? coolerNo,
  String status = 'approved',
  int itemsCount = 3,
  required int totalPiasters,
  int paidPiasters = 0,
  String occurredAt = '2026-10-02T09:00:00+03:00',
}) =>
    {
      'id': id,
      'no': no,
      'supplier': supplier,
      'invoiceNo': invoiceNo,
      'occurredAt': occurredAt,
      'coolerId': coolerId,
      'coolerNo': coolerNo,
      'status': status,
      'itemsCount': itemsCount,
      'incompleteCount': 0,
      'completeTotalPiasters': totalPiasters,
      'paidPiasters': paidPiasters,
      'remainingPiasters': totalPiasters - paidPiasters,
      'late': false,
      'notes': '',
      'createdAt': occurredAt,
      'createdBy': 'كريم عبد الله',
      'version': 2,
    };

/// الوادي: P-0004 (المتبقي 2,500.00) وP-0005 دون براد (1,000.00). مطبعة النيل مدفوعة بالكامل.
List<Map<String, dynamic>> sampleApprovedPackagingJson() => [
      packagingJson(
        id: 'PK-0004',
        no: 'P-0004',
        supplier: 'الوادي للتغليف',
        invoiceNo: '77',
        coolerId: 'CL-0014',
        coolerNo: 14,
        totalPiasters: 450000,
        paidPiasters: 200000,
      ),
      packagingJson(
        id: 'PK-0005',
        no: 'P-0005',
        supplier: 'الوادي للتغليف',
        itemsCount: 1,
        totalPiasters: 100000,
        occurredAt: '2026-10-02T09:30:00+03:00',
      ),
      packagingJson(
        id: 'PK-0006',
        no: 'P-0006',
        supplier: 'مطبعة النيل',
        coolerId: 'CL-0013',
        coolerNo: 13,
        totalPiasters: 120000,
        paidPiasters: 120000,
      ),
    ];

/// يسجّل ردود القراءة التي يحتاجها قسم المدفوعات.
void installPayments(
  FakeBackendApi api, {
  List<Map<String, dynamic>>? payments,
  List<Map<String, dynamic>>? purchases,
  List<Map<String, dynamic>>? packaging,
}) {
  api.handlers['payments.list'] = (p) => {'payments': payments ?? samplePaymentsJson()};
  final allPurchases = purchases ?? paymentPurchasesJson();
  api.handlers['purchases.list'] = (p) => {
        'purchases': [
          for (final x in allPurchases)
            if (p['includeCancelled'] == true || x['status'] == 'active') x,
        ],
      };
  final allPackaging = packaging ?? sampleApprovedPackagingJson();
  api.handlers['packaging.list'] = (p) => {
        'packaging': [
          for (final x in allPackaging)
            if (p['status'] == null || x['status'] == p['status']) x,
        ],
      };
  api.handlers['packaging.get'] = (p) => {
        'packaging': allPackaging.firstWhere((x) => x['id'] == p['id']),
        'items': <Map<String, dynamic>>[],
      };
}

/// رد payments.create: الدفعة الجديدة والعملية بعد تحديث المدفوع.
Map<String, dynamic> createdPayment(Map<String, dynamic> p, {String no = 'D-0006'}) => {
      'payment': paymentJson(
        id: 'PY-0006',
        no: no,
        payeeName: 'حسن البدري',
        targetType: p['targetType'] as String,
        targetId: p['targetId'] as String,
        amountPiasters: (p['amountPiasters'] as num).toInt(),
        method: p['method'] as String,
      ),
      'target': null,
      'replayed': false,
    };
