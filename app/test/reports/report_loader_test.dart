import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/models/settings.dart';
import 'package:rumman_calculator/core/reports/reports.dart';

import '../support/fake_backend_api.dart';
import '../support/sample_data.dart';

Map<String, dynamic> purchaseJson(String id, {String farmerId = 'FR-0001', String status = 'active', int paid = 0}) => {
      'id': id,
      'coolerId': 'CL-0014',
      'coolerNo': 14,
      'farmerId': farmerId,
      'farmerName': 'حسن البدري',
      'occurredAt': '2026-10-02T06:40:00+03:00',
      'boxes': 10,
      'avgWeightGrams': 11000,
      'weightMethod': 'direct',
      'totalWeightGrams': 110000,
      'pricePerKgPiasters': 1500,
      'valuePiasters': 165000,
      'paidPiasters': paid,
      'remainingPiasters': 165000 - paid,
      'payStatus': paid == 0 ? 'unpaid' : 'partial',
      'status': status,
    };

Map<String, dynamic> packagingJson(String id, String status, {int total = 10000}) => {
      'id': id,
      'no': 'P-${id.substring(3)}',
      'supplier': 'مصنع الكرتون',
      'occurredAt': '2026-10-02T08:00:00+03:00',
      'coolerId': 'CL-0014',
      'coolerNo': 14,
      'status': status,
      'itemsCount': 1,
      'completeTotalPiasters': total,
      'paidPiasters': 0,
      'remainingPiasters': status == 'approved' ? total : 0,
    };

Map<String, dynamic> paymentJson(String id, {String status = 'active'}) => {
      'id': id,
      'no': 'D-0001',
      'payeeType': 'farmer',
      'payeeName': 'حسن البدري',
      'payeeId': 'FR-0001',
      'targetType': 'purchase',
      'targetId': 'PU-0001',
      'coolerId': 'CL-0014',
      'coolerNo': 14,
      'amountPiasters': 50000,
      'method': 'cash',
      'paidAt': '2026-10-02T07:00:00+03:00',
      'status': status,
    };

