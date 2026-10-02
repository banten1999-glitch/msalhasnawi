# حاسبة الرمان

تطبيق عربي (Flutter) لإدارة شراء الرمان من المزارعين، وتحميل البرادات، ومشتريات مواد التعبئة،
مع ملف Google Sheets مركزي واحد. يعمل على الويب وAndroid وiPhone.

التصميم المرئي الكامل للشاشات: [لوحة التصميم](https://claude.ai/artifact/TCcx5D99PnYUMYDjdkY38y)

## ما تم تنفيذه حتى الآن

| الجزء | المكان |
|---|---|
| الشعار الثابت (SVG) مطابق للصورة المرجعية | `brand/logo.svg` |
| الشعار المتحرك (SVG) ومعاينة شاشة البداية | `brand/logo-animated.svg` · `brand/preview.html` |
| صور الشعار وأيقونة التطبيق والحركة (GIF) | `brand/png/` |
| مشروع Flutter مع شاشة البداية المتحركة (3 ثوانٍ، وتحترم «تقليل الحركة») | `app/` |
| أيقونات التطبيق وشاشة النظام لـ Android وiPhone والويب | مولّدة داخل `app/android` و`app/ios` و`app/web` |
| معرّفات OAuth لتسجيل الدخول بـ Google | `app/lib/config/google_auth_config.dart` |
| ملف Google Sheets المنسق (مع أمثلة، وقالب فارغ) | `sheets/rumman-calculator.xlsx` · `sheets/rumman-calculator-template.xlsx` |
| سكربت يبني الصفحات داخل Google Sheets مباشرة | `sheets/setup.gs` |
| وصف الصفحات والأعمدة للخادم | `sheets/schema.json` |

## ملف Google Sheets

يحتوي الملف على 11 صفحة، كلها من اليمين لليسار وبخط Cairo كبير وواضح:

لوحة الملخص · البرادات · المزارعون · مشتريات الرمان · مشتريات التعبئة · تفاصيل التعبئة ·
المدفوعات · المستخدمون · الإعدادات · أصناف التعبئة · سجل التعديلات

- الصف 1 عنوان الصفحة، والصف 2 شرح مختصر، والصف 3 أسماء الأعمدة، والبيانات تبدأ من الصف 4.
- كل سجل له «معرّف» ثابت؛ الربط يتم بالمعرّف وليس برقم الصف أو بالاسم.
- أعمدة الحالة فيها قوائم اختيار وألوان (مفتوح، مقفّل، مسودة، مدفوع، جزئي، غير مدفوع…).
- «لوحة الملخص» تُحسب تلقائيًا من الصفحات الأخرى، ولا يُكتب فيها يدويًا.

### طريقتان لإنشائه في Google Drive

**الأسرع: رفع الملف**
1. افتح [drive.google.com](https://drive.google.com) واسحب `sheets/rumman-calculator-template.xlsx` إليه
   (أو `rumman-calculator.xlsx` لترى البيانات التجريبية).
2. افتحه بنقرة مزدوجة، ثم من قائمة «ملف» اختر «حفظ بتنسيق Google Sheets».

**الأدق: السكربت**
1. أنشئ ملفًا جديدًا من [sheets.new](https://sheets.new).
2. من «الإضافات ← Apps Script» احذف المحتوى والصق `sheets/setup.gs` كاملًا، ثم احفظ.
3. اختر الدالة `setupRummanSheet` واضغط «تشغيل» ووافق على الصلاحيات.

السكربت آمن للتكرار: يضيف الصفحات والأعمدة الناقصة فقط ولا يمسح أي بيانات.

لإعادة توليد الملفات بعد تعديل الأعمدة: `pip install openpyxl && python3 sheets/build_sheet.py`

## تسجيل الدخول بـ Google

المعرّفات موضوعة في التطبيق (وهي عامة وليست أسرارًا):

| المنصة | Client ID | يجب أن يطابق في Google Cloud |
|---|---|---|
| الويب | `833981951758-668sjormn0kp8lm4e8c0ioltdr0ctip8` | أصول JavaScript المصرح بها: رابط موقع التطبيق، و`http://localhost` للتجربة |
| iPhone | `833981951758-pb57t33tr66q4b8c3r9tsd3gnbs4doi5` | Bundle ID: `com.hasnawi.mysheetapp` |
| Android | `833981951758-c4f37gpodur13gg933ka3hi14359alg1` | Package name: `com.hasnawi.mysheetapp` + بصمة SHA-1 لمفتاح التوقيع |

## تشغيل التطبيق

```bash
cd app
flutter pub get
flutter run            # على جهاز أو محاكي
flutter run -d chrome  # على الويب
flutter test
```

لإعادة توليد الشعار وطبقاته: `python3 brand/build_logo.py`
لإعادة توليد الأيقونات وشاشة النظام: `dart run flutter_launcher_icons` ثم `dart run flutter_native_splash:create`

الخطوط المستخدمة: IBM Plex Sans Arabic وReadex Pro (رخصة SIL Open Font License، النص في `app/assets/fonts/OFL.txt`).
