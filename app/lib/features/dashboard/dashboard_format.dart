import '../../core/format/numbers.dart';
import '../../core/models/dashboard.dart';
import '../../ui/money_text.dart';

/// فترات لوحة التحكم بالترتيب المعروض (docs/API.md §6 dashboard.get).
const dashboardPeriods = <(String, String)>[
  ('season', 'هذا الموسم'),
  ('today', 'اليوم'),
  // الخادم يحسبها آخر 7 أيام حتى اليوم (لا أسبوعًا تقويميًا)، فيُسمّى كما يسميه الخادم.
  ('week', 'آخر 7 أيام'),
  ('month', 'هذا الشهر'),
  ('all', 'الكل'),
];

String periodLabel(String key) =>
    dashboardPeriods.firstWhere((p) => p.$1 == key, orElse: () => dashboardPeriods.first).$2;

/// عنوان قسم المؤشرات حسب الفترة.
String periodSummaryTitle(String key) => switch (key) {
      'today' => 'ملخص اليوم',
      'week' => 'ملخص آخر 7 أيام',
      'month' => 'ملخص هذا الشهر',
      'all' => 'ملخص كل الفترات',
      _ => 'ملخص الموسم',
    };

/// «1 أغسطس – 2 أكتوبر 2026» من حدود الفترة كما أرسلها الخادم.
String periodRangeText(PeriodInfo p) {
  final from = p.from;
  final to = p.to;
  if (from == null && to == null) return 'كل البيانات المسجلة';
  if (from == null) return 'حتى ${formatArabicDate(to)}';
  if (to == null) return 'من ${formatArabicDate(from)}';
  if (from.length >= 10 && to.length >= 10 && from.substring(0, 10) == to.substring(0, 10)) {
    return formatArabicDate(to);
  }
  final sameYear = from.length >= 4 && to.length >= 4 && from.substring(0, 4) == to.substring(0, 4);
  return '${formatArabicDate(from, withYear: !sameYear)} – ${formatArabicDate(to)}';
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// «اليوم 06:40 ص» أو «أمس 04:12 م» أو «2 أكتوبر · 06:40 ص».
///
/// الوقت يُعرض كما أرسله الخادم بتوقيت العمل؛ «اليوم/أمس» تُقارن بتاريخ الجهاز.
String relativeDateTime(String? iso, {DateTime? now}) {
  if (iso == null || iso.length < 16) return '';
  final today = now ?? DateTime.now();
  final date = iso.substring(0, 10);
  final time = formatLocalTimestamp(iso, withDate: false);
  if (date == _ymd(today)) return 'اليوم\u00A0$time';
  if (date == _ymd(today.subtract(const Duration(days: 1)))) return 'أمس\u00A0$time';
  return '${formatArabicDate(iso, withYear: date.substring(0, 4) != today.year.toString())} · $time';
}

/// «اليوم 06:40 ص · ن ق ر 7316 · سامي عطية»
String coolerSubtitle(CoolerSummary c, {DateTime? now}) {
  final parts = <String>[
    if (c.isOpen && c.openedAt != null) 'فُتح ${relativeDateTime(c.openedAt, now: now)}',
    if (!c.isOpen && c.closedAt != null) 'قُفّل ${relativeDateTime(c.closedAt, now: now)}',
    if (c.carNo != null) c.carNo!,
    if (c.driver != null) c.driver!,
  ];
  return parts.join(' · ');
}

/// «2,718.2» بالكيلوغرام.
String kg(int grams) => formatWeight(grams);

/// «عملية واحدة»، «عمليتان»، «3 عمليات»، «11 عملية».
String operationsCount(int n) {
  if (n == 0) return 'لا عمليات';
  if (n == 1) return 'عملية واحدة';
  if (n == 2) return 'عمليتان';
  final mod = n % 100;
  if (mod >= 3 && mod <= 10) return '${formatCount(n)} عمليات';
  return '${formatCount(n)} عملية';
}
