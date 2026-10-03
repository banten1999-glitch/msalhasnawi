/// تصدير التقرير إلى PDF عربي (A4، من اليمين لليسار، خط IBM Plex Sans Arabic).
///
/// الجداول تنقسم على الصفحات مع تكرار صف العناوين، وفي أسفل كل صفحة «صفحة X من Y».
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'report_document.dart';
import 'report_pdf_text.dart';

/// خطوط التقرير. في التطبيق: [ReportFonts.fromAssets]؛ في الاختبارات: [ReportFonts.fromBytes] من ملف.
class ReportFonts {
  const ReportFonts({required this.regular, required this.bold});

  /// من بايتات ملفات TTF (مثلًا File('assets/fonts/IBMPlexSansArabic-Regular.ttf').readAsBytesSync()).
  factory ReportFonts.fromBytes(Uint8List regular, Uint8List bold) => ReportFonts(
        regular: pw.Font.ttf(ByteData.sublistView(regular)),
        bold: pw.Font.ttf(ByteData.sublistView(bold)),
      );

  static const regularAsset = 'assets/fonts/IBMPlexSansArabic-Regular.ttf';
  static const boldAsset = 'assets/fonts/IBMPlexSansArabic-Bold.ttf';

  static Future<ReportFonts>? _cached;

  /// من أصول التطبيق (تُحمَّل مرة واحدة ثم تُستخدم من الذاكرة).
  static Future<ReportFonts> fromAssets({AssetBundle? bundle}) {
    Future<ReportFonts> load() async {
      final b = bundle ?? rootBundle;
      final data = await Future.wait([b.load(regularAsset), b.load(boldAsset)]);
      return ReportFonts(regular: pw.Font.ttf(data[0]), bold: pw.Font.ttf(data[1]));
    }

    if (bundle != null) return load();
    return _cached ??= load().catchError((Object e) {
      _cached = null;
      throw e;
    });
  }

  final pw.Font regular;
  final pw.Font bold;
}

// ---------------------------------------------------------------- الألوان (من سمة التطبيق)

const _brand = PdfColor.fromInt(0xFFA00B1E);
const _ink = PdfColor.fromInt(0xFF2B2420);
const _label = PdfColor.fromInt(0xFF3D3530);
const _hint = PdfColor.fromInt(0xFF8F857D);
const _muted = PdfColor.fromInt(0xFF9C928A);
const _border = PdfColor.fromInt(0xFFE2D9CC);
const _tableHead = PdfColor.fromInt(0xFFF6F1E9);
const _zebra = PdfColor.fromInt(0xFFFCFAF6);
const _totalsBg = PdfColor.fromInt(0xFFF3EEE6);
const _highlightBg = PdfColor.fromInt(0xFFFFF8EA);
const _highlightBorder = PdfColor.fromInt(0xFFF3DDB0);

/// يبني ملف PDF للتقرير. [businessName] من الإعدادات (settings.businessName).
Future<Uint8List> buildReportPdf(ReportDocument doc, {required String businessName, ReportFonts? fonts}) async {
  final pdf = await buildReportPdfDocument(doc, businessName: businessName, fonts: fonts);
  return pdf.save();
}

/// مثل [buildReportPdf] لكنه يعيد المستند قبل الحفظ (للاختبارات: عدد الصفحات بعد save).
Future<pw.Document> buildReportPdfDocument(ReportDocument doc, {required String businessName, ReportFonts? fonts}) async {
  final f = fonts ?? await ReportFonts.fromAssets();
  final pdf = pw.Document(
    title: _t(doc.title),
    author: _t(businessName),
    creator: 'حاسبة الرمان',
    subject: doc.subtitle == null ? null : _t(doc.subtitle!),
  );
  final generated = _t(doc.generatedAtText);
  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 22),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: f.regular, bold: f.bold).copyWith(
              defaultTextStyle: pw.TextStyle(font: f.regular, fontBold: f.bold, fontSize: 9, color: _ink),
            ),
      ),
      maxPages: 1000,
      header: (ctx) => _header(ctx, doc, businessName, generated),
      footer: (ctx) => _footer(ctx, doc),
      build: (ctx) => [
        if (doc.meta.isNotEmpty) _metaBox(doc.meta),
        if (doc.summary.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _sectionTitle('الملخص'),
          _summaryGrid(doc.summary),
        ],
        for (final s in doc.sections) ..._section(s),
      ],
    ),
  );
  return pdf;
}

