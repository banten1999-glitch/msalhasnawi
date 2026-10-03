import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/backend_api.dart';
import 'package:rumman_calculator/core/models/user.dart';
import 'package:rumman_calculator/core/sync/data_changes.dart';
import 'package:rumman_calculator/core/sync/outbox.dart';
import 'package:rumman_calculator/ui/labeled_field.dart';

import '../../support/fake_auth_controller.dart';
import '../../support/fake_backend_api.dart';
import '../../support/sample_data.dart';
import '../../support/test_app.dart';

/// صفحة سابقة تفتح [page] فوقها (حتى يعمل الرجوع بعد الحفظ كما في التطبيق).
class Launcher extends StatefulWidget {
  const Launcher(this.page, {super.key});

  final Widget page;

  @override
  State<Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<Launcher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => widget.page));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('الصفحة السابقة')));
}

/// يفتح [page] فوق صفحة سابقة داخل التطبيق.
Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  required BackendApi api,
  AppUser? user,
  Outbox? outbox,
  DataChanges? changes,
  Size size = phoneSize,
}) =>
    pumpTestApp(
      tester,
      Launcher(page),
      api: api,
      auth: FakeAuthController(user: user ?? sampleAdmin()),
      outbox: outbox,
      changes: changes,
      size: size,
    );

/// حقل النص تحت التسمية [label] (LabeledField).
Finder fieldIn(String label) =>
    find.descendant(of: find.widgetWithText(LabeledField, label), matching: find.byType(TextField)).first;

/// يمرر حتى يظهر العنصر ثم يضغطه.
Future<void> tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> typeInto(WidgetTester tester, String label, String text) async {
  await tester.enterText(fieldIn(label), text);
  await tester.pump();
}

/// مزارعون نشطون كما يعيدهم farmers.list.
List<Map<String, dynamic>> farmersJson() => [
      {'id': 'FR-0001', 'no': 1, 'name': 'حسن البدري', 'village': 'كفر سعد', 'status': 'active', 'version': 1},
      {'id': 'FR-0002', 'no': 2, 'name': 'عبد الرحمن الشافعي', 'village': 'الزرقا', 'status': 'active', 'version': 1},
      {'id': 'FR-0003', 'no': 3, 'name': 'الحاج محمود عبد العال', 'status': 'active', 'version': 2},
      {'id': 'FR-0004', 'no': 4, 'name': 'سعيد أبو زيد', 'status': 'active', 'version': 1},
    ];

/// عملية شراء بصيغة الخادم (50 صندوق × 11 كغ × 15 ج.م افتراضيًا).
Map<String, dynamic> purchaseJson({
  String id = 'PU-0030',
  String coolerId = 'CL-0014',
  int coolerNo = 14,
  String farmerId = 'FR-0001',
  String farmerName = 'حسن البدري',
  int boxes = 50,
  int avg = 11000,
  int price = 1500,
  int paid = 0,
  String status = 'active',
  String? cancelReason,
  String method = 'direct',
  List<int> samples = const [],
  int? tare,
  String createdBy = 'محمد الحسناوي',
  String createdByEmail = 'hasnawi.owner@gmail.com',
  String occurredAt = '2026-10-02T09:31:00+03:00',
  String? notes,
  int version = 1,
}) {
  final weight = boxes * avg;
  final value = (weight * price + 500) ~/ 1000;
  final active = status == 'active';
  return {
    'id': id,
    'coolerId': coolerId,
    'coolerNo': coolerNo,
    'farmerId': farmerId,
    'farmerName': farmerName,
    'occurredAt': occurredAt,
    'boxes': boxes,
    'avgWeightGrams': avg,
    'weightMethod': method,
    'sampleWeightsGrams': samples,
    'tareGrams': tare,
    'totalWeightGrams': weight,
    'pricePerKgPiasters': price,
    'valuePiasters': value,
    'paidPiasters': paid,
    'remainingPiasters': active ? value - paid : 0,
    'payStatus': paid <= 0 ? 'unpaid' : (paid >= value ? 'paid' : 'partial'),
    'status': status,
    'cancelReason': cancelReason,
    'notes': notes,
    'createdAt': occurredAt,
    'createdBy': createdBy,
    'createdByEmail': createdByEmail,
    'version': version,
  };
}

/// براد بالتفصيل كما يعيده coolers.get.
Map<String, dynamic> coolerDetailJson({
  Map<String, dynamic>? cooler,
  List<Map<String, dynamic>>? purchases,
  List<Map<String, dynamic>> packaging = const [],
}) =>
    {
      'cooler': cooler ?? cooler14Json(),
      'purchases': purchases ??
          [
            purchaseJson(id: 'PU-0023', paid: 200000),
            purchaseJson(
              id: 'PU-0022',
              farmerId: 'FR-0002',
              farmerName: 'عبد الرحمن الشافعي',
              boxes: 56,
              avg: 12000,
              price: 1200,
              paid: 806400,
              createdBy: 'كريم عبد الله',
              createdByEmail: 'karim.abdallah.eg@gmail.com',
            ),
            purchaseJson(
              id: 'PU-0019',
              farmerId: 'FR-0004',
              farmerName: 'سعيد أبو زيد',
              boxes: 30,
              status: 'cancelled',
              cancelReason: 'سُجّلت مرتين بالخطأ',
            ),
          ],
      'packaging': packaging,
    };

Map<String, dynamic> packagingJson({
  String id = 'PK-0004',
  String no = 'P-0004',
  String status = 'approved',
  bool late = false,
  int total = 450000,
  String supplier = 'الوادي للتغليف',
}) =>
    {
      'id': id,
      'no': no,
      'supplier': supplier,
      'occurredAt': '2026-10-02T09:50:00+03:00',
      'coolerId': 'CL-0014',
      'coolerNo': 14,
      'status': status,
      'itemsCount': 3,
      'incompleteCount': status == 'draft' ? 1 : 0,
      'completeTotalPiasters': total,
      'paidPiasters': 0,
      'remainingPiasters': status == 'approved' ? total : 0,
      'late': late,
      'version': 1,
    };

/// خادم وهمي جاهز لشاشات البرادات: المزارعون، تفاصيل البراد 14، وحفظ الشراء.
FakeBackendApi coolersApi() {
  final api = FakeBackendApi();
  api.handlers['farmers.list'] = (_) => {'farmers': farmersJson()};
  api.handlers['coolers.get'] = (p) => coolerDetailJson(
        cooler: (sampleCoolersJson().where((c) => c['id'] == p['id']).firstOrNull) ?? cooler14Json(),
      );
  var n = 30;
  api.handlers['purchases.create'] = (p) {
    n++;
    final created = p['newFarmerName'] != null;
    return {
      'purchase': purchaseJson(
        id: 'PU-00$n',
        coolerId: p['coolerId'] as String,
        farmerId: created ? 'FR-0099' : p['farmerId'] as String,
        farmerName: created ? p['newFarmerName'] as String : 'حسن البدري',
        boxes: p['boxes'] as int,
        avg: p['avgWeightGrams'] as int,
        price: p['pricePerKgPiasters'] as int,
      ),
      'payment': null,
      'farmer': created
          ? {'id': 'FR-0099', 'no': 99, 'name': p['newFarmerName'], 'status': 'active', 'version': 1}
          : null,
      'replayed': false,
    };
  };
  return api;
}
