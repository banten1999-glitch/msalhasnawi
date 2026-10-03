import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/ui/labeled_field.dart';

import '../../support/fake_backend_api.dart';

/// بيانات المزارعين ومشترياتهم بصيغة docs/API.md §6.

Map<String, dynamic> farmerJson(
  String id,
  int no,
  String name, {
  String phone = '',
  String village = '',
  String notes = '',
  String status = 'active',
  int version = 1,
}) =>
    {
      'id': id,
      'no': no,
      'name': name,
      'phone': phone,
      'village': village,
      'notes': notes,
      'status': status,
      'version': version,
    };

List<Map<String, dynamic>> sampleFarmersJson() => [
      farmerJson('FR-0001', 1, 'حسن البدري', phone: '01001234567', village: 'بني عدي', version: 2),
      farmerJson('FR-0002', 2, 'أحمد الشافعى', phone: '01119876543', village: 'منفلوط'),
      farmerJson('FR-0003', 3, 'الحاج محمود عبد العال', village: 'القوصية'),
      farmerJson('FR-0004', 4, 'رمضان حسانين', status: 'inactive', version: 4),
    ];

Map<String, dynamic> purchaseJson({
  required String id,
  required String farmerId,
  required String farmerName,
  String coolerId = 'CL-0014',
  int coolerNo = 14,
  String occurredAt = '2026-10-02T10:42:00+03:00',
  int boxes = 50,
  int avgWeightGrams = 11000,
  int pricePerKgPiasters = 1500,
  required int valuePiasters,
  int paidPiasters = 0,
  String status = 'active',
}) =>
    {
      'id': id,
      'coolerId': coolerId,
      'coolerNo': coolerNo,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'occurredAt': occurredAt,
      'boxes': boxes,
      'avgWeightGrams': avgWeightGrams,
      'weightMethod': 'direct',
      'sampleWeightsGrams': <int>[],
      'tareGrams': null,
      'totalWeightGrams': boxes * avgWeightGrams,
      'pricePerKgPiasters': pricePerKgPiasters,
      'valuePiasters': valuePiasters,
      'paidPiasters': paidPiasters,
      'remainingPiasters': valuePiasters - paidPiasters,
      'payStatus': paidPiasters == 0 ? 'unpaid' : (paidPiasters >= valuePiasters ? 'paid' : 'partial'),
      'status': status,
      'cancelReason': '',
      'notes': '',
      'createdAt': occurredAt,
      'createdBy': 'كريم عبد الله',
      'version': 1,
    };

/// حسن: عمليتان (المتبقي 5,000.00)، أحمد: عملية مدفوعة بالكامل، محمود: لا عمليات.
List<Map<String, dynamic>> samplePurchasesJson() => [
      purchaseJson(id: 'PU-0001', farmerId: 'FR-0001', farmerName: 'حسن البدري', valuePiasters: 825000, paidPiasters: 500000),
      purchaseJson(
        id: 'PU-0002',
        farmerId: 'FR-0001',
        farmerName: 'حسن البدري',
        boxes: 20,
        valuePiasters: 330000,
        paidPiasters: 155000,
      ),
      purchaseJson(id: 'PU-0003', farmerId: 'FR-0002', farmerName: 'أحمد الشافعى', valuePiasters: 412500, paidPiasters: 412500),
    ];

/// يسجّل ردود farmers.list وpurchases.list في الخادم الوهمي.
void installFarmers(FakeBackendApi api, {List<Map<String, dynamic>>? farmers, List<Map<String, dynamic>>? purchases}) {
  final all = farmers ?? sampleFarmersJson();
  api.handlers['farmers.list'] = (p) => {
        'farmers': [
          for (final f in all)
            if (p['includeInactive'] == true || f['status'] == 'active') f,
        ],
      };
  api.handlers['purchases.list'] = (p) => {'purchases': purchases ?? samplePurchasesJson()};
}

/// حقل النص تحت التسمية [label] في LabeledField.
Finder fieldLabeled(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(LabeledField)).first,
      matching: find.byType(TextField),
    );

/// يضغط بعد التمرير إليه.
Future<void> tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}
