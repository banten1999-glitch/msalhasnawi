/// تنسيق الأرقام وتحويل المدخلات إلى وحدات صحيحة (قرش، جرام) دون أعداد عشرية تقريبية.
library;

const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';
const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

/// يحوّل الأرقام العربية والفارسية إلى لاتينية، و«٫» إلى نقطة، ويحذف فواصل الآلاف والمسافات.
String normalizeDigits(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final a = _arabicDigits.indexOf(ch);
    final p = _persianDigits.indexOf(ch);
    if (a >= 0) {
      out.write(a);
    } else if (p >= 0) {
      out.write(p);
    } else if (ch == '٫') {
      out.write('.');
    } else if (ch == '٬' || ch == ',' || ch == ' ' || ch == ' ') {
      continue;
    } else {
      out.write(ch);
    }
  }
  return out.toString().trim();
}

/// مثل [normalizeDigits] لكنه يُبقي فواصل الآلاف (، و٬ والمسافات الداخلية تصبح «,») حتى يُتحقق من موضعها.
String _normalizeKeepingGroups(String input) {
  final out = StringBuffer();
  for (final rune in input.trim().runes) {
    final ch = String.fromCharCode(rune);
    final a = _arabicDigits.indexOf(ch);
    final p = _persianDigits.indexOf(ch);
    if (a >= 0) {
      out.write(a);
    } else if (p >= 0) {
      out.write(p);
    } else if (ch == '٫') {
      out.write('.');
    } else if (ch == '٬' || ch == ',' || ch == ' ' || ch == '\u00A0' || ch == '\u202F') {
      out.write(',');
    } else {
      out.write(ch);
    }
  }
  return out.toString();
}

/// يحوّل نصًا عشريًا إلى عدد صحيح بعد ضربه في 10^[scale]، مع تقريب النصف للأعلى.
/// يعيد null إذا كان النص فارغًا أو غير صالح أو سالبًا.
///
/// فواصل الآلاف (, أو ٬ أو مسافة) مقبولة فقط في مواضعها الصحيحة قبل العلامة العشرية (كل 3 أرقام):
/// «1,234.5» صحيح، أما «12,5» (فاصلة مكان العلامة العشرية) و«1,2,3» فيعيدان null بدل قراءتهما 125 و123،
/// فيعرض النموذج خطأً تحت الحقل.
///
/// parseToMinor('15', 2) == 1500 · parseToMinor('١٠٫٦', 3) == 10600 · parseToMinor('0.125', 2) == 13
int? parseToMinor(String input, int scale) {
  final t = _normalizeKeepingGroups(input);
  final m = RegExp(r'^(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d*))?$|^\.(\d+)$').firstMatch(t);
  if (m == null) return null;
  final whole = (m.group(1) ?? '0').replaceAll(',', '');
  var frac = m.group(2) ?? m.group(3) ?? '';
  var roundUp = false;
  if (frac.length > scale) {
    roundUp = frac.codeUnitAt(scale) >= 0x35; // '5'
    frac = frac.substring(0, scale);
  }
  frac = frac.padRight(scale, '0');
  final digits = '$whole$frac'.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final value = BigInt.parse(digits.isEmpty ? '0' : digits) + (roundUp ? BigInt.one : BigInt.zero);
  if (value > BigInt.from(9007199254740991)) return null;
  return value.toInt();
}

String _group(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
    b.write(digits[i]);
  }
  return b.toString();
}

/// يعرض عددًا صحيحًا بوحدة صغرى كعدد عشري بفواصل الآلاف: formatMinor(825000, 2) == '8,250.00'.
String formatMinor(int value, int scale, {int? decimals, bool trimZeros = false}) {
  final shown = decimals ?? scale;
  final negative = value < 0;
  var v = value.abs();
  // تقريب إلى عدد المنازل المعروضة (النصف للأعلى).
  if (shown < scale) {
    var div = 1;
    for (var i = 0; i < scale - shown; i++) {
      div *= 10;
    }
    v = (v + div ~/ 2) ~/ div;
  }
  var unit = 1;
  for (var i = 0; i < shown; i++) {
    unit *= 10;
  }
  final whole = _group((v ~/ unit).toString());
  var frac = shown == 0 ? '' : (v % unit).toString().padLeft(shown, '0');
  if (trimZeros) frac = frac.replaceFirst(RegExp(r'0+$'), '');
  return '${negative ? '-' : ''}$whole${frac.isEmpty ? '' : '.$frac'}';
}

/// مبلغ بالقرش ← «8,250.00»
String formatMoney(int piasters, {int decimals = 2}) => formatMinor(piasters, 2, decimals: decimals);

/// وزن بالجرام ← «2,718.2» (منزلة واحدة افتراضيًا، دون أصفار زائدة: 550000 ← «550»)
String formatWeight(int grams, {int decimals = 1}) => formatMinor(grams, 3, decimals: decimals, trimZeros: true);

/// عدد صحيح بفواصل الآلاف.
String formatCount(int n) => formatMinor(n, 0);

/// يعرض الجزء المحلي من طابع وقت ISO بالمنطقة الزمنية للعمل: '2026-10-02T06:40:00+03:00' ← '2026-10-02 · 06:40 ص'
String formatLocalTimestamp(String? iso, {bool withDate = true}) {
  if (iso == null || iso.length < 16) return '';
  final date = iso.substring(0, 10);
  final hour = int.tryParse(iso.substring(11, 13)) ?? 0;
  final minute = iso.substring(14, 16);
  final suffix = hour < 12 ? 'ص' : 'م';
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  // مسافة غير قابلة للكسر: لا ينفصل «ص/م» عن الساعة في آخر السطر.
  final time = '${h12.toString().padLeft(2, '0')}:$minute\u00A0$suffix';
  return withDate ? '$date · $time' : time;
}

/// وقت يختاره المستخدم ← نص يرسله التطبيق للخادم: «2026-10-02 06:40».
///
/// دون إزاحة: الخادم يفسّره بالمنطقة الزمنية للعمل (الإعدادات)، فيبقى الوقت كما رآه المستخدم على الشاشة
/// مهما كانت منطقة الجهاز. أرسل null بدلًا منه حين يبقى «الآن» حتى يستخدم الخادم وقته الفعلي.
String toWallClockText(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// عكس [toWallClockText] للجزء المحلي من طابع ISO القادم من الخادم (دون تحويل منطقة).
DateTime? parseWallClock(String? iso) {
  if (iso == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})').firstMatch(iso);
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
  );
}
