import 'package:rumman_calculator/core/models/dashboard.dart';
import 'package:rumman_calculator/core/models/sheet_status.dart';
import 'package:rumman_calculator/core/models/user.dart';

/// بيانات الاختبار بصيغة docs/API.md، مطابقة لأرقام التصميم المعتمد (البراد 14 · شحنة دمياط).

UserPermissions permissionsForRole(UserRole role, {Map<String, bool> entry = const {}}) => switch (role) {
      UserRole.admin => const UserPermissions(
          addFarmers: true,
          recordPurchases: true,
          editOthers: true,
          recordPayments: true,
          packaging: true,
          closeCoolers: true,
          reopenCoolers: true,
          manageUsers: true,
          manageSettings: true,
        ),
      UserRole.viewer => const UserPermissions(),
      UserRole.entry => UserPermissions(
          addFarmers: entry['addFarmers'] ?? true,
          recordPurchases: entry['recordPurchases'] ?? true,
          editOthers: entry['editOthers'] ?? false,
          recordPayments: entry['recordPayments'] ?? true,
          packaging: entry['packaging'] ?? true,
          closeCoolers: entry['closeCoolers'] ?? false,
        ),
    };

AppUser makeUser(
  String id,
  String email,
  String name,
  UserRole role, {
  bool active = true,
  int version = 1,
  bool isBootstrap = false,
  Map<String, bool> entry = const {},
}) =>
    AppUser(
      id: id,
      email: email,
      name: name,
      role: role,
      active: active,
      permissions: permissionsForRole(role, entry: entry),
      version: version,
      isBootstrap: isBootstrap,
    );

AppUser sampleAdmin() =>
    makeUser('US-0001', 'hasnawi.owner@gmail.com', 'محمد الحسناوي', UserRole.admin, version: 3, isBootstrap: true);

AppUser sampleEntry({Map<String, bool> entry = const {'closeCoolers': true}}) =>
    makeUser('US-0002', 'karim.abdallah.eg@gmail.com', 'كريم عبد الله', UserRole.entry, version: 5, entry: entry);

AppUser sampleViewer() => makeUser('US-0004', 'salma.fouad.acc@gmail.com', 'سلمى فؤاد', UserRole.viewer);

List<AppUser> sampleUsers() => [
      sampleAdmin(),
      sampleEntry(),
      makeUser('US-0003', 'youssef.nasser.farm@gmail.com', 'يوسف ناصر', UserRole.entry, version: 2),
      sampleViewer(),
      makeUser('US-0005', 'ahmed.samir.weigh@gmail.com', 'أحمد سمير', UserRole.entry, active: false, version: 4),
    ];

Map<String, dynamic> cooler14Json() => {
      'id': 'CL-0014',
      'no': 14,
      'name': 'شحنة دمياط',
      'status': 'open',
      'carNo': 'ن ق ر 7316',
      'driver': 'سامي عطية',
      'notes': '',
      'openedAt': '2026-10-02T06:40:00+03:00',
      'openedBy': 'محمد الحسناوي',
      'closedAt': null,
      'closedBy': null,
      'farmers': 5,
      'purchases': 6,
      'boxes': 249,
      'weightGrams': 2718200,
      'valuePiasters': 4083940,
      'paidPiasters': 2331400,
      'remainingPiasters': 1752540,
      'packagingApprovedPiasters': 450000,
      'packagingLatePiasters': 0,
      'totalCostPiasters': 4533940,
      'avgPricePerKgPiasters': 1502,
      'version': 1,
      'closeSnapshot': null,
    };

Map<String, dynamic> cooler13Json() => {
      ...cooler14Json(),
      'id': 'CL-0013',
      'no': 13,
      'name': 'شحنة الإسكندرية',
      'carNo': 'س د م 2194',
      'driver': 'خالد فرج',
      'openedAt': '2026-10-01T15:20:00+03:00',
      'farmers': 3,
      'purchases': 3,
      'boxes': 112,
      'weightGrams': 1215200,
      'valuePiasters': 1831200,
      'paidPiasters': 1000000,
      'remainingPiasters': 831200,
    };

Map<String, dynamic> cooler12Json() => {
      ...cooler14Json(),
      'id': 'CL-0012',
      'no': 12,
      'name': 'شحنة بورسعيد',
      'status': 'closed',
      'closedAt': '2026-09-30T17:30:00+03:00',
      'closedBy': 'كريم عبد الله',
    };

List<Map<String, dynamic>> sampleCoolersJson() => [cooler14Json(), cooler13Json(), cooler12Json()];

