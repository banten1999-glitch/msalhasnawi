/// أوامر التصدير من شاشة التقرير: طباعة، مشاركة PDF، حفظ أو مشاركة CSV.
///
/// على الويب: الطباعة نافذة طباعة المتصفح، والحفظ تنزيل مباشر للملف. على Android وiPhone: نافذة المشاركة
/// (حفظ في الملفات، Drive، واتساب…).
library;

import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'report_csv.dart';
import 'report_document.dart';
import 'report_download.dart';
import 'report_pdf.dart';

/// أوامر التصدير لتقرير واحد. في اختبارات الواجهة يمكن توريثه وتجاوز دواله حتى لا تُفتح نوافذ النظام.
class ReportActions {
  const ReportActions({required this.businessName, this.fonts});

  /// اسم النشاط في رأس PDF (settings.businessName).
  final String businessName;

  /// null = خطوط التطبيق من الأصول.
  final ReportFonts? fonts;

  static const pdfMimeType = 'application/pdf';
  static const csvMimeType = 'text/csv';

  /// «تقرير-البراد-14.pdf»، أو «cooler-report-14.pdf» مع [ascii].
  static String pdfFileName(ReportDocument doc, {bool ascii = false}) =>
      '${ascii ? doc.asciiFileStem : doc.fileStem}.pdf';

  /// «تقرير-البراد-14.csv»، أو «cooler-report-14.csv» مع [ascii].
  static String csvFileName(ReportDocument doc, {bool ascii = false}) =>
      '${ascii ? doc.asciiFileStem : doc.fileStem}.csv';

  /// بايتات PDF (لحفظها مسبقًا وتمريرها لعدة أوامر دون إعادة البناء).
  Future<Uint8List> buildPdf(ReportDocument doc) => buildReportPdf(doc, businessName: businessName, fonts: fonts);

  /// بايتات CSV بترميز UTF-8 مع BOM.
  Uint8List buildCsv(ReportDocument doc) => csvBytes(buildReportCsv(doc));

  /// نافذة الطباعة (A4). [pdf]: بايتات جاهزة من [buildPdf] إن وُجدت.
  Future<bool> printPdf(ReportDocument doc, {Uint8List? pdf}) async {
    final bytes = pdf ?? await buildPdf(doc);
    return Printing.layoutPdf(name: doc.fileStem, format: PdfPageFormat.a4, onLayout: (_) async => bytes);
  }

  /// مشاركة PDF: نافذة المشاركة على الهاتف، وتنزيل على الويب. [origin]: موضع الزر (لنافذة iPad).
  Future<bool> sharePdf(ReportDocument doc, {Uint8List? pdf, Rect? origin}) async {
    final bytes = pdf ?? await buildPdf(doc);
    Future<bool> share(bool ascii) =>
        Printing.sharePdf(bytes: bytes, filename: pdfFileName(doc, ascii: ascii), subject: doc.title, bounds: origin);
    try {
      return await share(false);
    } on PlatformException {
      // بعض نوافذ المشاركة ترفض أسماء الملفات غير اللاتينية.
      return share(true);
    }
  }

  /// حفظ PDF: تنزيل مباشر على الويب، ونافذة المشاركة على الهاتف.
  Future<bool> savePdf(ReportDocument doc, {Uint8List? pdf, Rect? origin}) async {
    if (!kIsWeb) return sharePdf(doc, pdf: pdf, origin: origin);
    return downloadBytes(pdf ?? await buildPdf(doc), fileName: pdfFileName(doc), mimeType: pdfMimeType);
  }

  /// حفظ CSV: تنزيل مباشر على الويب، ونافذة المشاركة على الهاتف («حفظ في الملفات» منها).
  Future<bool> saveCsv(ReportDocument doc, {Rect? origin}) => _shareFile(
        buildCsv(doc),
        name: csvFileName(doc),
        asciiName: csvFileName(doc, ascii: true),
        mimeType: csvMimeType,
        title: doc.title,
        origin: origin,
      );

  /// مشاركة CSV: نافذة المشاركة على الهاتف، وتنزيل على الويب.
  Future<bool> shareCsv(ReportDocument doc, {Rect? origin}) => saveCsv(doc, origin: origin);

  /// true إذا نُزّل الملف أو شورك (false إذا أغلق المستخدم نافذة المشاركة).
  Future<bool> _shareFile(
    Uint8List bytes, {
    required String name,
    required String asciiName,
    required String mimeType,
    required String title,
    Rect? origin,
  }) async {
    if (kIsWeb) return downloadBytes(bytes, fileName: name, mimeType: '$mimeType;charset=utf-8');
    Future<ShareResult> share(String fileName) => SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
          fileNameOverrides: [fileName],
          title: title,
          subject: title,
          sharePositionOrigin: origin,
        ));
    ShareResult result;
    try {
      result = await share(name);
    } on PlatformException {
      result = await share(asciiName);
    }
    return result.status != ShareResultStatus.dismissed;
  }
}
