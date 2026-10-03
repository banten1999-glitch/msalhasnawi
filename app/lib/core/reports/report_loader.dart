/// جلب ما يحتاجه كل تقرير من الخادم عبر BackendApi (قراءات فقط، صلاحية viewData)، ثم بناء التقرير.
library;

import '../api/api_exception.dart';
import '../api/backend_api.dart';
import '../models/dashboard.dart';
import '../models/records.dart';
import '../models/settings.dart';
import 'cooler_report.dart';
import 'farmer_statement.dart';
import 'period_report.dart';
import 'report_format.dart';
import 'supplier_report.dart';

/// يحمّل بيانات التقارير. كل الدوال ترمي [ApiException] عند فشل الخادم أو الاتصال.
///
/// ```dart
/// final loader = ReportLoader(AppScope.of(context).api);
/// final report = await loader.coolerReport('CL-0014');
/// final pdf = await buildReportPdf(report.toDocument(), businessName: (await loader.settings()).businessName);
/// ```
class ReportLoader {
  ReportLoader(this.api, {this.parallelRequests = 4});

  final BackendApi api;

  /// أقصى عدد طلبات packaging.get المتزامنة (لأصناف مشتريات التعبئة المعتمدة).
  final int parallelRequests;

  Future<BusinessSettings>? _settings;

  /// إعدادات العمل (اسم النشاط للرأس، ورمز العملة). تُجلب مرة واحدة لكل [ReportLoader].
  Future<BusinessSettings> settings() => _settings ??= api.settings().catchError((Object e) {
        _settings = null;
        throw e;
      });

  Future<String> _currency() async {
    try {
      final symbol = (await settings()).currencySymbol.trim();
      return symbol.isEmpty ? 'ج.م' : symbol;
    } on ApiException {
      // الإعدادات للعرض فقط: لا نُفشل التقرير بسببها.
      return 'ج.م';
    }
  }

  /// تقرير البراد: coolers.get + payments.list(coolerId) + packaging.get لكل شراء تعبئة معتمد مرتبط به.
  Future<CoolerReport> coolerReport(String coolerId) async {
    final r = await _all([api.getCooler(coolerId), api.listPayments(coolerId: coolerId), _currency()]);
    final detail = r[0] as CoolerDetail;
    final approved = [for (final p in detail.packaging) if (p.status == PackagingStatus.approved) p.id];
    return CoolerReport.build(
      detail: detail,
      payments: r[1] as List<Payment>,
      packagingDetails: await _packagingDetails(approved),
      currency: r[2] as String,
    );
  }

  /// كشف حساب المزارع: farmers.list (للبيانات) + purchases.list(farmerId، الفترة، مع الملغاة) +
  /// payments.list(payeeId). [from]/[to] شاملان بتاريخ العمل.
  Future<FarmerStatement> farmerStatement(String farmerId, {DateTime? from, DateTime? to}) async {
    final r = await _all([
      api.listFarmers(includeInactive: true),
      api.listPurchases(
        farmerId: farmerId,
        from: from == null ? null : dateKey(from),
        to: to == null ? null : dateKey(to),
        includeCancelled: true,
      ),
      api.listPayments(payeeId: farmerId),
      _currency(),
    ]);
    final farmer = (r[0] as List<Farmer>).where((f) => f.id == farmerId).firstOrNull;
    if (farmer == null) {
      throw const ApiException(
        ApiErrorCode.notFound,
        'المزارع غير موجود. ربما حُذف من الملف؛ حدّث القائمة وأعد المحاولة.',
      );
    }
    return FarmerStatement.build(
      farmer: farmer,
      purchases: r[1] as List<Purchase>,
      payments: r[2] as List<Payment>,
      from: from,
      to: to,
      currency: r[3] as String,
    );
  }

  /// تقرير الموردين (أو مورد واحد): packaging.list + packaging.get لكل شراء معتمد في النطاق (للأصناف).
  /// [includeItems] = false يتخطى الأصناف (أسرع مع مشتريات كثيرة).
  Future<SupplierReport> supplierReport({
    String? supplier,
    DateTime? from,
    DateTime? to,
    bool includeItems = true,
  }) async {
    final r = await _all([api.listPackaging(), _currency()]);
    final all = r[0] as List<PackagingSummary>;
    // البناء يطبق المرشحات نفسها؛ نبنيه أولًا لنعرف المشتريات المعتمدة التي تحتاج أصنافها فقط.
    final scoped = SupplierReport.build(packaging: all, supplier: supplier, from: from, to: to);
    final approved = [
      for (final g in scoped.groups)
        for (final p in g.approved) p.id,
    ];
    final details = includeItems ? await _packagingDetails(approved) : const <PackagingDetail>[];
    return SupplierReport.build(
      packaging: all,
      details: details,
      supplier: supplier,
      from: from,
      to: to,
      currency: r[1] as String,
    );
  }

  /// أسماء الموردين المسجلة (لاختيار مورد في الواجهة)، مرتبة ودون تكرار.
  Future<List<String>> suppliers() async {
    final all = await api.listPackaging();
    final byKey = <String, String>{};
    for (final p in all) {
      final name = p.supplier?.trim() ?? '';
      if (name.isEmpty) continue;
      byKey.putIfAbsent(name.replaceAll(RegExp(r'\s+'), ' ').toLowerCase(), () => name);
    }
    return byKey.values.toList()..sort();
  }

  /// تقرير الفترة: purchases.list(الفترة، مع الملغاة) + payments.list() + packaging.list() + coolers.list(all).
  Future<PeriodReport> periodReport({DateTime? from, DateTime? to}) async {
    final r = await _all([
      api.listPurchases(
        from: from == null ? null : dateKey(from),
        to: to == null ? null : dateKey(to),
        includeCancelled: true,
      ),
      api.listPayments(),
      api.listPackaging(),
      api.listCoolers(status: 'all'),
      _currency(),
    ]);
    return PeriodReport.build(
      from: from,
      to: to,
      purchases: r[0] as List<Purchase>,
      payments: r[1] as List<Payment>,
      packaging: r[2] as List<PackagingSummary>,
      coolers: r[3] as List<CoolerSummary>,
      currency: r[4] as String,
    );
  }

  /// ينتظر الطلبات المتوازية معًا ويرمي أول خطأ كما هو (ApiException)، دون أخطاء غير معالجة من البقية.
  static Future<List<Object>> _all(List<Future<Object>> futures) => Future.wait(futures, eagerError: true);

  /// packaging.get لكل معرّف، بحد أقصى [parallelRequests] طلبات في الوقت نفسه، بالترتيب نفسه.
  Future<List<PackagingDetail>> _packagingDetails(List<String> ids) async {
    final out = <PackagingDetail>[];
    final step = parallelRequests < 1 ? 1 : parallelRequests;
    for (var i = 0; i < ids.length; i += step) {
      final batch = ids.sublist(i, i + step > ids.length ? ids.length : i + step);
      out.addAll(await Future.wait([for (final id in batch) api.getPackaging(id)]));
    }
    return out;
  }
}
