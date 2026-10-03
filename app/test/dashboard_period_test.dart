import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/demo_backend_api.dart';
import 'package:rumman_calculator/features/dashboard/dashboard_format.dart';

void main() {
  late DemoBackendApi api;

  setUp(() async {
    api = DemoBackendApi(latency: Duration.zero, clock: () => DateTime(2026, 10, 2, 10, 58));
    api.session = (await api.login('anything')).session;
  });

  test('F7: فترة week تُسمّى «آخر 7 أيام» كما يحسبها الخادم (اليوم و6 أيام قبله)، لا «هذا الأسبوع»', () async {
    expect(periodLabel('week'), 'آخر 7 أيام');
    expect(periodSummaryTitle('week'), 'ملخص آخر 7 أيام');
    expect(dashboardPeriods.map((p) => p.$2), isNot(contains('هذا الأسبوع')));
    final d = await api.dashboard(period: 'week');
    // التسمية المحلية (قبل وصول البيانات) هي نفسها تسمية الخادم.
    expect(d.period.label, periodLabel('week'));
    expect(d.period.from, startsWith('2026-09-26'));
    expect(d.period.to, startsWith('2026-10-02'));
  });

  test('F2: المتبقي في الوضع التجريبي = متبقي عمليات الفترة، ولا يكون سالبًا في أي فترة', () async {
    for (final period in const ['season', 'today', 'week', 'month', 'all']) {
      final k = (await api.dashboard(period: period)).kpis;
      expect(k.remainingFarmersPiasters, greaterThanOrEqualTo(0), reason: period);
      expect(k.remainingSuppliersPiasters, greaterThanOrEqualTo(0), reason: period);
      expect(k.remainingPiasters, k.remainingFarmersPiasters + k.remainingSuppliersPiasters, reason: period);
    }
    final all = (await api.dashboard(period: 'all')).kpis;
    expect(all.remainingPiasters, all.purchaseValuePiasters + all.packagingApprovedPiasters - all.paidPiasters);
  });
}