// ---------------------------------------------------------------- النص

String _t(String s) => pdfSafeText(s);

/// كل نصوص التقرير تمر من هنا: rtlText يضمن المسافات الصحيحة بين الكلمات العربية (راجع report_pdf_text.dart).
pw.Widget _text(
  String s, {
  double size = 9,
  bool bold = false,
  PdfColor color = _ink,
  pw.TextAlign align = pw.TextAlign.right,
  int? maxLines,
}) =>
    rtlText(
      s,
      align: align,
      maxLines: maxLines,
      style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color),
    );

pw.TextAlign _align(ReportAlign a) => switch (a) {
      ReportAlign.start => pw.TextAlign.right,
      ReportAlign.center => pw.TextAlign.center,
      ReportAlign.end => pw.TextAlign.left,
    };

pw.Alignment _boxAlign(ReportAlign a) => switch (a) {
      ReportAlign.start => pw.Alignment.centerRight,
      ReportAlign.center => pw.Alignment.center,
      ReportAlign.end => pw.Alignment.centerLeft,
    };

// ---------------------------------------------------------------- الرأس والتذييل

pw.Widget _header(pw.Context ctx, ReportDocument doc, String businessName, String generated) {
  if (ctx.pageNumber > 1) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.6))),
      child: pw.Row(
        children: [
          pw.Expanded(child: _text('$businessName · ${doc.title}', size: 8.5, bold: true, color: _label, maxLines: 1)),
          _text(generated, size: 7.5, color: _hint, align: pw.TextAlign.left),
        ],
      ),
    );
  }
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _brand, width: 1.2))),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _text(businessName, size: 10, bold: true, color: _brand),
              pw.SizedBox(height: 2),
              _text(doc.title, size: 16, bold: true),
              if (doc.subtitle != null && doc.subtitle!.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                _text(doc.subtitle!, size: 10, color: _label),
              ],
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _text('تاريخ الإنشاء', size: 7.5, color: _hint, align: pw.TextAlign.left),
            _text(generated, size: 8.5, color: _label, align: pw.TextAlign.left),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _footer(pw.Context ctx, ReportDocument doc) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _border, width: 0.6))),
      child: pw.Row(
        children: [
          pw.Expanded(child: _text(doc.title, size: 7.5, color: _hint, maxLines: 1)),
          _text('صفحة ${ctx.pageNumber} من ${ctx.pagesCount}', size: 8, color: _label, align: pw.TextAlign.left),
        ],
      ),
    );

// ---------------------------------------------------------------- البيانات التعريفية والملخص

/// صفوف من [perRow] عناصر متساوية العرض (Row تحترم الاتجاه من اليمين).
List<pw.Widget> _grid(List<pw.Widget> cells, int perRow, {double gap = 6}) {
  final rows = <pw.Widget>[];
  for (var i = 0; i < cells.length; i += perRow) {
    final chunk = cells.sublist(i, i + perRow > cells.length ? cells.length : i + perRow);
    rows.add(pw.Padding(
      padding: pw.EdgeInsets.only(bottom: gap),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (var j = 0; j < perRow; j++) ...[
            if (j > 0) pw.SizedBox(width: gap),
            pw.Expanded(child: j < chunk.length ? chunk[j] : pw.SizedBox()),
          ],
        ],
      ),
    ));
  }
  return rows;
}

pw.Widget _metaBox(List<ReportEntry> meta) => pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 2),
      decoration: pw.BoxDecoration(
        color: _zebra,
        border: pw.Border.all(color: _border, width: 0.6),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: _grid([
          for (final e in meta)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _text(e.label, size: 7.5, color: _hint),
                _text(e.text.isEmpty ? '—' : e.text, size: 9, bold: true),
              ],
            ),
        ], 4),
      ),
    );

pw.Widget _entryTile(ReportEntry e, {bool compact = false}) => pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 4 : 6),
      decoration: pw.BoxDecoration(
        color: e.highlight ? _highlightBg : PdfColors.white,
        border: pw.Border.all(color: e.highlight ? _highlightBorder : _border, width: 0.6),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _text(e.label, size: 7.5, color: _hint),
          pw.SizedBox(height: 1),
          _text(e.text, size: compact ? 9.5 : 11, bold: true, color: e.highlight ? _brand : _ink),
        ],
      ),
    );

