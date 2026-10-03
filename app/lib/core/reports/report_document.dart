/// نموذج محايد للتقرير: تبنيه كل التقارير (البراد، كشف المزارع، الموردون، الفترة)، وتعرضه الواجهة كما هو،
/// ويُصدَّر منه ملف PDF وملف CSV. لا يعرف شيئًا عن Flutter أو الخادم.
library;

import '../format/numbers.dart';
import 'report_format.dart';

/// محاذاة العمود باتجاه النص: [start] = يمين الصفحة العربية، [end] = يسارها.
enum ReportAlign { start, center, end }

/// خلية: [text] للعرض (بفواصل الآلاف كما في التطبيق)، و[raw] لملف CSV (رقم خام دون فواصل مثل 8250.00
/// حتى تجمعه برامج الجداول).
class ReportCell {
  const ReportCell(this.text, {this.rawValue});

  /// مبلغ بالقرش: «8,250.00» للعرض و«8250.00» لـ CSV.
  ReportCell.money(int piasters)
      : text = formatMoney(piasters),
        rawValue = plainMinor(piasters, 2);

  /// وزن بالجرام بالكيلوغرام: «2,718.2» للعرض و«2718.200» (دقة كاملة) لـ CSV.
  ReportCell.weight(int grams, {int decimals = 1})
      : text = formatWeight(grams, decimals: decimals),
        rawValue = plainMinor(grams, 3);

  /// عدد صحيح: «1,234» للعرض و«1234» لـ CSV.
  ReportCell.count(int n)
      : text = formatCount(n),
        rawValue = '$n';

  /// تاريخ ووقت ISO بتوقيت العمل: «2026-10-02 · 06:40 ص».
  ReportCell.time(String? iso)
      : text = formatLocalTimestamp(iso),
        rawValue = isoWallClock(iso);

  /// التاريخ فقط: «2026-10-02».
  ReportCell.date(String? iso)
      : text = isoDate(iso),
        rawValue = isoDate(iso);

  static const empty = ReportCell('');

  final String text;

  /// قيمة CSV إن اختلفت عن [text] (null = [text] نفسه).
  final String? rawValue;

  /// القيمة في ملف CSV.
  String get raw => rawValue ?? text;

  @override
  String toString() => text;
}

class ReportColumn {
  const ReportColumn(this.title, {this.numeric = false, ReportAlign? align, this.flex = 1})
      : align = align ?? (numeric ? ReportAlign.end : ReportAlign.start);

  final String title;

  /// عمود أرقام: يُحاذى للطرف الآخر ويُكتب في CSV دون فواصل الآلاف.
  final bool numeric;
  final ReportAlign align;

  /// عرض نسبي للعمود في PDF والمعاينة (1 = عادي).
  final double flex;
}

class ReportRow {
  const ReportRow(this.cells, {this.muted = false});

  final List<ReportCell> cells;

  /// صف معروض للعلم فقط ولا يدخل في المجاميع (عملية ملغاة أو مسودة): يُعرض باهتًا.
  final bool muted;
}

class ReportTable {
  const ReportTable({required this.columns, this.rows = const [], this.totals, this.emptyText = 'لا توجد بيانات'});

  final List<ReportColumn> columns;
  final List<ReportRow> rows;

  /// صف «الإجمالي» (بعدد الأعمدة نفسه)، يُعرض بخط عريض.
  final List<ReportCell>? totals;

  /// يُعرض بدل الجدول حين لا توجد صفوف.
  final String emptyText;
}

/// زوج «البند: القيمة» في رأس التقرير أو ملخصه.
class ReportEntry {
  const ReportEntry(this.label, this.value, {this.unit, this.highlight = false});

  ReportEntry.text(this.label, String text, {this.highlight = false})
      : value = ReportCell(text),
        unit = null;

  final String label;
  final ReportCell value;

  /// «ج.م» أو «كغ»… تُلحق بالقيمة في العرض، وتُكتب في عمود مستقل في CSV.
  final String? unit;

  /// بند رئيسي (مثل المتبقي أو إجمالي التكلفة): يُبرز في العرض.
  final bool highlight;

  /// «8,250.00 ج.م»
  String get text => unit == null || value.text.isEmpty ? value.text : '${value.text} $unit';
}

class ReportSection {
  const ReportSection({required this.title, this.entries = const [], this.table, this.notes = const []});

  final String title;
  final List<ReportEntry> entries;
  final ReportTable? table;

  /// ملاحظات توضيحية تحت الجدول (مثل «العمليات الملغاة لا تدخل في المجاميع»).
  final List<String> notes;
}

class ReportDocument {
  const ReportDocument({
    required this.title,
    this.subtitle,
    required this.generatedAt,
    this.meta = const [],
    this.summary = const [],
    this.sections = const [],
    required this.fileStem,
    required this.asciiFileStem,
  });

  /// «تقرير البراد 14»
  final String title;

  /// «شحنة دمياط · مقفّل»
  final String? subtitle;

  /// وقت إنشاء التقرير على الجهاز.
  final DateTime generatedAt;

  /// بيانات تعريفية (البراد، المزارع، الفترة…).
  final List<ReportEntry> meta;

  /// الأرقام الرئيسية.
  final List<ReportEntry> summary;
  final List<ReportSection> sections;

  /// اسم الملف دون الامتداد: «تقرير-البراد-14».
  final String fileStem;

  /// بديل لاتيني لاسم الملف لنوافذ المشاركة التي لا تقبل الأحرف العربية: «cooler-report-14».
  final String asciiFileStem;

  /// «2026-10-03 · 09:15 ص»
  String get generatedAtText => formatLocalTimestamp(toWallClockText(generatedAt));
}
