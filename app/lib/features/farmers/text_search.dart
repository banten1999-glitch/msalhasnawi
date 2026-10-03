/// البحث النصي المتسامح مع الكتابة العربية (يستخدمه قسما المزارعين والمدفوعات).
library;

import '../../core/models/records.dart';

/// تطبيع للبحث والمقارنة، مطابق لـ normText_ في الخادم (backend/src/Util.gs):
/// أرقام لاتينية، بلا تشكيل أو تطويل أو علامات اتجاه، توحيد الألف والياء والتاء المربوطة والهمزات، مسافات مفردة.
///
/// normalizeArabic('أحمد  الشافعى') == 'احمد الشافعي' · normalizeArabic('٠١٠') == '010'
String normalizeArabic(String? input) {
  if (input == null || input.isEmpty) return '';
  final b = StringBuffer();
  for (final r in input.runes) {
    if (r >= 0x0660 && r <= 0x0669) {
      b.writeCharCode(0x30 + r - 0x0660);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      b.writeCharCode(0x30 + r - 0x06F0);
    } else if ((r >= 0x064B && r <= 0x065F) ||
        r == 0x0670 ||
        r == 0x0640 ||
        (r >= 0x200B && r <= 0x200F) ||
        (r >= 0x202A && r <= 0x202E) ||
        (r >= 0x2066 && r <= 0x2069)) {
      // تشكيل، تطويل، محارف اتجاه غير مرئية.
      continue;
    } else {
      b.writeCharCode(switch (r) {
        0x0622 || 0x0623 || 0x0625 || 0x0671 => 0x0627, // آ أ إ ٱ ← ا
        0x0649 || 0x0626 => 0x064A, // ى ئ ← ي
        0x0629 => 0x0647, // ة ← ه
        0x0624 => 0x0648, // ؤ ← و
        _ => r,
      });
    }
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}

/// الأرقام فقط من نص (بعد تحويل الأرقام العربية): «٠١٠ ١٢٣-٤» ← «0101234».
String digitsOnly(String? input) => normalizeArabic(input).replaceAll(RegExp(r'\D'), '');

final _allDigits = RegExp(r'^\d+$');

/// كل كلمة من [query] موجودة في أحد [fields] بعد التطبيع. استعلام فارغ يطابق كل شيء.
bool matchesAllWords(Iterable<String?> fields, String query) {
  final q = normalizeArabic(query);
  if (q.isEmpty) return true;
  final hay = normalizeArabic(fields.whereType<String>().join(' '));
  return q.split(' ').every(hay.contains);
}

/// هل يطابق المزارع البحث؟ بالاسم أو القرية (كل الكلمات، دون حساسية للهمزات والتاء المربوطة والتشكيل)،
/// أو برقم المزارع بالضبط، أو بجزء من رقم الهاتف (3 أرقام على الأقل). يقبل الأرقام العربية واللاتينية.
bool farmerMatches(Farmer f, String query) {
  final q = normalizeArabic(query);
  if (q.isEmpty) return true;
  final hay = normalizeArabic('${f.name} ${f.village ?? ''}');
  final phone = digitsOnly(f.phone);
  return q.split(' ').every((word) {
    if (hay.contains(word)) return true;
    if (!_allDigits.hasMatch(word)) return false;
    return word == '${f.no}' || (word.length >= 3 && phone.contains(word));
  });
}

/// «مزارع واحد»، «مزارعان»، «3 مزارعين»، «11 مزارعًا».
String farmersCountLabel(int n) {
  if (n == 0) return 'لا مزارعين';
  if (n == 1) return 'مزارع واحد';
  if (n == 2) return 'مزارعان';
  final mod = n % 100;
  if (mod >= 3 && mod <= 10) return '$n مزارعين';
  return '$n مزارعًا';
}

/// «عملية واحدة»، «عمليتان»، «3 عمليات»، «11 عملية».
String operationsLabel(int n) {
  if (n == 0) return 'لا عمليات';
  if (n == 1) return 'عملية واحدة';
  if (n == 2) return 'عمليتان';
  final mod = n % 100;
  if (mod >= 3 && mod <= 10) return '$n عمليات';
  return '$n عملية';
}
