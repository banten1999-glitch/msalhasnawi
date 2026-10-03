/// تصدير التقرير إلى CSV: UTF-8 مع BOM (حتى يعرض Excel العربية)، واقتباس RFC 4180، وأسطر CRLF.
/// الأرقام خام دون فواصل الآلاف (8250.00) حتى تجمعها برامج الجداول.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../format/numbers.dart';
import 'report_document.dart';

/// علامة ترتيب البايتات: تجعل Excel يقرأ الملف UTF-8.
const kCsvBom = '\uFEFF';

const _eol = '\r\n';

final _plainNumber = RegExp(r'^-?\d+(\.\d+)?$');

/// يبني نص CSV كاملًا (يبدأ بـ BOM): العنوان ووقت الإنشاء، ثم البيانات التعريفية، ثم الملخص، ثم كل قسم
/// يسبقه سطر فارغ وسطر بعنوانه، ثم جدوله (العناوين، الصفوف، صف الإجمالي) وملاحظاته.
String buildReportCsv(ReportDocument doc) {
  final lines = <List<String>>[];
  void blank() => lines.add(const []);
  void entries(List<ReportEntry> list) {
    for (final e in list) {
      lines.add([e.label, e.value.raw, if (e.unit != null) e.unit!]);
    }
  }

  lines.add([doc.title]);
  if (doc.subtitle != null && doc.subtitle!.isNotEmpty) lines.add([doc.subtitle!]);
  lines.add(['تاريخ الإنشاء', toWallClockText(doc.generatedAt)]);
  if (doc.meta.isNotEmpty) {
    blank();
    entries(doc.meta);
  }
  if (doc.summary.isNotEmpty) {
    blank();
    lines.add(['الملخص']);
    entries(doc.summary);
  }
  for (final s in doc.sections) {
    blank();
    lines.add([s.title]);
    entries(s.entries);
    final t = s.table;
    if (t != null) {
      lines.add([for (final c in t.columns) c.title]);
      for (final r in t.rows) {
        lines.add([for (final c in r.cells) c.raw]);
      }
      if (t.rows.isEmpty) lines.add([t.emptyText]);
      if (t.totals != null && t.rows.isNotEmpty) lines.add([for (final c in t.totals!) c.raw]);
    }
    for (final n in s.notes) {
      lines.add([n]);
    }
  }

  final out = StringBuffer(kCsvBom);
  for (final l in lines) {
    out
      ..write(l.map(csvField).join(','))
      ..write(_eol);
  }
  return out.toString();
}

/// نص CSV ← بايتات UTF-8 (الـ BOM يُرمَّز EF BB BF).
Uint8List csvBytes(String csv) => Uint8List.fromList(utf8.encode(csv));

/// حقل CSV وفق RFC 4180: يُقتبس إن احتوى فاصلة أو علامة اقتباس أو سطرًا جديدًا (وتُضاعف علامات الاقتباس).
/// النص الذي يبدأ بـ = + - @ (وليس رقمًا) تسبقه «'» حتى لا يفسره برنامج الجداول معادلة.
String csvField(String value) {
  var v = value;
  if (v.isNotEmpty && !_plainNumber.hasMatch(v) && '=+-@\t\r'.contains(v[0])) v = "'$v";
  final needsQuotes = v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r');
  return needsQuotes ? '"${v.replaceAll('"', '""')}"' : v;
}
