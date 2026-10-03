/// التقارير: البناء من السجلات (دوال نقية)، النموذج المحايد ReportDocument، التحميل من الخادم، والتصدير
/// (PDF عربي، CSV، طباعة، مشاركة). شاشات features/reports تستورد هذا الملف فقط.
library;

export 'cooler_report.dart';
export 'farmer_statement.dart';
export 'period_report.dart';
export 'report_actions.dart';
export 'report_csv.dart';
export 'report_document.dart';
export 'report_format.dart'
    show compareByTime, dateKey, dateRangeText, inDateRange, plainMinor, roundHalfUpDiv, weightedAvgPricePerKg;
export 'report_loader.dart';
export 'report_pdf.dart';
export 'report_totals.dart';
export 'supplier_report.dart';
