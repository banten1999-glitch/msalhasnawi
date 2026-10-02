int _i(Object? v) => (v as num?)?.toInt() ?? 0;
String? _s(Object? v) => v is String && v.isNotEmpty ? v : null;

class PeriodInfo {
  const PeriodInfo({required this.key, required this.label, this.from, this.to});
  factory PeriodInfo.fromJson(Map<String, dynamic> j) =>
      PeriodInfo(key: j['key'] as String? ?? 'season', label: j['label'] as String? ?? '', from: _s(j['from']), to: _s(j['to']));

  final String key;
  final String label;
  final String? from;
  final String? to;
}

class DashboardKpis {
  const DashboardKpis({
    this.closedCoolers = 0,
    this.openCoolers = 0,
    this.distinctFarmers = 0,
    this.purchases = 0,
    this.boxes = 0,
    this.weightGrams = 0,
    this.purchaseValuePiasters = 0,
    this.packagingApprovedPiasters = 0,
    this.paidPiasters = 0,
    this.remainingPiasters = 0,
    this.remainingFarmersPiasters = 0,
    this.remainingSuppliersPiasters = 0,
    this.avgPricePerKgPiasters = 0,
  });

  factory DashboardKpis.fromJson(Map<String, dynamic> j) => DashboardKpis(
        closedCoolers: _i(j['closedCoolers']),
        openCoolers: _i(j['openCoolers']),
        distinctFarmers: _i(j['distinctFarmers']),
        purchases: _i(j['purchases']),
        boxes: _i(j['boxes']),
        weightGrams: _i(j['weightGrams']),
        purchaseValuePiasters: _i(j['purchaseValuePiasters']),
        packagingApprovedPiasters: _i(j['packagingApprovedPiasters']),
        paidPiasters: _i(j['paidPiasters']),
        remainingPiasters: _i(j['remainingPiasters']),
        remainingFarmersPiasters: _i(j['remainingFarmersPiasters']),
        remainingSuppliersPiasters: _i(j['remainingSuppliersPiasters']),
        avgPricePerKgPiasters: _i(j['avgPricePerKgPiasters']),
      );

  final int closedCoolers;
  final int openCoolers;
  final int distinctFarmers;
  final int purchases;
  final int boxes;
  final int weightGrams;
  final int purchaseValuePiasters;
  final int packagingApprovedPiasters;
  final int paidPiasters;
  final int remainingPiasters;
  final int remainingFarmersPiasters;
  final int remainingSuppliersPiasters;
  final int avgPricePerKgPiasters;
}

class CoolerSummary {
  const CoolerSummary({
    required this.id,
    required this.no,
    required this.name,
    required this.isOpen,
    this.carNo,
    this.driver,
    this.notes,
    this.openedAt,
    this.openedBy,
    this.closedAt,
    this.closedBy,
    this.farmers = 0,
    this.purchases = 0,
    this.boxes = 0,
    this.weightGrams = 0,
    this.valuePiasters = 0,
    this.paidPiasters = 0,
    this.remainingPiasters = 0,
    this.packagingApprovedPiasters = 0,
    this.packagingLatePiasters = 0,
    this.totalCostPiasters = 0,
    this.avgPricePerKgPiasters = 0,
    this.version = 1,
  });

  factory CoolerSummary.fromJson(Map<String, dynamic> j) => CoolerSummary(
        id: j['id'] as String,
        no: _i(j['no']),
        name: j['name'] as String? ?? '',
        isOpen: j['status'] == 'open',
        carNo: _s(j['carNo']),
        driver: _s(j['driver']),
        notes: _s(j['notes']),
        openedAt: _s(j['openedAt']),
        openedBy: _s(j['openedBy']),
        closedAt: _s(j['closedAt']),
        closedBy: _s(j['closedBy']),
        farmers: _i(j['farmers']),
        purchases: _i(j['purchases']),
        boxes: _i(j['boxes']),
        weightGrams: _i(j['weightGrams']),
        valuePiasters: _i(j['valuePiasters']),
        paidPiasters: _i(j['paidPiasters']),
        remainingPiasters: _i(j['remainingPiasters']),
        packagingApprovedPiasters: _i(j['packagingApprovedPiasters']),
        packagingLatePiasters: _i(j['packagingLatePiasters']),
        totalCostPiasters: _i(j['totalCostPiasters']),
        avgPricePerKgPiasters: _i(j['avgPricePerKgPiasters']),
        version: _i(j['version']) == 0 ? 1 : _i(j['version']),
      );

  final String id;
  final int no;
  final String name;
  final bool isOpen;
  final String? carNo;
  final String? driver;
  final String? notes;
  final String? openedAt;
  final String? openedBy;
  final String? closedAt;
  final String? closedBy;
  final int farmers;
  final int purchases;
  final int boxes;
  final int weightGrams;
  final int valuePiasters;
  final int paidPiasters;
  final int remainingPiasters;
  final int packagingApprovedPiasters;
  final int packagingLatePiasters;
  final int totalCostPiasters;
  final int avgPricePerKgPiasters;
  final int version;

  /// «براد 14 · شحنة دمياط»
  String get title => name.isEmpty ? 'براد $no' : 'براد $no · $name';
}

class ActivityItem {
  const ActivityItem({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    this.coolerNo,
    this.at,
    this.amountPiasters = 0,
    this.status = '',
    this.statusLabel = '',
  });

  factory ActivityItem.fromJson(Map<String, dynamic> j) => ActivityItem(
        type: j['type'] as String? ?? 'purchase',
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
        coolerNo: (j['coolerNo'] as num?)?.toInt(),
        at: _s(j['at']),
        amountPiasters: _i(j['amountPiasters']),
        status: j['status'] as String? ?? '',
        statusLabel: j['statusLabel'] as String? ?? '',
      );

  /// purchase | payment | packaging
  final String type;
  final String id;
  final String title;
  final String subtitle;
  final int? coolerNo;
  final String? at;
  final int amountPiasters;

  /// paid | partial | unpaid | draft | approved | cancelled | active
  final String status;
  final String statusLabel;
}

class DashboardData {
  const DashboardData({
    required this.period,
    required this.kpis,
    required this.empty,
    this.currentCooler,
    this.openCoolers = const [],
    this.recent = const [],
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
        period: PeriodInfo.fromJson((j['period'] as Map?)?.cast<String, dynamic>() ?? const {}),
        kpis: DashboardKpis.fromJson((j['kpis'] as Map?)?.cast<String, dynamic>() ?? const {}),
        empty: j['empty'] == true,
        currentCooler: j['currentCooler'] is Map
            ? CoolerSummary.fromJson((j['currentCooler'] as Map).cast<String, dynamic>())
            : null,
        openCoolers: [
          for (final c in (j['openCoolers'] as List?) ?? const []) CoolerSummary.fromJson((c as Map).cast<String, dynamic>()),
        ],
        recent: [
          for (final a in (j['recent'] as List?) ?? const []) ActivityItem.fromJson((a as Map).cast<String, dynamic>()),
        ],
      );

  final PeriodInfo period;
  final DashboardKpis kpis;
  final bool empty;
  final CoolerSummary? currentCooler;
  final List<CoolerSummary> openCoolers;
  final List<ActivityItem> recent;
}