pw.Widget _summaryGrid(List<ReportEntry> entries) =>
    pw.Column(children: _grid([for (final e in entries) _entryTile(e)], 4));

// ---------------------------------------------------------------- الأقسام والجداول

pw.Widget _sectionTitle(String title) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.fromLTRB(0, 2, 6, 2),
      decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: _brand, width: 3))),
      child: _text(title, size: 11.5, bold: true),
    );

/// أقصى عدد صفوف لجدول يبقى مع عنوان قسمه وملاحظاته في صفحة واحدة؛ الجداول الأكبر تنقسم على الصفحات.
const _keepTogetherRows = 12;

List<pw.Widget> _section(ReportSection s) {
  final t = s.table;
  final head = [
    _sectionTitle(s.title),
    if (s.entries.isNotEmpty) pw.Column(children: _grid([for (final e in s.entries) _entryTile(e, compact: true)], 4)),
  ];
  final notes = [
    if (s.notes.isNotEmpty) pw.SizedBox(height: 4),
    for (final n in s.notes)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2),
        child: _text('• $n', size: 7.5, color: _label),
      ),
  ];
  pw.Widget together(List<pw.Widget> children) =>
      pw.Inseparable(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children));
  // قسم صغير لا يُفصل عنوانه عن جدوله؛ الكبير يبقى عنوانه وبطاقاته معًا وينقسم جدوله مع تكرار صف العناوين.
  if (t == null || t.rows.length <= _keepTogetherRows) {
    return [pw.SizedBox(height: 12), together([...head, if (t != null) _table(t), ...notes])];
  }
  return [pw.SizedBox(height: 12), together(head), _table(t), ...notes];
}

pw.Widget _table(ReportTable t) {
  if (t.rows.isEmpty) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _border, width: 0.6)),
      child: _text(t.emptyText, size: 8.5, color: _hint, align: pw.TextAlign.center),
    );
  }
  final n = t.columns.length;
  // pw.Table لا يعكس الأعمدة في الاتجاه من اليمين لليسار: نرتبها بأنفسنا (العمود الأول في أقصى اليمين).
  List<T> rtl<T>(List<T> cells) => cells.reversed.toList();

  pw.Widget cell(String text, ReportColumn c, {bool bold = false, PdfColor color = _ink, double size = 7.5}) =>
      pw.Container(
        alignment: _boxAlign(c.align),
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: _text(text, size: size, bold: bold, color: color, align: _align(c.align)),
      );

  List<ReportCell> fit(List<ReportCell> cells) =>
      [for (var i = 0; i < n; i++) i < cells.length ? cells[i] : ReportCell.empty];

  final rows = <pw.TableRow>[
    pw.TableRow(
      repeat: true,
      decoration: const pw.BoxDecoration(color: _tableHead),
      verticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rtl([for (final c in t.columns) cell(c.title, c, bold: true, color: _label, size: 7.2)]),
    ),
    for (var r = 0; r < t.rows.length; r++)
      pw.TableRow(
        decoration: pw.BoxDecoration(color: r.isOdd ? _zebra : PdfColors.white),
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: rtl([
          for (final (i, c) in fit(t.rows[r].cells).indexed)
            cell(c.text, t.columns[i], color: t.rows[r].muted ? _muted : _ink),
        ]),
      ),
    if (t.totals != null)
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: _totalsBg,
          border: pw.Border(top: pw.BorderSide(color: _label, width: 0.8)),
        ),
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: rtl([for (final (i, c) in fit(t.totals!).indexed) cell(c.text, t.columns[i], bold: true)]),
      ),
  ];

  return pw.Table(
    border: const pw.TableBorder(
      top: pw.BorderSide(color: _border, width: 0.6),
      bottom: pw.BorderSide(color: _border, width: 0.6),
      left: pw.BorderSide(color: _border, width: 0.6),
      right: pw.BorderSide(color: _border, width: 0.6),
      horizontalInside: pw.BorderSide(color: _border, width: 0.4),
      verticalInside: pw.BorderSide(color: _border, width: 0.4),
    ),
    columnWidths: {
      for (var i = 0; i < n; i++) n - 1 - i: pw.FlexColumnWidth(t.columns[i].flex),
    },
    children: rows,
  );
}
