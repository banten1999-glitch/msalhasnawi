/// حساب وتنسيق مشترك للتقارير: أعداد صحيحة فقط (قرش وجرام)، وتواريخ بتوقيت العمل كما أرسلها الخادم.
library;

/// round_half_up(n ÷ d) بأعداد صحيحة (مثل roundHalfUpDiv_ في الخادم). [d] > 0.
int roundHalfUpDiv(int n, int d) {
  if (n < 0) return -roundHalfUpDiv(-n, d);
  final r = n % d;
  final q = n ~/ d;
  return 2 * r >= d ? q + 1 : q;
}

/// متوسط سعر الكيلو المرجّح بالقرش = Σ القيمة ÷ Σ الوزن (بالكيلو)، كما في الخادم (avgPricePerKg_).
int weightedAvgPricePerKg(int valuePiasters, int weightGrams) =>
    weightGrams > 0 ? roundHalfUpDiv(valuePiasters * 1000, weightGrams) : 0;

/// عدد بوحدة صغرى كنص عشري خام دون فواصل الآلاف (لملف CSV): plainMinor(825000, 2) == '8250.00'.
String plainMinor(int value, int scale) {
  final negative = value < 0;
  final digits = value.abs().toString().padLeft(scale + 1, '0');
  final whole = digits.substring(0, digits.length - scale);
  final frac = digits.substring(digits.length - scale);
  return '${negative ? '-' : ''}$whole${scale == 0 ? '' : '.$frac'}';
}

/// «2026-10-02» من طابع ISO بتوقيت العمل (دون تحويل منطقة)، أو '' إن لم يوجد.
String isoDate(String? iso) => iso != null && iso.length >= 10 ? iso.substring(0, 10) : '';

/// «2026-10-02 06:40» من طابع ISO بتوقيت العمل، أو التاريخ فقط إن لم يكن فيه وقت.
String isoWallClock(String? iso) {
  if (iso == null || iso.length < 10) return '';
  if (iso.length < 16) return iso.substring(0, 10);
  return '${iso.substring(0, 10)} ${iso.substring(11, 16)}';
}

/// «2026-10-02» من تاريخ يختاره المستخدم (يُرسل للخادم ويقارن بتواريخ السجلات).
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// هل يقع تاريخ السجل [iso] (بتوقيت العمل) بين [from] و[to] شاملًا اليومين؟ null = بلا حد.
/// سجل بلا تاريخ لا يقع في أي فترة محددة.
bool inDateRange(String? iso, {DateTime? from, DateTime? to}) {
  if (from == null && to == null) return true;
  final day = isoDate(iso);
  if (day.isEmpty) return false;
  if (from != null && day.compareTo(dateKey(from)) < 0) return false;
  if (to != null && day.compareTo(dateKey(to)) > 0) return false;
  return true;
}

/// «من 2026-09-01 إلى 2026-10-02»، «حتى 2026-10-02»، «كل الفترات».
String dateRangeText(DateTime? from, DateTime? to) {
  if (from == null && to == null) return 'كل الفترات';
  if (from == null) return 'حتى ${dateKey(to!)}';
  if (to == null) return 'من ${dateKey(from)}';
  if (dateKey(from) == dateKey(to)) return dateKey(from);
  return 'من ${dateKey(from)} إلى ${dateKey(to)}';
}

/// جزء صالح داخل اسم ملف: يحذف الرموز الممنوعة في أنظمة الملفات ويستبدل المسافات بشرطة.
String fileSafeName(String s, {String fallback = 'report'}) {
  final cleaned = s.trim().replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '').replaceAll(RegExp(r'\s+'), '-');
  return cleaned.isEmpty ? fallback : cleaned;
}

/// ترتيب تصاعدي بالوقت ثم المعرّف (التقارير تُقرأ من الأقدم إلى الأحدث).
int compareByTime(String? aTime, String aId, String? bTime, String bId) {
  final c = (aTime ?? '').compareTo(bTime ?? '');
  return c != 0 ? c : aId.compareTo(bId);
}
