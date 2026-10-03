// أدوات قسم البرادات: حساب الشراء بأعداد صحيحة كما في الخادم (docs/API.md §5)، وتنسيق النصوص العربية.
import '../../core/format/numbers.dart';
import '../../core/models/dashboard.dart';
import '../../core/models/records.dart';
import '../../core/models/user.dart';
import '../../ui/money_text.dart';

// ============================================================================ الحساب (مطابق للخادم)

/// حدود التحقق كما في Purchases.gs (RMN_LIMITS).
abstract final class PurchaseLimits {
  static const boxesMax = 100000;
  static const avgWeightMaxGrams = 60000;
  static const priceMaxPiasters = 100000;
  static const sampleMaxCount = 200;
  static const sampleWeightMaxGrams = 100000;
  static const tareMaxGrams = 60000;
  static const notesMax = 1000;
  static const coolerNameMax = 80;
  static const carNoMax = 30;
  static const driverMax = 80;
  static const reasonMax = 500;
}

/// round_half_up(n / d) لأعداد صحيحة (d > 0)، مثل roundHalfUpDiv_ في الخادم.
int roundHalfUpDiv(int n, int d) {
  if (n < 0) return -roundHalfUpDiv(-n, d);
  final r = n % d;
  final q = n ~/ d;
  return 2 * r >= d ? q + 1 : q;
}

/// الوزن الإجمالي = الصناديق × متوسط الوزن الصافي.
int purchaseWeightGrams(int boxes, int avgWeightGrams) => boxes * avgWeightGrams;

/// القيمة = round_half_up(الوزن × سعر الكيلو / 1000) بالقرش.
int purchaseValuePiasters(int weightGrams, int pricePerKgPiasters) =>
    roundHalfUpDiv(weightGrams * pricePerKgPiasters, 1000);

/// متوسط الوزن الصافي من العينة = round(mean(sample) − الفارغ) بالجرام، مثل sampleNetAverage_ في الخادم.
int sampleNetAverageGrams(List<int> samples, int tareGrams) {
  if (samples.isEmpty) return 0;
  final sum = samples.fold<int>(0, (a, b) => a + b);
  return roundHalfUpDiv(sum - tareGrams * samples.length, samples.length);
}

/// متوسط سعر الكيلو المرجّح = round_half_up(القيمة × 1000 / الوزن).
int avgPricePerKgPiasters(int valuePiasters, int weightGrams) =>
    weightGrams > 0 ? roundHalfUpDiv(valuePiasters * 1000, weightGrams) : 0;

// ============================================================================ قراءة المدخلات

/// نتيجة قراءة حقل رقمي: قيمة صحيحة بالوحدة الصغرى، أو خطأ.
class ParsedNumber {
  const ParsedNumber.empty()
      : value = null,
        empty = true,
        invalid = false,
        tooManyDecimals = false;
  const ParsedNumber.ok(int this.value)
      : empty = false,
        invalid = false,
        tooManyDecimals = false;
  const ParsedNumber.invalid({this.tooManyDecimals = false})
      : value = null,
        empty = false,
        invalid = true;

  final int? value;
  final bool empty;
  final bool invalid;
  final bool tooManyDecimals;
}

/// يقرأ نصًا بأرقام عربية أو لاتينية إلى عدد صحيح × 10^[scale]، ويرفض المنازل الزائدة بدل تقريبها خفية.
ParsedNumber parseAmount(String text, int scale) {
  final t = text.trim();
  if (t.isEmpty) return const ParsedNumber.empty();
  final normalized = normalizeDigits(t);
  final dot = normalized.indexOf('.');
  if (dot >= 0 && normalized.length - dot - 1 > scale) return const ParsedNumber.invalid(tooManyDecimals: true);
  final v = parseToMinor(t, scale);
  if (v == null) return const ParsedNumber.invalid();
  return ParsedNumber.ok(v);
}

// ============================================================================ النصوص

/// «عملية واحدة»، «عمليتان»، «3 عمليات»، «11 عملية».
String operationsLabel(int n) {
  if (n == 0) return 'لا عمليات';
  if (n == 1) return 'عملية واحدة';
  if (n == 2) return 'عمليتان';
  final mod = n % 100;
  if (mod >= 3 && mod <= 10) return '${formatCount(n)} عمليات';
  return '${formatCount(n)} عملية';
}

/// «عملية واحدة بانتظار المزامنة»، «3 عمليات بانتظار المزامنة».
String pendingLabel(int n) => '${operationsLabel(n)} بانتظار المزامنة';

/// «مزارع واحد»، «مزارعان»، «3 مزارعين»، «11 مزارعًا».
String farmersLabel(int n) {
  if (n == 0) return 'لا مزارعين';
  if (n == 1) return 'مزارع واحد';
  if (n == 2) return 'مزارعان';
  final mod = n % 100;
  if (mod >= 3 && mod <= 10) return '${formatCount(n)} مزارعين';
  return '${formatCount(n)} مزارعًا';
}

/// وزن بالكيلو حتى 3 منازل دون أصفار زائدة: 11000 ← «11»، 10625 ← «10.625».
String kgExact(int grams) => formatWeight(grams, decimals: 3);

/// وزن مختصر بمنزلة واحدة كما في لوحة التحكم.
String kgShort(int grams) => formatWeight(grams);

/// قيمة حقل وزن معدّة للتحرير (دون فواصل آلاف): 1900 ← «1.9».
String kgInput(int grams) => formatMinor(grams, 3, trimZeros: true).replaceAll(',', '');