Map<String, dynamic> sampleDashboardJson() => {
      'period': {
        'key': 'season',
        'label': 'هذا الموسم',
        'from': '2026-08-01T00:00:00+03:00',
        'to': '2026-10-02T23:59:59+03:00',
      },
      'empty': false,
      'kpis': {
        'closedCoolers': 12,
        'openCoolers': 2,
        'distinctFarmers': 37,
        'purchases': 168,
        'boxes': 7142,
        'weightGrams': 78315600,
        'purchaseValuePiasters': 117648240,
        'packagingApprovedPiasters': 11264000,
        'paidPiasters': 115190400,
        'remainingPiasters': 13721840,
        'remainingFarmersPiasters': 12221840,
        'remainingSuppliersPiasters': 1500000,
        'avgPricePerKgPiasters': 1502,
      },
      'currentCooler': cooler14Json(),
      'openCoolers': [cooler14Json(), cooler13Json()],
      'recent': [
        {
          'type': 'purchase', 'id': 'PU-0023', 'title': 'حسن البدري', 'subtitle': 'شراء · براد 14 · محمد',
          'coolerNo': 14, 'at': '2026-10-02T10:42:00+03:00', 'amountPiasters': 441000,
          'status': 'partial', 'statusLabel': 'جزئي',
        },
        {
          'type': 'purchase', 'id': 'PU-0022', 'title': 'عبد الرحمن الشافعي', 'subtitle': 'شراء · براد 14 · يوسف',
          'coolerNo': 14, 'at': '2026-10-02T10:15:00+03:00', 'amountPiasters': 806400,
          'status': 'paid', 'statusLabel': 'مدفوع',
        },
        {
          'type': 'packaging', 'id': 'PK-0004', 'title': 'الوادي للتغليف', 'subtitle': 'تعبئة · براد 14 · كريم',
          'coolerNo': 14, 'at': '2026-10-02T09:50:00+03:00', 'amountPiasters': 258000,
          'status': 'draft', 'statusLabel': 'مسودة',
        },
        {
          'type': 'purchase', 'id': 'PU-0021', 'title': 'الحاج محمود عبد العال', 'subtitle': 'شراء · براد 14 · كريم',
          'coolerNo': 14, 'at': '2026-10-02T09:31:00+03:00', 'amountPiasters': 356400,
          'status': 'unpaid', 'statusLabel': 'غير مدفوع',
        },
        {
          'type': 'payment', 'id': 'PY-0021', 'title': 'سعيد أبو زيد', 'subtitle': 'دفعة · براد 14 · كريم',
          'coolerNo': 14, 'at': '2026-10-02T09:05:00+03:00', 'amountPiasters': 500000,
          'status': 'active', 'statusLabel': 'فعّالة',
        },
        {
          'type': 'purchase', 'id': 'PU-0019', 'title': 'رمضان حسانين', 'subtitle': 'شراء · براد 13 · يوسف',
          'coolerNo': 13, 'at': '2026-10-01T16:30:00+03:00', 'amountPiasters': 671460,
          'status': 'cancelled', 'statusLabel': 'ملغاة',
        },
      ],
    };

DashboardData sampleDashboard() => DashboardData.fromJson(sampleDashboardJson());

/// لا برادات ولا عمليات على الإطلاق.
DashboardData emptyDashboard() => DashboardData.fromJson({
      'period': {'key': 'season', 'label': 'هذا الموسم', 'from': '2026-08-01T00:00:00+03:00', 'to': '2026-10-02T23:59:59+03:00'},
      'empty': true,
      'kpis': <String, dynamic>{},
      'currentCooler': null,
      'openCoolers': <dynamic>[],
      'recent': <dynamic>[],
    });

const sampleSpreadsheetId = '1hX9tQ2mB7rLk4ZpW8sN3yV6cJ0dF5gH9aE2uR7vQe4';

Map<String, dynamic> _sheet(String key, String title, int rows, {bool exists = true, List<String> missing = const []}) => {
      'key': key,
      'title': title,
      'exists': exists,
      'rows': rows,
      'missingColumns': missing,
      'extraColumns': <String>[],
    };

Map<String, dynamic> sampleSheetStatusJson({bool repaired = false}) => {
      'configured': true,
      'spreadsheetId': sampleSpreadsheetId,
      'title': 'حاسبة الرمان — موسم 2026',
      'url': 'https://docs.google.com/spreadsheets/d/$sampleSpreadsheetId/edit',
      'connectedAs': 'hasnawi.owner@gmail.com',
      'timezone': 'Africa/Cairo',
      'ok': repaired,
      'sheets': [
        _sheet('coolers', 'البرادات', 14),
        _sheet('farmers', 'المزارعون', 13),
        _sheet('purchases', 'مشتريات الرمان', 23),
        _sheet('packaging', 'مشتريات التعبئة', 4, missing: repaired ? const [] : const ['رقم الفاتورة']),
        _sheet('payments', 'المدفوعات', 22),
        _sheet('users', 'المستخدمون', 5),
        _sheet('audit', 'سجل التعديلات', repaired ? 1 : 0, exists: repaired),
      ],
      'lastWriteAt': '2026-10-02T10:44:00+03:00',
      'lastError': {
        'at': '2026-10-01T16:12:00+03:00',
        'message': 'تعذّرت الكتابة لأن خدمة Google لم تستجب في الوقت المحدد. أُعيدت المحاولة تلقائيًا ونجحت دون تكرار.',
      },
      'checkedAt': '2026-10-02T10:57:00+03:00',
    };

SheetStatus sampleSheetStatus() => SheetStatus.fromJson(sampleSheetStatusJson());

SheetStatus repairedSheetStatus() => SheetStatus.fromJson(sampleSheetStatusJson(repaired: true));

const connectWarning = 'البيانات القديمة لا تُنقل تلقائيًا إلى الملف الجديد. المستخدمون والبرادات والعمليات المسجلة في الملف السابق تبقى فيه.';

SheetStatus connectedSheetStatus(String spreadsheet) => SheetStatus.fromJson({
      ...sampleSheetStatusJson(repaired: true),
      'spreadsheetId': 'NEWfileID_abcdefghijklmnop0123',
      'title': 'ملف الموسم الجديد',
      'url': spreadsheet,
      'warning': connectWarning,
    });
