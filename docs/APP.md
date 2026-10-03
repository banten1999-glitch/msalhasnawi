# حاسبة الرمان — بنية التطبيق (Flutter)

هذا الملف يصف طبقات التطبيق في `app/` والعقود المشتركة بين الأقسام. عقد الخادم نفسه في `docs/API.md`.

## الطبقات

| المجلد | المحتوى |
|---|---|
| `lib/core/api/` | `BackendApi` (الواجهة المجردة)، `BackendActions` (تحويل كل دالة إلى إجراء من العقد فوق `call`)، `HttpBackendApi` (Apps Script)، `DemoBackendApi` (خادم في الذاكرة للوضع التجريبي)، `SubmissionRequestId`، `ApiException`. |
| `lib/core/models/` | `records.dart` (Farmer, Purchase, PurchaseInput, Payment, PackagingSummary/Item/Detail, ItemType, CoolerDetail…)، `dashboard.dart` (CoolerSummary + CloseSnapshot، DashboardData)، `user.dart` (AppUser + UserPermissions)، `settings.dart`، `sheet_status.dart`. |
| `lib/core/format/numbers.dart` | `parseToMinor` (نص بأرقام عربية أو لاتينية ← قرش/جرام صحيح)، `formatMoney`، `formatWeight`، `formatCount`، `formatLocalTimestamp`. لا أعداد عشرية تقريبية في الحسابات. |
| `lib/core/sync/` | `Outbox` (قائمة «بانتظار المزامنة»)، `DataChanges` (إشارة «تغيّرت البيانات»). |
| `lib/core/reports/` | بناء التقارير من سجلات الخادم وتصديرها (PDF عربي، CSV، طباعة، مشاركة). |
| `lib/app/` | `AppScope` (api, auth, outbox, changes)، `AppRoutes` (نقاط الدخول بين الأقسام). |
| `lib/ui/` | عناصر التصميم المشتركة (AppCard, AppButton, KpiTile, StatusChip, MoneyText, EmptyState, ErrorView, LoadingSkeleton, SegmentedChoice, PillTabs, LabeledField, InlineBanner, showConfirmDialog…). |
| `lib/features/<قسم>/` | الشاشات. كل قسم يملك مجلده فقط. |

## قواعد مشتركة

* **العربية واليمين لليسار** في كل شيء؛ الأرقام تُعرض بالأرقام اللاتينية مع فواصل الآلاف (`formatMoney`…)،
  والمدخلات تقبل الأرقام العربية واللاتينية (`parseToMinor`). لوحة أرقام عددية في كل حقل رقمي.
* **المال بالقرش والوزن بالجرام** كأعداد صحيحة. الحساب الحي في النماذج يطابق معادلات الخادم
  (`docs/API.md` §5): الوزن = الصناديق × متوسط الوزن الصافي؛ القيمة = round_half_up(الوزن × السعر/1000).
* **الصلاحيات**: الواجهة تخفي أو تعطّل ما لا يملكه المستخدم (`AppScope.of(context).auth.user!.permissions`)،
  والخادم يتحقق مرة أخرى مع كل طلب. «مشاهدة فقط» لا يرى أي زر حفظ.
* **الحفظ**: كل نموذج يستخدم `SubmissionRequestId` (نفس المعرّف عند إعادة إرسال الحمولة نفسها)، ويمنع
  الضغط المزدوج (الزر معطّل مع مؤشر أثناء الإرسال)، ولا يعرض «تم الحفظ» إلا بعد رد الخادم الناجح.
  بعد كل حفظ ناجح: `AppScope.of(context).changes.bump()`.
* **دون اتصال**: `purchases.create` و`payments.create` فقط تمر عبر `outbox.submit(...)`. النتيجة
  `SubmitSent` (حُفظت في الملف) أو `SubmitQueued` (حُفظت على الجهاز «بانتظار المزامنة» وستُرسل تلقائيًا
  بالمعرّف نفسه). بقية العمليات تعرض خطأ الاتصال وتُبقي البيانات في النموذج لإعادة المحاولة.
  تقفيل البراد يرسل `clientPendingCount: outbox.pendingForCooler(coolerId)`، والواجهة تمنعه قبل الإرسال إن
  كان أكبر من صفر.
* **لا حذف نهائي**: الإلغاء دائمًا مع سبب (`purchases.cancel`، `payments.cancel`، `packaging.cancel`).
* **الأخطاء**: `ErrorView` للصفحات، ورسالة `ApiException.message` (عربية جاهزة) تحت النموذج؛ أخطاء
  `VALIDATION` ذات `field` تُعرض تحت الحقل المعني. `CONFLICT` ⇒ «عدّل شخص آخر هذا السجل، حدّث وأعد المحاولة».
* **الاستجابة للشاشات**: الهاتف أولًا (390px)، والشاشات العريضة ≥ `kWideBreakpoint` بأعمدة/جداول. أهداف
  اللمس ≥ 48px.
* **التقارير**: بلا أرباح. متوسط سعر الكيلو مرجّح = Σ القيمة ÷ Σ الوزن.

## الأقسام وملكية الملفات

| القسم | الملفات | نقطة الدخول |
|---|---|---|
| البرادات وشراء الرمان | `features/coolers/**` | `CoolersScreen`، `CoolerDetailsScreen(coolerId)`، `PurchaseFormScreen(coolerId?, purchase?)`، `CloseCoolerScreen(coolerId)`، `showCreateCoolerSheet` |
| المزارعون | `features/farmers/**` | `FarmersScreen`، `showFarmerEditSheet(farmer?, initialName?)` |
| التعبئة والتغليف | `features/packaging/**` | `PackagingScreen`، `PackagingEditorScreen(packagingId?, coolerId?)` |
| المدفوعات | `features/payments/**` | `PaymentsScreen`، `RecordPaymentScreen(targetType?, targetId?)` |
| التقارير | `features/reports/**` | `ReportsScreen`، `CoolerReportScreen(coolerId?)`، `FarmerStatementScreen(farmerId)` |
| المزامنة | `features/sync/**` | `PendingSyncScreen` |
| الإعدادات | `features/settings/**` | `SettingsScreen` (الملف، المستخدمون، إعدادات العمل، أنواع التعبئة) |

الأقسام لا تستورد شاشات بعضها مباشرة؛ الانتقال عبر `AppRoutes` في `lib/app/routes.dart`.

## الاختبارات

* `test/support/test_app.dart`: `pumpTestApp(tester, widget, api:, auth:, outbox:?)` يبني الشاشة داخل
  السمة والعربية و`AppScope`.
* `test/support/fake_backend_api.dart`: `FakeBackendApi` يسجّل كل استدعاء؛ أي إجراء جديد يُعرّف رده في
  `fake.handlers['purchases.create'] = (payload) => {...}` أو خطؤه في `fake.errors[...]`.
* `Outbox(api: api, storage: MemoryOutboxStorage())` + `bindUser('x@y.com')` لاختبار الحفظ دون اتصال.
* التطبيق يجب أن يبنى بـ Flutter 3.44.1 (Dart 3.12) فما فوق.