void main() {
  late FakeBackendApi api;
  late ReportLoader loader;

  setUp(() {
    api = FakeBackendApi(settings: const BusinessSettings(businessName: 'حاسبة الحسناوي', currencySymbol: 'EGP'));
    loader = ReportLoader(api);
    api.handlers['coolers.get'] = (p) => {
          'cooler': {...cooler14Json(), 'status': 'closed', 'closedAt': '2026-10-02T17:30:00+03:00'},
          'purchases': [purchaseJson('PU-0001', paid: 50000), purchaseJson('PU-0002', status: 'cancelled')],
          'packaging': [
            packagingJson('PK-0001', 'approved'),
            packagingJson('PK-0002', 'draft'),
            packagingJson('PK-0003', 'approved', total: 5000),
          ],
        };
    api.handlers['payments.list'] = (p) => {
          'payments': [paymentJson('PY-0001'), paymentJson('PY-0002', status: 'cancelled')],
        };
    api.handlers['packaging.get'] = (p) => {
          'packaging': packagingJson(p['id'] as String, 'approved'),
          'items': [
            {'id': 'IT-1', 'name': 'كرتونة', 'quantity': 20, 'unit': 'كرتونة', 'unitPricePiasters': 500,
              'totalPiasters': 10000, 'status': 'complete'},
          ],
        };
    api.handlers['farmers.list'] = (p) => {
          'farmers': [
            {'id': 'FR-0001', 'no': 1, 'name': 'حسن البدري', 'status': 'active'},
          ],
        };
    api.handlers['purchases.list'] = (p) => {
          'purchases': [purchaseJson('PU-0001', paid: 50000), purchaseJson('PU-0002', status: 'cancelled')],
        };
    api.handlers['packaging.list'] = (p) => {
          'packaging': [packagingJson('PK-0001', 'approved'), packagingJson('PK-0002', 'draft')],
        };
  });

  test('تقرير البراد: coolers.get + payments.list(coolerId) + packaging.get للمعتمدة فقط', () async {
    final report = await loader.coolerReport('CL-0014');
    expect(api.callsOf('coolers.get').single.payload, {'id': 'CL-0014'});
    expect(api.callsOf('payments.list').single.payload, {'coolerId': 'CL-0014'});
    expect([for (final c in api.callsOf('packaging.get')) c.payload['id']], ['PK-0001', 'PK-0003']);
    expect(report.totals.operations, 1);
    expect(report.totals.cancelled, 1);
    expect(report.packagingTotals.approvedPiasters, 15000);
    expect(report.approvedItems.keys, {'PK-0001', 'PK-0003'});
    expect(report.paymentTotals.totalPiasters, 50000);
    expect(report.currency, 'EGP');
  });

  test('الإعدادات تُجلب مرة واحدة لكل محمّل', () async {
    await loader.coolerReport('CL-0014');
    await loader.periodReport();
    expect((await loader.settings()).businessName, 'حاسبة الحسناوي');
    expect(api.count('settings.get'), 1);
  });

  test('فشل الإعدادات لا يُفشل التقرير (العملة الافتراضية)', () async {
    api.settingsError = const ApiException(ApiErrorCode.network, 'لا يوجد اتصال');
    final report = await loader.coolerReport('CL-0014');
    expect(report.currency, 'ج.م');
  });

  test('خطأ الخادم يصل كما هو ApiException', () async {
    api.errors['payments.list'] = const ApiException(ApiErrorCode.forbidden, 'لا تملك صلاحية');
    await expectLater(
      loader.coolerReport('CL-0014'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.forbidden)),
    );
  });

  test('كشف المزارع: الفترة بتاريخ العمل ومع الملغاة، والدفعات حسب المستفيد', () async {
    final s = await loader.farmerStatement('FR-0001', from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 2, 18));
    expect(api.callsOf('farmers.list').single.payload, {'includeInactive': true});
    expect(api.callsOf('purchases.list').single.payload,
        {'farmerId': 'FR-0001', 'from': '2026-10-01', 'to': '2026-10-02', 'includeCancelled': true});
    expect(api.callsOf('payments.list').single.payload, {'payeeId': 'FR-0001'});
    expect(s.farmer.name, 'حسن البدري');
    expect(s.valuePiasters, 165000);
    expect(s.remainingPiasters, 115000);
  });

  test('كشف مزارع غير موجود ⇒ NOT_FOUND', () async {
    await expectLater(
      loader.farmerStatement('FR-9999'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.notFound)),
    );
  });

  test('تقرير الموردين: packaging.get للمعتمدة في النطاق فقط', () async {
    final r = await loader.supplierReport();
    expect(api.callsOf('packaging.list').single.payload, isEmpty);
    expect([for (final c in api.callsOf('packaging.get')) c.payload['id']], ['PK-0001']);
    expect(r.totals.approvedPiasters, 10000);
    expect(r.totals.draftCount, 1);

    api.calls.clear();
    await loader.supplierReport(includeItems: false);
    expect(api.count('packaging.get'), 0);
  });

  test('أسماء الموردين دون تكرار', () async {
    api.handlers['packaging.list'] = (p) => {
          'packaging': [
            {...packagingJson('PK-0001', 'approved'), 'supplier': 'مصنع الكرتون'},
            {...packagingJson('PK-0002', 'draft'), 'supplier': ' مصنع  الكرتون'},
            {...packagingJson('PK-0003', 'draft'), 'supplier': 'الشبك الحديث'},
            {...packagingJson('PK-0004', 'draft'), 'supplier': ''},
          ],
        };
    expect(await loader.suppliers(), ['الشبك الحديث', 'مصنع الكرتون']);
  });

  test('تقرير الفترة: كل القراءات اللازمة', () async {
    final r = await loader.periodReport(from: DateTime(2026, 10, 2), to: DateTime(2026, 10, 2));
    expect(
      api.callsOf('purchases.list').single.payload,
      {'from': '2026-10-02', 'to': '2026-10-02', 'includeCancelled': true},
    );
    expect(api.callsOf('payments.list').single.payload, isEmpty);
    expect(api.callsOf('packaging.list').single.payload, isEmpty);
    expect(api.callsOf('coolers.list').single.payload, {'status': 'all'});
    expect(r.totals.operations, 1);
    expect(r.paymentTotals.totalPiasters, 50000);
    expect(r.coolers.single.label, 'براد 14 · شحنة دمياط');
  });
}