/// قيمة حقل مبلغ معدّة للتحرير: 1500 ← «15»، 1475 ← «14.75».
String moneyInput(int piasters) {
  final s = formatMinor(piasters, 2).replaceAll(',', '');
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// «اليوم 06:40 ص» أو «أمس 04:12 م» أو «2 أكتوبر · 06:40 ص». الوقت كما أرسله الخادم بتوقيت العمل.
String whenText(String? iso, {DateTime? now}) {
  if (iso == null || iso.length < 16) return '';
  final today = now ?? DateTime.now();
  final date = iso.substring(0, 10);
  final time = formatLocalTimestamp(iso, withDate: false);
  if (date == _ymd(today)) return 'اليوم\u00A0$time';
  if (date == _ymd(today.subtract(const Duration(days: 1)))) return 'أمس\u00A0$time';
  return '${formatArabicDate(iso, withYear: date.substring(0, 4) != today.year.toString())} · $time';
}

/// «فُتح اليوم 06:40 ص · محمد الحسناوي»
String openedLine(CoolerSummary c) {
  final when = whenText(c.openedAt);
  if (when.isEmpty && c.openedBy == null) return '';
  return [
    if (when.isNotEmpty) 'فُتح $when' else 'فُتح',
    if (c.openedBy != null) c.openedBy!,
  ].join(' · ');
}

/// «قُفّل 30 سبتمبر · 05:30 م · كريم عبد الله» (فارغ لبراد مفتوح لم يُقفَّل).
String closedLine(CoolerSummary c) {
  if (c.isOpen) return '';
  final when = whenText(c.closedAt);
  return [
    if (when.isNotEmpty) 'قُفّل $when' else 'مقفّل',
    if (c.closedBy != null) c.closedBy!,
  ].join(' · ');
}

/// «ن ق ر 7316 · سامي عطية»
String vehicleLine(CoolerSummary c) => [if (c.carNo != null) c.carNo!, if (c.driver != null) c.driver!].join(' · ');

// ============================================================================ الصلاحيات

/// صلاحيات المستخدم الحالي («مشاهدة فقط» إن لم يوجد مستخدم).
UserPermissions permissionsOf(AppUser? user) => user?.permissions ?? const UserPermissions();

/// هل أنشأ [user] العملية؟ بالبريد إن أرسله الخادم، وإلا بالاسم.
bool isOwnPurchase(Purchase p, AppUser? user) {
  if (user == null) return false;
  final email = p.createdByEmail;
  if (email != null && email.isNotEmpty) return email.trim().toLowerCase() == user.email.trim().toLowerCase();
  return p.createdBy != null && p.createdBy!.trim() == user.name.trim();
}

/// تعديل العملية أو إلغاؤها: البراد مفتوح، العملية فعّالة، وصلاحية التسجيل (+ تعديل عمليات الآخرين لغير صاحبها).
bool canChangePurchase(Purchase p, {required bool coolerOpen, required AppUser? user}) {
  final perms = permissionsOf(user);
  if (!coolerOpen || !p.active || !perms.recordPurchases) return false;
  return isOwnPurchase(p, user) || perms.editOthers;
}

/// تسجيل دفعة على العملية: مسموح حتى في البراد المقفّل.
bool canPayPurchase(Purchase p, {required AppUser? user}) =>
    p.active && p.remainingPiasters > 0 && permissionsOf(user).recordPayments;

// ============================================================================ أسماء المزارعين

const _diacritics = '[\u064B-\u0670\u065F\u0640\u200B-\u200F\u202A-\u202E]';

/// تطبيع الاسم كما في normText_ بالخادم: بلا تشكيل، الألف والياء والتاء المربوطة موحّدة.
String normalizeName(String s) => normalizeDigits(s)
    .replaceAll(RegExp(_diacritics), '')
    .replaceAll(RegExp('[آأإٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

int _editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final del = prev[j] + 1;
      final ins = cur[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      cur[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// تطابق تام بعد التطبيع (الخادم يرفض إضافة مزارع جديد بالاسم نفسه).
bool sameName(String a, String b) {
  final na = normalizeName(a);
  return na.isNotEmpty && na == normalizeName(b);
}

/// أسماء قريبة قد تكون للشخص نفسه: احتواء، أو كلمة مشتركة (3 أحرف فأكثر)، أو اختلاف حرف أو حرفين.
bool similarName(String a, String b) {
  final na = normalizeName(a);
  final nb = normalizeName(b);
  if (na.isEmpty || nb.isEmpty) return false;
  if (na == nb) return true;
  if (na.length >= 3 && nb.contains(na)) return true;
  if (nb.length >= 3 && na.contains(nb)) return true;
  final ta = na.split(' ').where((t) => t.length >= 3 && t != 'عبد' && t != 'ابو').toSet();
  final tb = nb.split(' ').where((t) => t.length >= 3 && t != 'عبد' && t != 'ابو').toSet();
  if (ta.intersection(tb).isNotEmpty) return true;
  if (na.length >= 5 && nb.length >= 5 && _editDistance(na, nb) <= 2) return true;
  return false;
}

/// مزارعون يطابقون نص البحث (الاسم أو الرقم أو القرية)، الأقرب أولًا.
List<Farmer> searchFarmers(List<Farmer> farmers, String query, {int limit = 6}) {
  final q = normalizeName(query);
  if (q.isEmpty) return const [];
  final starts = <Farmer>[];
  final contains = <Farmer>[];
  for (final f in farmers) {
    final name = normalizeName(f.name);
    if (name.startsWith(q) || f.no.toString() == q) {
      starts.add(f);
    } else if (name.contains(q) || normalizeName(f.village ?? '').contains(q)) {
      contains.add(f);
    }
  }
  return [...starts, ...contains].take(limit).toList();
}
