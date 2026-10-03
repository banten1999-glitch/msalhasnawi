import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/models/records.dart';
import 'package:rumman_calculator/features/coolers/cooler_format.dart';

import '../../support/sample_data.dart';
import 'coolers_test_support.dart';

void main() {
  group('الحساب مطابق للخادم (docs/API.md §5)', () {
    test('50 × 11 كغ × 15 ج.م = 550 كغ و825,000 قرش', () {
      final w = purchaseWeightGrams(50, 11000);
      expect(w, 550000);
      expect(purchaseValuePiasters(w, 1500), 825000);
    });

    test('round_half_up للقيمة ولمتوسط العينة', () {
      // 1 × 0.005 كغ × 1.00 ج.م = 0.5 قرش ⇒ 1
      expect(purchaseValuePiasters(5, 100), 1);
      expect(purchaseValuePiasters(4, 100), 0);
      expect(roundHalfUpDiv(-5, 10), -1);
      // (12.9 + 13.1) / 2 − 1.9 = 11.1
      expect(sampleNetAverageGrams([12900, 13100], 1900), 11100);
      // (10.001 + 10.002) / 2 = 10.0015 ⇒ 10.002
      expect(sampleNetAverageGrams([10001, 10002], 0), 10002);
      expect(sampleNetAverageGrams(const [], 1900), 0);
    });

    test('متوسط سعر الكيلو المرجّح', () {
      expect(avgPricePerKgPiasters(4083940, 2718200), 1502);
      expect(avgPricePerKgPiasters(100, 0), 0);
    });
  });

  group('قراءة المدخلات', () {
    test('أرقام عربية ولاتينية وفواصل', () {
      expect(parseAmount('٥٠', 0).value, 50);
      expect(parseAmount('١٠٫٦', 3).value, 10600);
      expect(parseAmount('1,500.5', 2).value, 150050);
      expect(parseAmount('', 2).empty, isTrue);
    });

    test('المنازل الزائدة والنصوص الخاطئة مرفوضة بدل تقريبها', () {
      expect(parseAmount('50.5', 0).invalid, isTrue);
      expect(parseAmount('50.5', 0).tooManyDecimals, isTrue);
      expect(parseAmount('10.6255', 3).tooManyDecimals, isTrue);
      expect(parseAmount('14.755', 2).invalid, isTrue);
      expect(parseAmount('12,5', 2).invalid, isTrue);
      expect(parseAmount('abc', 2).invalid, isTrue);
    });

    test('قيم الحقول للتحرير', () {
      expect(kgInput(1900), '1.9');
      expect(kgInput(11000), '11');
      expect(kgInput(1234500), '1234.5');
      expect(moneyInput(1500), '15');
      expect(moneyInput(1475), '14.75');
      expect(moneyInput(150050), '1500.50');
    });
  });

  group('النصوص', () {
    test('العدد بالعربية', () {
      expect(operationsLabel(1), 'عملية واحدة');
      expect(operationsLabel(2), 'عمليتان');
      expect(operationsLabel(3), '3 عمليات');
      expect(operationsLabel(11), '11 عملية');
      expect(pendingLabel(4), '4 عمليات بانتظار المزامنة');
    });
  });

  group('أسماء المزارعين', () {
    test('التطبيع كما في الخادم', () {
      expect(sameName('حسن البدرى', 'حسن البدري'), isTrue);
      expect(sameName('أحمد  عليّ', 'احمد علي'), isTrue);
      expect(sameName('فاطمة', 'فاطمه'), isTrue);
      expect(sameName('حسن', 'حسين'), isFalse);
    });

    test('الأسماء المشابهة', () {
      expect(similarName('حسن البدري', 'حسن البدرى عطية'), isTrue);
      expect(similarName('محمود عبد العال', 'الحاج محمود عبد العال'), isTrue);
      expect(similarName('سعيد أبو زيد', 'سعيد ابوزيد'), isTrue);
      expect(similarName('حسن البدري', 'سعيد أبو زيد'), isFalse);
      expect(similarName('محمد حسن', 'محمد السيد'), isFalse);
      expect(similarName('محمد عبد الله السيد', 'محمد السيد'), isTrue);
    });

    test('البحث بالاسم أو الرقم، والأقرب أولًا', () {
      final farmers = [for (final j in farmersJson()) Farmer.fromJson(j)];
      expect(searchFarmers(farmers, 'محمود').map((f) => f.id), ['FR-0003']);
      expect(searchFarmers(farmers, '4').map((f) => f.id), ['FR-0004']);
      expect(searchFarmers(farmers, 'عبد').first.id, 'FR-0002');
      expect(searchFarmers(farmers, ''), isEmpty);
    });
  });

  group('الصلاحيات على العملية', () {
    final own = Purchase.fromJson(purchaseJson(createdByEmail: 'karim.abdallah.eg@gmail.com'));
    final other = Purchase.fromJson(purchaseJson());
    final cancelled =
        Purchase.fromJson(purchaseJson(status: 'cancelled', createdByEmail: 'karim.abdallah.eg@gmail.com'));

    test('موظف الإدخال يعدّل عمليته فقط في براد مفتوح', () {
      final karim = sampleEntry();
      expect(canChangePurchase(own, coolerOpen: true, user: karim), isTrue);
      expect(canChangePurchase(other, coolerOpen: true, user: karim), isFalse);
      expect(canChangePurchase(own, coolerOpen: false, user: karim), isFalse);
      expect(canChangePurchase(cancelled, coolerOpen: true, user: karim), isFalse);
      expect(canChangePurchase(other, coolerOpen: true, user: sampleAdmin()), isTrue);
      expect(canChangePurchase(own, coolerOpen: true, user: sampleViewer()), isFalse);
    });

    test('الدفعة مسموحة حتى في البراد المقفّل لمن يملك الصلاحية وعلى العملية متبقٍ', () {
      expect(canPayPurchase(other, user: sampleEntry()), isTrue);
      expect(canPayPurchase(other, user: sampleViewer()), isFalse);
      expect(canPayPurchase(cancelled, user: sampleAdmin()), isFalse);
      final paid = Purchase.fromJson(purchaseJson(paid: 825000));
      expect(canPayPurchase(paid, user: sampleAdmin()), isFalse);
    });
  });
}
