import 'package:flutter/material.dart';

import '../core/models/dashboard.dart';
import '../core/models/records.dart';
import '../features/coolers/close_cooler_screen.dart';
import '../features/coolers/cooler_details_screen.dart';
import '../features/coolers/create_cooler_sheet.dart';
import '../features/coolers/purchase_form_screen.dart';
import '../features/farmers/farmer_edit_sheet.dart';
import '../features/packaging/packaging_editor_screen.dart';
import '../features/payments/record_payment_screen.dart';
import '../features/reports/cooler_report_screen.dart';
import '../features/reports/farmer_statement_screen.dart';
import '../features/sync/pending_sync_screen.dart';

/// نقاط الدخول المشتركة بين الأقسام. كل شاشة تفتح شاشة قسم آخر من هنا فقط، فلا تعتمد الأقسام على
/// تفاصيل بعضها. الشاشات المفتوحة تحفظ بنفسها وتستدعي `AppScope.of(context).changes.bump()` بعد الحفظ.
abstract final class AppRoutes {
  static Future<T?> _push<T>(BuildContext context, Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));

  // ---------------------------------------------------------------- البرادات وشراء الرمان

  static Future<void> openCooler(BuildContext context, String coolerId) =>
      _push<void>(context, CoolerDetailsScreen(coolerId: coolerId));

  /// يعيد البراد الجديد أو null إن أُلغي.
  static Future<CoolerSummary?> createCooler(BuildContext context) => showCreateCoolerSheet(context);

  /// [coolerId] == null ⇒ البراد المفتوح الحالي (أو اختيار براد).
  static Future<void> addPurchase(BuildContext context, {String? coolerId}) =>
      _push<void>(context, PurchaseFormScreen(coolerId: coolerId));

  static Future<void> editPurchase(BuildContext context, Purchase purchase) =>
      _push<void>(context, PurchaseFormScreen(coolerId: purchase.coolerId, purchase: purchase));

  static Future<void> closeCooler(BuildContext context, String coolerId) =>
      _push<void>(context, CloseCoolerScreen(coolerId: coolerId));

  // ---------------------------------------------------------------- المزارعون

  /// يعيد المزارع المحفوظ أو null.
  static Future<Farmer?> editFarmer(BuildContext context, {Farmer? farmer, String? initialName}) =>
      showFarmerEditSheet(context, farmer: farmer, initialName: initialName);

  static Future<void> openFarmerStatement(BuildContext context, String farmerId) =>
      _push<void>(context, FarmerStatementScreen(farmerId: farmerId));

  // ---------------------------------------------------------------- التعبئة والمدفوعات

  /// [packagingId] == null ⇒ مسودة جديدة.
  static Future<void> openPackaging(BuildContext context, {String? packagingId, String? coolerId}) =>
      _push<void>(context, PackagingEditorScreen(packagingId: packagingId, coolerId: coolerId));

  static Future<void> recordPayment(BuildContext context, {PaymentTarget? targetType, String? targetId}) =>
      _push<void>(context, RecordPaymentScreen(targetType: targetType, targetId: targetId));

  // ---------------------------------------------------------------- التقارير والمزامنة

  static Future<void> openCoolerReport(BuildContext context, {String? coolerId}) =>
      _push<void>(context, CoolerReportScreen(coolerId: coolerId));

  static Future<void> openPendingSync(BuildContext context) => _push<void>(context, const PendingSyncScreen());
}
