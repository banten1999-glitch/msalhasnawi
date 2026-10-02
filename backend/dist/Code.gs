/**
 * حاسبة الرمان — الخادم (Google Apps Script)
 *
 * ملف مولَّد تلقائيًا بواسطة backend/build.py — لا تعدّله يدويًا.
 * المصادر: sheets/setup.gs ثم backend/src/*.gs (Config.gs وUtil.gs أولًا ثم الباقي بالترتيب الأبجدي).
 * العقد: docs/API.md. خطوات النشر: backend/DEPLOY.md.
 *
 * GENERATED FILE — do not edit. Edit sheets/build_sheet.py or backend/src/*.gs and run
 * `python3 backend/build.py` again.
 */

// ============================================================================================
// المصدر: sheets/setup.gs
// ============================================================================================

/**
 * حاسبة الرمان — إعداد ملف Google Sheets المركزي
 *
 * الاستخدام:
 *   1. أنشئ ملف Google Sheets جديدًا (sheets.new).
 *   2. من القائمة: الإضافات ← Apps Script، والصق هذا الملف كاملًا مكان المحتوى، ثم احفظ.
 *   3. اختر الدالة setupRummanSheet واضغط «تشغيل»، ووافق على الصلاحيات.
 *
 * التشغيل آمن للتكرار: يُنشئ الصفحات والأعمدة الناقصة فقط، ويعيد التنسيق،
 * ولا يمسح أي بيانات موجودة في صفحات البيانات.
 *
 * هذا الملف مولَّد من sheets/build_sheet.py — عدّل المصدر هناك ثم أعد التوليد.
 */

const SCHEMA = {
  "version": 1,
  "headerRow": 3,
  "firstDataRow": 4,
  "sheets": [
    {
      "key": "coolers",
      "title": "البرادات",
      "description": "بيانات كل براد وحالته. أعمدة «عند التقفيل» تُحفظ مرة واحدة لحظة التقفيل ولا تتغير بعدها.",
      "tabColor": "#A00B1E",
      "freezeColumns": 2,
      "columns": [
        {
          "name": "المعرّف",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "رقم البراد",
          "kind": "int",
          "width": 12,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الاسم / الوصف",
          "kind": "text",
          "width": 20,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "رقم السيارة",
          "kind": "text",
          "width": 15,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "السائق",
          "kind": "text",
          "width": 16,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "تاريخ ووقت الفتح",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الحالة",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "مفتوح",
            "مقفّل"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "فتحه",
          "kind": "text",
          "width": 20,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "تاريخ ووقت التقفيل",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "قفّله",
          "kind": "text",
          "width": 20,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "عدد المزارعين عند التقفيل",
          "kind": "int",
          "width": 15,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "عدد العمليات عند التقفيل",
          "kind": "int",
          "width": 15,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الصناديق عند التقفيل",
          "kind": "int",
          "width": 14,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الوزن عند التقفيل (كغ)",
          "kind": "kg",
          "width": 15,
          "numberFormat": "#,##0.0",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "قيمة الرمان عند التقفيل (ج.م)",
          "kind": "money",
          "width": 17,
          "numberFormat": "#,##0.00",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": "bold"
        },
        {
          "name": "المدفوع عند التقفيل (ج.م)",
          "kind": "money",
          "width": 17,
          "numberFormat": "#,##0.00",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": "paid"
        },
        {
          "name": "المتبقي عند التقفيل (ج.م)",
          "kind": "money",
          "width": 17,
          "numberFormat": "#,##0.00",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": "due"
        },
        {
          "name": "التعبئة عند التقفيل (ج.م)",
          "kind": "money",
          "width": 17,
          "numberFormat": "#,##0.00",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "إجمالي التكلفة عند التقفيل (ج.م)",
          "kind": "money",
          "width": 17,
          "numberFormat": "#,##0.00",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": "bold"
        },
        {
          "name": "ملاحظات",
          "kind": "long",
          "width": 34,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "آخر تعديل",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "عدّله",
          "kind": "text",
          "width": 20,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الإصدار",
          "kind": "int",
          "width": 12,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": true,
          "emphasis": null
        }
      ]
    },
    {
      "key": "farmers",
      "title": "المزارعون",
      "description": "قائمة المزارعين. يُربط كل شراء بالمعرّف وليس بالاسم، فتغيير الاسم لا يفصل العمليات السابقة.",
      "tabColor": "#1F6B2C",
      "freezeColumns": 3,
      "columns": [
        {
          "name": "المعرّف",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "رقم المزارع",
          "kind": "int",
          "width": 12,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الاسم",
          "kind": "text",
          "width": 24,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الهاتف",
          "kind": "text",
          "width": 16,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "القرية / المنطقة",
          "kind": "text",
          "width": 18,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "ملاحظات",
          "kind": "long",
          "width": 34,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الحالة",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "نشط",
            "موقوف"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "تاريخ الإضافة",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "أضافه",
          "kind": "text",
          "width": 20,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الإصدار",
          "kind": "int",
          "width": 12,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": true,
          "emphasis": null
        }
      ]
    },
    {
      "key": "purchases",
      "title": "مشتريات الرمان",
      "description": "كل عملية شراء من مزارع. الوزن = الصناديق × متوسط الوزن الصافي، والقيمة = الوزن × سعر الكيلو. المدفوع والمتبقي يحسبهما التطبيق من صفحة المدفوعات.",
      "tabColor": "#A00B1E",
      "freezeColumns": 5,
      "columns": [
        {
          "name": "المعرّف",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "معرّف البراد",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "رقم البراد",
          "kind": "int",
          "width": 11,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "معرّف المزارع",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "اسم المزارع",
          "kind": "text",
          "width": 24,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "تاريخ ووقت العملية",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "عدد الصناديق",
          "kind": "int",
          "width": 12,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "متوسط وزن الصندوق (كغ)",
          "kind": "kg3",
          "width": 15,
          "numberFormat": "0.0##",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "طريقة حساب الوزن",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "مباشر",
            "عينة"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "أوزان العينة (كغ)",
          "kind": "text",
          "width": 22,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "وزن الصندوق الفارغ (كغ)",
          "kind": "kg3",
          "width": 15,
          "numberFormat": "0.0##",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "إجمالي الوزن (كغ)",
          "kind": "kg",
          "width": 15,
          "numberFormat": "#,##0.0",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": "bold"
        },
        {
          "name": "سعر الكيلو (ج.م)",
          "kind": "money",
          "width": 14,
          "numberFormat": "#,##0.00",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "إجمالي السعر (ج.م)",
          "kind": "money",
          "width": 17,
          "numberFormat": "#,##0.00",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": "bold"
        },
        {
          "name": "المدفوع (ج.م)",
          "kind": "money",
          "width": 17,
          "numberFormat": "#,##0.00",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": "paid"
        },
        {
          "name": "المتبقي (ج.م)",
          "kind": "money",
          "width": 17,
          "numberFormat": "#,##0.00",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": "due"
        },
        {
          "name": "حالة الدفع",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "مدفوع",
            "جزئي",
            "غير مدفوع"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الحالة",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "فعّالة",
            "ملغاة"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "سبب الإلغاء",
          "kind": "long",
          "width": 34,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "ملاحظات",
          "kind": "long",
          "width": 34,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "تاريخ الإنشاء الفعلي",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "أنشأها",
          "kind": "text",
          "width": 20,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "آخر تعديل",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "عدّلها",
          "kind": "text",
          "width": 20,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الإصدار",
          "kind": "int",
          "width": 12,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": true,
          "emphasis": null
        },
        {
          "name": "مفتاح عدم التكرار",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": true,
          "emphasis": null
        }
      ]
    },
    {
      "key": "packaging",
      "title": "مشتريات التعبئة",
      "description": "عمليات شراء مواد التعبئة. المسودة لا تدخل الإجماليات المعتمدة. «تكلفة متأخرة» تعني أنها أُضيفت بعد تقفيل البراد.",
      "tabColor": "#1F6B2C",
      "freezeColumns": 3,
      "columns": [
        {
          "name": "المعرّف",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "رقم الشراء",
          "kind": "text",
          "width": 13,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "المورد",
          "kind": "text",
          "width": 22,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "رقم الفاتورة",
          "kind": "text",
          "width": 14,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "تاريخ ووقت الشراء",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "معرّف البراد",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "رقم البراد",
          "kind": "int",
          "width": 11,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الحالة",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "مسودة",
            "معتمد",
            "ملغى"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "عدد العناصر",
          "kind": "int",
          "width": 12,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "عناصر غير مكتملة",
          "kind": "int",
          "width": 14,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "إجمالي العناصر المكتملة (ج.م)",
          "kind": "money",
          "width": 17,
          "numberFormat": "#,##0.00",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": "bold"
        },
        {
          "name": "المدفوع (ج.م)",
          "kind": "money",
          "width": 17,
          "numberFormat": "#,##0.00",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": "paid"
        },
        {
          "name": "المتبقي (ج.م)",
          "kind": "money",
          "width": 17,
          "numberFormat": "#,##0.00",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": "due"
        },
        {
          "name": "تكلفة متأخرة",
          "kind": "bool",
          "width": 13,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "نعم",
            "لا"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "ملاحظات",
          "kind": "long",
          "width": 34,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "تاريخ الإنشاء",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "أنشأه",
          "kind": "text",
          "width": 20,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "آخر تعديل",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الإصدار",
          "kind": "int",
          "width": 12,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": true,
          "emphasis": null
        },
        {
          "name": "مفتاح عدم التكرار",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": true,
          "emphasis": null
        }
      ]
    },
    {
      "key": "packaging_items",
      "title": "تفاصيل التعبئة",
      "description": "العناصر داخل كل شراء تعبئة. الإجمالي = الكمية × السعر المفرد. الخانة الفارغة تعني «غير مكتمل» وليست صفرًا.",
      "tabColor": "#1F6B2C",
      "freezeColumns": 4,
      "columns": [
        {
          "name": "المعرّف",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "معرّف الشراء",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "رقم الشراء",
          "kind": "text",
          "width": 13,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الصنف",
          "kind": "text",
          "width": 22,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الكمية",
          "kind": "int",
          "width": 12,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الوحدة",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "قطعة",
            "رزمة",
            "لفة",
            "رول",
            "كرتونة",
            "كغ"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "السعر المفرد (ج.م)",
          "kind": "money",
          "width": 15,
          "numberFormat": "#,##0.00",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الإجمالي (ج.م)",
          "kind": "money",
          "width": 17,
          "numberFormat": "#,##0.00",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": "bold"
        },
        {
          "name": "الحالة",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "مكتمل",
            "غير مكتمل",
            "محذوف"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "ملاحظات",
          "kind": "long",
          "width": 34,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "آخر تعديل",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الإصدار",
          "kind": "int",
          "width": 12,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": true,
          "emphasis": null
        }
      ]
    },
    {
      "key": "payments",
      "title": "المدفوعات",
      "description": "كل دفعة سجل مستقل مرتبط بعملية شراء. إجمالي المدفوع في كل التقارير = مجموع الدفعات الفعّالة هنا.",
      "tabColor": "#1F6B2C",
      "freezeColumns": 4,
      "columns": [
        {
          "name": "المعرّف",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "رقم الدفعة",
          "kind": "text",
          "width": 13,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "نوع المستفيد",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "مزارع",
            "مورد"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "اسم المستفيد",
          "kind": "text",
          "width": 24,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "معرّف المستفيد",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "نوع العملية",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "شراء رمان",
            "شراء تعبئة"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "معرّف العملية",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "معرّف البراد",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "رقم البراد",
          "kind": "int",
          "width": 11,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "المبلغ (ج.م)",
          "kind": "money",
          "width": 17,
          "numberFormat": "#,##0.00",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": "paid"
        },
        {
          "name": "طريقة الدفع",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "نقدًا",
            "تحويل بنكي",
            "محفظة إلكترونية"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "تاريخ الدفعة",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الحالة",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "فعّالة",
            "ملغاة"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "سبب الإلغاء",
          "kind": "long",
          "width": 34,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "ملاحظات",
          "kind": "long",
          "width": 34,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "تاريخ الإنشاء",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "أنشأها",
          "kind": "text",
          "width": 20,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الإصدار",
          "kind": "int",
          "width": 12,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": true,
          "emphasis": null
        },
        {
          "name": "مفتاح عدم التكرار",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": true,
          "emphasis": null
        }
      ]
    },
    {
      "key": "users",
      "title": "المستخدمون",
      "description": "الحسابات المسموح لها فقط. يعدّلها المدير من داخل التطبيق، والخادم يتحقق منها مع كل طلب.",
      "tabColor": "#1C1714",
      "freezeColumns": 3,
      "columns": [
        {
          "name": "المعرّف",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "البريد (Gmail)",
          "kind": "email",
          "width": 32,
          "numberFormat": "@",
          "align": "left",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الاسم",
          "kind": "text",
          "width": 20,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الدور",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "مدير",
            "موظف إدخال",
            "مشاهدة فقط"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الحالة",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "نشط",
            "معطّل"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "إضافة المزارعين",
          "kind": "bool",
          "width": 13,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "نعم",
            "لا"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "تسجيل المشتريات",
          "kind": "bool",
          "width": 13,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "نعم",
            "لا"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "تعديل عمليات الآخرين",
          "kind": "bool",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "نعم",
            "لا"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "تسجيل المدفوعات",
          "kind": "bool",
          "width": 13,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "نعم",
            "لا"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "مشتريات التعبئة",
          "kind": "bool",
          "width": 13,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "نعم",
            "لا"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "تقفيل البرادات",
          "kind": "bool",
          "width": 13,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "نعم",
            "لا"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "تاريخ الإضافة",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "أضافه",
          "kind": "text",
          "width": 20,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "آخر تعديل",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الإصدار",
          "kind": "int",
          "width": 12,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": true,
          "emphasis": null
        }
      ]
    },
    {
      "key": "settings",
      "title": "الإعدادات",
      "description": "إعدادات العمل غير السرية فقط. لا تُكتب هنا أي كلمات مرور أو مفاتيح.",
      "tabColor": "#1C1714",
      "freezeColumns": 1,
      "columns": [
        {
          "name": "المفتاح",
          "kind": "text",
          "width": 28,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "القيمة",
          "kind": "text",
          "width": 34,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الوصف",
          "kind": "long",
          "width": 60,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        }
      ]
    },
    {
      "key": "item_types",
      "title": "أصناف التعبئة",
      "description": "قائمة أصناف مواد التعبئة ووحداتها الافتراضية. يضيف المدير أصنافًا جديدة من التطبيق.",
      "tabColor": "#1F6B2C",
      "freezeColumns": 2,
      "columns": [
        {
          "name": "المعرّف",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الصنف",
          "kind": "text",
          "width": 26,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الوحدة الافتراضية",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "قطعة",
            "رزمة",
            "لفة",
            "رول",
            "كرتونة",
            "كغ"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الترتيب",
          "kind": "int",
          "width": 12,
          "numberFormat": "#,##0",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "نشط",
          "kind": "bool",
          "width": 13,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "نعم",
            "لا"
          ],
          "hidden": false,
          "emphasis": null
        }
      ]
    },
    {
      "key": "audit",
      "title": "سجل التعديلات",
      "description": "كل إنشاء وتعديل وإلغاء وتقفيل وإعادة فتح يُسجَّل هنا تلقائيًا ولا يُحذف.",
      "tabColor": "#1C1714",
      "freezeColumns": 2,
      "columns": [
        {
          "name": "المعرّف",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "التاريخ والوقت",
          "kind": "dt",
          "width": 20,
          "numberFormat": "yyyy-mm-dd  hh:mm",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "المستخدم",
          "kind": "text",
          "width": 18,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الإجراء",
          "kind": "enum",
          "width": 16,
          "numberFormat": "@",
          "align": "center",
          "options": [
            "إنشاء",
            "تعديل",
            "إلغاء",
            "تقفيل",
            "إعادة فتح",
            "دفعة"
          ],
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "نوع السجل",
          "kind": "text",
          "width": 16,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "معرّف السجل",
          "kind": "id",
          "width": 15,
          "numberFormat": "@",
          "align": "center",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "الوصف",
          "kind": "long",
          "width": 46,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "القيم السابقة",
          "kind": "long",
          "width": 34,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "القيم الجديدة",
          "kind": "long",
          "width": 34,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        },
        {
          "name": "السبب",
          "kind": "long",
          "width": 34,
          "numberFormat": "@",
          "align": "right",
          "options": null,
          "hidden": false,
          "emphasis": null
        }
      ]
    }
  ]
};

const BASE_ROWS = {
  "settings": [
    [
      "اسم النشاط",
      "حاسبة الحسناوي",
      "يظهر في التقارير وملفات PDF."
    ],
    [
      "العملة",
      "جنيه مصري (EGP)",
      "عملة كل المبالغ."
    ],
    [
      "رمز العملة",
      "ج.م",
      "يظهر بجانب المبالغ."
    ],
    [
      "المنطقة الزمنية",
      "Africa/Cairo",
      "تُحسب التواريخ والأوقات على توقيت القاهرة."
    ],
    [
      "منازل المبالغ",
      2,
      "عدد المنازل العشرية عند عرض المبالغ."
    ],
    [
      "منازل الأوزان",
      1,
      "عدد المنازل العشرية عند عرض الأوزان."
    ],
    [
      "وزن الصندوق الفارغ (كغ)",
      1.9,
      "يُطرح من أوزان العينة إذا وُزنت مع الصندوق."
    ],
    [
      "سياسة التقريب",
      "قيمة كل عملية تُقرَّب لأقرب قرش (النصف للأعلى)، والإجماليات مجموع القيم المقرّبة.",
      "تضمن تطابق إجماليات العمليات والتقارير."
    ],
    [
      "بداية الموسم",
      "2026-08-01",
      "تبدأ منه فترة «هذا الموسم» في لوحة التحكم."
    ],
    [
      "صف العناوين",
      3,
      "رقم صف أسماء الأعمدة في كل صفحة. لا تغيّره."
    ],
    [
      "إصدار المخطط",
      1,
      "يزيد عند تغيير أعمدة الصفحات."
    ]
  ],
  "item_types": [
    [
      "IT-01",
      "الصناديق",
      "قطعة",
      1,
      "نعم"
    ],
    [
      "IT-02",
      "الباليتات",
      "قطعة",
      2,
      "نعم"
    ],
    [
      "IT-03",
      "الشمبر",
      "رزمة",
      3,
      "نعم"
    ],
    [
      "IT-04",
      "جزاري «ورق الفاصل»",
      "رزمة",
      4,
      "نعم"
    ],
    [
      "IT-05",
      "المناديل",
      "كرتونة",
      5,
      "نعم"
    ],
    [
      "IT-06",
      "غطاء باليت",
      "قطعة",
      6,
      "نعم"
    ],
    [
      "IT-07",
      "الملصقات",
      "رول",
      7,
      "نعم"
    ],
    [
      "IT-08",
      "جهاز تجسس",
      "قطعة",
      8,
      "نعم"
    ],
    [
      "IT-09",
      "السترتش",
      "لفة",
      9,
      "نعم"
    ]
  ]
};

const VALUE_STYLES = {"مفتوح": ["E5F1E9", "1F6B2C", false], "مقفّل": ["EEE9E2", "4A423C", false], "مسودة": ["FDF0D5", "8A4B00", false], "معتمد": ["E5F1E9", "1F6B2C", false], "ملغى": ["EEE9E2", "6F655D", true], "ملغاة": ["EEE9E2", "6F655D", true], "فعّالة": ["E5F1E9", "1F6B2C", false], "مدفوع": ["E5F1E9", "1F6B2C", false], "جزئي": ["FDF0D5", "8A4B00", false], "غير مدفوع": ["FBE9EC", "A00B1E", false], "مكتمل": ["E5F1E9", "1F6B2C", false], "غير مكتمل": ["FDF0D5", "8A4B00", false], "محذوف": ["EEE9E2", "6F655D", true], "نشط": ["E5F1E9", "1F6B2C", false], "معطّل": ["EEE9E2", "4A423C", false], "موقوف": ["EEE9E2", "4A423C", false], "نعم": ["E5F1E9", "1F6B2C", false], "لا": ["EEE9E2", "6F655D", false], "مدير": ["FBE9EC", "A00B1E", false], "موظف إدخال": ["E6EEF8", "1D4F91", false], "مشاهدة فقط": ["EEE9E2", "4A423C", false], "مباشر": ["EEE9E2", "4A423C", false], "عينة": ["E6EEF8", "1D4F91", false], "مزارع": ["FBE9EC", "A00B1E", false], "مورد": ["E5F1E9", "1F6B2C", false], "شراء رمان": ["FBE9EC", "A00B1E", false], "شراء تعبئة": ["E5F1E9", "1F6B2C", false], "إنشاء": ["E5F1E9", "1F6B2C", false], "تعديل": ["E6EEF8", "1D4F91", false], "إلغاء": ["EEE9E2", "4A423C", false], "تقفيل": ["FBE9EC", "A00B1E", false], "إعادة فتح": ["FDF0D5", "8A4B00", false], "دفعة": ["E5F1E9", "1F6B2C", false]};

const SUMMARY = {
  "cards": [
    [
      [
        "برادات مقفّلة ومحمّلة",
        "=COUNTIF('البرادات'!$G$4:$G$3000,\"مقفّل\")",
        "#,##0",
        "plain"
      ],
      [
        "برادات مفتوحة",
        "=COUNTIF('البرادات'!$G$4:$G$3000,\"مفتوح\")",
        "#,##0",
        "plain"
      ],
      [
        "مزارعون مختلفون",
        "=SUMPRODUCT(('مشتريات الرمان'!$D$4:$D$1500<>\"\")*('مشتريات الرمان'!$R$4:$R$1500=\"فعّالة\")/COUNTIFS('مشتريات الرمان'!$D$4:$D$1500,'مشتريات الرمان'!$D$4:$D$1500&\"\",'مشتريات الرمان'!$R$4:$R$1500,'مشتريات الرمان'!$R$4:$R$1500&\"\"))",
        "#,##0",
        "plain"
      ],
      [
        "عمليات شراء الرمان",
        "=COUNTIFS('مشتريات الرمان'!$A$4:$A$3000,\"<>\",'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\")",
        "#,##0",
        "plain"
      ],
      [
        "إجمالي الصناديق",
        "=SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\")",
        "#,##0",
        "plain"
      ]
    ],
    [
      [
        "إجمالي الوزن (كغ)",
        "=SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\")",
        "#,##0.0",
        "plain"
      ],
      [
        "قيمة شراء الرمان (ج.م)",
        "=SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\")",
        "#,##0.00",
        "value"
      ],
      [
        "مشتريات التعبئة المعتمدة (ج.م)",
        "=SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\")",
        "#,##0.00",
        "value"
      ],
      [
        "المدفوع فعليًا (ج.م)",
        "=SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$M$4:$M$3000,\"فعّالة\")",
        "#,##0.00",
        "paid"
      ],
      [
        "المتبقي (ج.م)",
        "=D8+F8-H8",
        "#,##0.00",
        "due"
      ]
    ],
    [
      [
        "متوسط سعر الكيلو (ج.م)",
        "=IFERROR(D8/B8,0)",
        "#,##0.00",
        "plain"
      ],
      [
        "المتبقي للمزارعين (ج.م)",
        "=D8-(SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$M$4:$M$3000,\"فعّالة\",'المدفوعات'!$F$4:$F$3000,\"شراء رمان\"))",
        "#,##0.00",
        "due"
      ],
      [
        "المتبقي للموردين (ج.م)",
        "=F8-(SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$M$4:$M$3000,\"فعّالة\",'المدفوعات'!$F$4:$F$3000,\"شراء تعبئة\"))",
        "#,##0.00",
        "due"
      ]
    ]
  ],
  "cardRow": 4,
  "tableTitleRow": 14,
  "tableFirstRow": 16,
  "tableHeads": [
    "رقم البراد",
    "الاسم",
    "الحالة",
    "عدد العمليات",
    "الصناديق",
    "الوزن (كغ)",
    "قيمة الرمان (ج.م)",
    "المدفوع للمزارعين (ج.م)",
    "المتبقي للمزارعين (ج.م)",
    "التعبئة المعتمدة (ج.م)",
    "إجمالي التكلفة (ج.م)"
  ],
  "tableFormats": [
    "0",
    "@",
    "@",
    "#,##0",
    "#,##0",
    "#,##0.0",
    "#,##0.00",
    "#,##0.00",
    "#,##0.00",
    "#,##0.00",
    "#,##0.00"
  ],
  "tableRows": [
    [
      "=IF('البرادات'!$B4=\"\",\"\",'البرادات'!$B4)",
      "=IF('البرادات'!$B4=\"\",\"\",'البرادات'!$C4)",
      "=IF('البرادات'!$B4=\"\",\"\",'البرادات'!$G4)",
      "=IF('البرادات'!$B4=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A4,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B4=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A4,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B4=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A4,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B4=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A4,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B4=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A4,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B4=\"\",\"\",H16-I16)",
      "=IF('البرادات'!$B4=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A4,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B4=\"\",\"\",H16+K16)"
    ],
    [
      "=IF('البرادات'!$B5=\"\",\"\",'البرادات'!$B5)",
      "=IF('البرادات'!$B5=\"\",\"\",'البرادات'!$C5)",
      "=IF('البرادات'!$B5=\"\",\"\",'البرادات'!$G5)",
      "=IF('البرادات'!$B5=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A5,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B5=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A5,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B5=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A5,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B5=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A5,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B5=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A5,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B5=\"\",\"\",H17-I17)",
      "=IF('البرادات'!$B5=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A5,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B5=\"\",\"\",H17+K17)"
    ],
    [
      "=IF('البرادات'!$B6=\"\",\"\",'البرادات'!$B6)",
      "=IF('البرادات'!$B6=\"\",\"\",'البرادات'!$C6)",
      "=IF('البرادات'!$B6=\"\",\"\",'البرادات'!$G6)",
      "=IF('البرادات'!$B6=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A6,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B6=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A6,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B6=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A6,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B6=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A6,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B6=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A6,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B6=\"\",\"\",H18-I18)",
      "=IF('البرادات'!$B6=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A6,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B6=\"\",\"\",H18+K18)"
    ],
    [
      "=IF('البرادات'!$B7=\"\",\"\",'البرادات'!$B7)",
      "=IF('البرادات'!$B7=\"\",\"\",'البرادات'!$C7)",
      "=IF('البرادات'!$B7=\"\",\"\",'البرادات'!$G7)",
      "=IF('البرادات'!$B7=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A7,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B7=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A7,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B7=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A7,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B7=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A7,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B7=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A7,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B7=\"\",\"\",H19-I19)",
      "=IF('البرادات'!$B7=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A7,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B7=\"\",\"\",H19+K19)"
    ],
    [
      "=IF('البرادات'!$B8=\"\",\"\",'البرادات'!$B8)",
      "=IF('البرادات'!$B8=\"\",\"\",'البرادات'!$C8)",
      "=IF('البرادات'!$B8=\"\",\"\",'البرادات'!$G8)",
      "=IF('البرادات'!$B8=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A8,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B8=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A8,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B8=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A8,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B8=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A8,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B8=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A8,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B8=\"\",\"\",H20-I20)",
      "=IF('البرادات'!$B8=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A8,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B8=\"\",\"\",H20+K20)"
    ],
    [
      "=IF('البرادات'!$B9=\"\",\"\",'البرادات'!$B9)",
      "=IF('البرادات'!$B9=\"\",\"\",'البرادات'!$C9)",
      "=IF('البرادات'!$B9=\"\",\"\",'البرادات'!$G9)",
      "=IF('البرادات'!$B9=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A9,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B9=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A9,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B9=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A9,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B9=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A9,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B9=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A9,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B9=\"\",\"\",H21-I21)",
      "=IF('البرادات'!$B9=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A9,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B9=\"\",\"\",H21+K21)"
    ],
    [
      "=IF('البرادات'!$B10=\"\",\"\",'البرادات'!$B10)",
      "=IF('البرادات'!$B10=\"\",\"\",'البرادات'!$C10)",
      "=IF('البرادات'!$B10=\"\",\"\",'البرادات'!$G10)",
      "=IF('البرادات'!$B10=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A10,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B10=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A10,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B10=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A10,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B10=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A10,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B10=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A10,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B10=\"\",\"\",H22-I22)",
      "=IF('البرادات'!$B10=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A10,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B10=\"\",\"\",H22+K22)"
    ],
    [
      "=IF('البرادات'!$B11=\"\",\"\",'البرادات'!$B11)",
      "=IF('البرادات'!$B11=\"\",\"\",'البرادات'!$C11)",
      "=IF('البرادات'!$B11=\"\",\"\",'البرادات'!$G11)",
      "=IF('البرادات'!$B11=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A11,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B11=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A11,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B11=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A11,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B11=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A11,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B11=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A11,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B11=\"\",\"\",H23-I23)",
      "=IF('البرادات'!$B11=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A11,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B11=\"\",\"\",H23+K23)"
    ],
    [
      "=IF('البرادات'!$B12=\"\",\"\",'البرادات'!$B12)",
      "=IF('البرادات'!$B12=\"\",\"\",'البرادات'!$C12)",
      "=IF('البرادات'!$B12=\"\",\"\",'البرادات'!$G12)",
      "=IF('البرادات'!$B12=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A12,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B12=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A12,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B12=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A12,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B12=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A12,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B12=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A12,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B12=\"\",\"\",H24-I24)",
      "=IF('البرادات'!$B12=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A12,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B12=\"\",\"\",H24+K24)"
    ],
    [
      "=IF('البرادات'!$B13=\"\",\"\",'البرادات'!$B13)",
      "=IF('البرادات'!$B13=\"\",\"\",'البرادات'!$C13)",
      "=IF('البرادات'!$B13=\"\",\"\",'البرادات'!$G13)",
      "=IF('البرادات'!$B13=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A13,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B13=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A13,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B13=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A13,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B13=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A13,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B13=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A13,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B13=\"\",\"\",H25-I25)",
      "=IF('البرادات'!$B13=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A13,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B13=\"\",\"\",H25+K25)"
    ],
    [
      "=IF('البرادات'!$B14=\"\",\"\",'البرادات'!$B14)",
      "=IF('البرادات'!$B14=\"\",\"\",'البرادات'!$C14)",
      "=IF('البرادات'!$B14=\"\",\"\",'البرادات'!$G14)",
      "=IF('البرادات'!$B14=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A14,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B14=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A14,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B14=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A14,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B14=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A14,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B14=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A14,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B14=\"\",\"\",H26-I26)",
      "=IF('البرادات'!$B14=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A14,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B14=\"\",\"\",H26+K26)"
    ],
    [
      "=IF('البرادات'!$B15=\"\",\"\",'البرادات'!$B15)",
      "=IF('البرادات'!$B15=\"\",\"\",'البرادات'!$C15)",
      "=IF('البرادات'!$B15=\"\",\"\",'البرادات'!$G15)",
      "=IF('البرادات'!$B15=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A15,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B15=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A15,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B15=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A15,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B15=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A15,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B15=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A15,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B15=\"\",\"\",H27-I27)",
      "=IF('البرادات'!$B15=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A15,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B15=\"\",\"\",H27+K27)"
    ],
    [
      "=IF('البرادات'!$B16=\"\",\"\",'البرادات'!$B16)",
      "=IF('البرادات'!$B16=\"\",\"\",'البرادات'!$C16)",
      "=IF('البرادات'!$B16=\"\",\"\",'البرادات'!$G16)",
      "=IF('البرادات'!$B16=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A16,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B16=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A16,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B16=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A16,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B16=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A16,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B16=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A16,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B16=\"\",\"\",H28-I28)",
      "=IF('البرادات'!$B16=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A16,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B16=\"\",\"\",H28+K28)"
    ],
    [
      "=IF('البرادات'!$B17=\"\",\"\",'البرادات'!$B17)",
      "=IF('البرادات'!$B17=\"\",\"\",'البرادات'!$C17)",
      "=IF('البرادات'!$B17=\"\",\"\",'البرادات'!$G17)",
      "=IF('البرادات'!$B17=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A17,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B17=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A17,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B17=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A17,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B17=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A17,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B17=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A17,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B17=\"\",\"\",H29-I29)",
      "=IF('البرادات'!$B17=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A17,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B17=\"\",\"\",H29+K29)"
    ],
    [
      "=IF('البرادات'!$B18=\"\",\"\",'البرادات'!$B18)",
      "=IF('البرادات'!$B18=\"\",\"\",'البرادات'!$C18)",
      "=IF('البرادات'!$B18=\"\",\"\",'البرادات'!$G18)",
      "=IF('البرادات'!$B18=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A18,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B18=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A18,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B18=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A18,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B18=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A18,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B18=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A18,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B18=\"\",\"\",H30-I30)",
      "=IF('البرادات'!$B18=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A18,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B18=\"\",\"\",H30+K30)"
    ],
    [
      "=IF('البرادات'!$B19=\"\",\"\",'البرادات'!$B19)",
      "=IF('البرادات'!$B19=\"\",\"\",'البرادات'!$C19)",
      "=IF('البرادات'!$B19=\"\",\"\",'البرادات'!$G19)",
      "=IF('البرادات'!$B19=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A19,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B19=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A19,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B19=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A19,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B19=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A19,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B19=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A19,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B19=\"\",\"\",H31-I31)",
      "=IF('البرادات'!$B19=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A19,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B19=\"\",\"\",H31+K31)"
    ],
    [
      "=IF('البرادات'!$B20=\"\",\"\",'البرادات'!$B20)",
      "=IF('البرادات'!$B20=\"\",\"\",'البرادات'!$C20)",
      "=IF('البرادات'!$B20=\"\",\"\",'البرادات'!$G20)",
      "=IF('البرادات'!$B20=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A20,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B20=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A20,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B20=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A20,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B20=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A20,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B20=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A20,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B20=\"\",\"\",H32-I32)",
      "=IF('البرادات'!$B20=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A20,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B20=\"\",\"\",H32+K32)"
    ],
    [
      "=IF('البرادات'!$B21=\"\",\"\",'البرادات'!$B21)",
      "=IF('البرادات'!$B21=\"\",\"\",'البرادات'!$C21)",
      "=IF('البرادات'!$B21=\"\",\"\",'البرادات'!$G21)",
      "=IF('البرادات'!$B21=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A21,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B21=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A21,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B21=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A21,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B21=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A21,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B21=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A21,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B21=\"\",\"\",H33-I33)",
      "=IF('البرادات'!$B21=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A21,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B21=\"\",\"\",H33+K33)"
    ],
    [
      "=IF('البرادات'!$B22=\"\",\"\",'البرادات'!$B22)",
      "=IF('البرادات'!$B22=\"\",\"\",'البرادات'!$C22)",
      "=IF('البرادات'!$B22=\"\",\"\",'البرادات'!$G22)",
      "=IF('البرادات'!$B22=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A22,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B22=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A22,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B22=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A22,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B22=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A22,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B22=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A22,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B22=\"\",\"\",H34-I34)",
      "=IF('البرادات'!$B22=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A22,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B22=\"\",\"\",H34+K34)"
    ],
    [
      "=IF('البرادات'!$B23=\"\",\"\",'البرادات'!$B23)",
      "=IF('البرادات'!$B23=\"\",\"\",'البرادات'!$C23)",
      "=IF('البرادات'!$B23=\"\",\"\",'البرادات'!$G23)",
      "=IF('البرادات'!$B23=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A23,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B23=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A23,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B23=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A23,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B23=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A23,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B23=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A23,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B23=\"\",\"\",H35-I35)",
      "=IF('البرادات'!$B23=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A23,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B23=\"\",\"\",H35+K35)"
    ],
    [
      "=IF('البرادات'!$B24=\"\",\"\",'البرادات'!$B24)",
      "=IF('البرادات'!$B24=\"\",\"\",'البرادات'!$C24)",
      "=IF('البرادات'!$B24=\"\",\"\",'البرادات'!$G24)",
      "=IF('البرادات'!$B24=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A24,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B24=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A24,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B24=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A24,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B24=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A24,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B24=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A24,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B24=\"\",\"\",H36-I36)",
      "=IF('البرادات'!$B24=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A24,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B24=\"\",\"\",H36+K36)"
    ],
    [
      "=IF('البرادات'!$B25=\"\",\"\",'البرادات'!$B25)",
      "=IF('البرادات'!$B25=\"\",\"\",'البرادات'!$C25)",
      "=IF('البرادات'!$B25=\"\",\"\",'البرادات'!$G25)",
      "=IF('البرادات'!$B25=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A25,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B25=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A25,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B25=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A25,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B25=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A25,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B25=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A25,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B25=\"\",\"\",H37-I37)",
      "=IF('البرادات'!$B25=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A25,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B25=\"\",\"\",H37+K37)"
    ],
    [
      "=IF('البرادات'!$B26=\"\",\"\",'البرادات'!$B26)",
      "=IF('البرادات'!$B26=\"\",\"\",'البرادات'!$C26)",
      "=IF('البرادات'!$B26=\"\",\"\",'البرادات'!$G26)",
      "=IF('البرادات'!$B26=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A26,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B26=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A26,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B26=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A26,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B26=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A26,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B26=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A26,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B26=\"\",\"\",H38-I38)",
      "=IF('البرادات'!$B26=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A26,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B26=\"\",\"\",H38+K38)"
    ],
    [
      "=IF('البرادات'!$B27=\"\",\"\",'البرادات'!$B27)",
      "=IF('البرادات'!$B27=\"\",\"\",'البرادات'!$C27)",
      "=IF('البرادات'!$B27=\"\",\"\",'البرادات'!$G27)",
      "=IF('البرادات'!$B27=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A27,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B27=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A27,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B27=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A27,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B27=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A27,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B27=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A27,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B27=\"\",\"\",H39-I39)",
      "=IF('البرادات'!$B27=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A27,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B27=\"\",\"\",H39+K39)"
    ],
    [
      "=IF('البرادات'!$B28=\"\",\"\",'البرادات'!$B28)",
      "=IF('البرادات'!$B28=\"\",\"\",'البرادات'!$C28)",
      "=IF('البرادات'!$B28=\"\",\"\",'البرادات'!$G28)",
      "=IF('البرادات'!$B28=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A28,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B28=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A28,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B28=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A28,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B28=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A28,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B28=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A28,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B28=\"\",\"\",H40-I40)",
      "=IF('البرادات'!$B28=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A28,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B28=\"\",\"\",H40+K40)"
    ],
    [
      "=IF('البرادات'!$B29=\"\",\"\",'البرادات'!$B29)",
      "=IF('البرادات'!$B29=\"\",\"\",'البرادات'!$C29)",
      "=IF('البرادات'!$B29=\"\",\"\",'البرادات'!$G29)",
      "=IF('البرادات'!$B29=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A29,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B29=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A29,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B29=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A29,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B29=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A29,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B29=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A29,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B29=\"\",\"\",H41-I41)",
      "=IF('البرادات'!$B29=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A29,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B29=\"\",\"\",H41+K41)"
    ],
    [
      "=IF('البرادات'!$B30=\"\",\"\",'البرادات'!$B30)",
      "=IF('البرادات'!$B30=\"\",\"\",'البرادات'!$C30)",
      "=IF('البرادات'!$B30=\"\",\"\",'البرادات'!$G30)",
      "=IF('البرادات'!$B30=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A30,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B30=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A30,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B30=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A30,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B30=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A30,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B30=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A30,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B30=\"\",\"\",H42-I42)",
      "=IF('البرادات'!$B30=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A30,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B30=\"\",\"\",H42+K42)"
    ],
    [
      "=IF('البرادات'!$B31=\"\",\"\",'البرادات'!$B31)",
      "=IF('البرادات'!$B31=\"\",\"\",'البرادات'!$C31)",
      "=IF('البرادات'!$B31=\"\",\"\",'البرادات'!$G31)",
      "=IF('البرادات'!$B31=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A31,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B31=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A31,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B31=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A31,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B31=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A31,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B31=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A31,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B31=\"\",\"\",H43-I43)",
      "=IF('البرادات'!$B31=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A31,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B31=\"\",\"\",H43+K43)"
    ],
    [
      "=IF('البرادات'!$B32=\"\",\"\",'البرادات'!$B32)",
      "=IF('البرادات'!$B32=\"\",\"\",'البرادات'!$C32)",
      "=IF('البرادات'!$B32=\"\",\"\",'البرادات'!$G32)",
      "=IF('البرادات'!$B32=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A32,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B32=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A32,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B32=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A32,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B32=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A32,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B32=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A32,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B32=\"\",\"\",H44-I44)",
      "=IF('البرادات'!$B32=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A32,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B32=\"\",\"\",H44+K44)"
    ],
    [
      "=IF('البرادات'!$B33=\"\",\"\",'البرادات'!$B33)",
      "=IF('البرادات'!$B33=\"\",\"\",'البرادات'!$C33)",
      "=IF('البرادات'!$B33=\"\",\"\",'البرادات'!$G33)",
      "=IF('البرادات'!$B33=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A33,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B33=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A33,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B33=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A33,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B33=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A33,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B33=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A33,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B33=\"\",\"\",H45-I45)",
      "=IF('البرادات'!$B33=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A33,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B33=\"\",\"\",H45+K45)"
    ],
    [
      "=IF('البرادات'!$B34=\"\",\"\",'البرادات'!$B34)",
      "=IF('البرادات'!$B34=\"\",\"\",'البرادات'!$C34)",
      "=IF('البرادات'!$B34=\"\",\"\",'البرادات'!$G34)",
      "=IF('البرادات'!$B34=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A34,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B34=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A34,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B34=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A34,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B34=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A34,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B34=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A34,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B34=\"\",\"\",H46-I46)",
      "=IF('البرادات'!$B34=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A34,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B34=\"\",\"\",H46+K46)"
    ],
    [
      "=IF('البرادات'!$B35=\"\",\"\",'البرادات'!$B35)",
      "=IF('البرادات'!$B35=\"\",\"\",'البرادات'!$C35)",
      "=IF('البرادات'!$B35=\"\",\"\",'البرادات'!$G35)",
      "=IF('البرادات'!$B35=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A35,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B35=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A35,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B35=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A35,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B35=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A35,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B35=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A35,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B35=\"\",\"\",H47-I47)",
      "=IF('البرادات'!$B35=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A35,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B35=\"\",\"\",H47+K47)"
    ],
    [
      "=IF('البرادات'!$B36=\"\",\"\",'البرادات'!$B36)",
      "=IF('البرادات'!$B36=\"\",\"\",'البرادات'!$C36)",
      "=IF('البرادات'!$B36=\"\",\"\",'البرادات'!$G36)",
      "=IF('البرادات'!$B36=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A36,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B36=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A36,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B36=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A36,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B36=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A36,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B36=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A36,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B36=\"\",\"\",H48-I48)",
      "=IF('البرادات'!$B36=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A36,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B36=\"\",\"\",H48+K48)"
    ],
    [
      "=IF('البرادات'!$B37=\"\",\"\",'البرادات'!$B37)",
      "=IF('البرادات'!$B37=\"\",\"\",'البرادات'!$C37)",
      "=IF('البرادات'!$B37=\"\",\"\",'البرادات'!$G37)",
      "=IF('البرادات'!$B37=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A37,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B37=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A37,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B37=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A37,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B37=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A37,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B37=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A37,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B37=\"\",\"\",H49-I49)",
      "=IF('البرادات'!$B37=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A37,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B37=\"\",\"\",H49+K49)"
    ],
    [
      "=IF('البرادات'!$B38=\"\",\"\",'البرادات'!$B38)",
      "=IF('البرادات'!$B38=\"\",\"\",'البرادات'!$C38)",
      "=IF('البرادات'!$B38=\"\",\"\",'البرادات'!$G38)",
      "=IF('البرادات'!$B38=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A38,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B38=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A38,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B38=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A38,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B38=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A38,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B38=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A38,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B38=\"\",\"\",H50-I50)",
      "=IF('البرادات'!$B38=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A38,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B38=\"\",\"\",H50+K50)"
    ],
    [
      "=IF('البرادات'!$B39=\"\",\"\",'البرادات'!$B39)",
      "=IF('البرادات'!$B39=\"\",\"\",'البرادات'!$C39)",
      "=IF('البرادات'!$B39=\"\",\"\",'البرادات'!$G39)",
      "=IF('البرادات'!$B39=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A39,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B39=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A39,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B39=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A39,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B39=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A39,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B39=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A39,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B39=\"\",\"\",H51-I51)",
      "=IF('البرادات'!$B39=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A39,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B39=\"\",\"\",H51+K51)"
    ],
    [
      "=IF('البرادات'!$B40=\"\",\"\",'البرادات'!$B40)",
      "=IF('البرادات'!$B40=\"\",\"\",'البرادات'!$C40)",
      "=IF('البرادات'!$B40=\"\",\"\",'البرادات'!$G40)",
      "=IF('البرادات'!$B40=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A40,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B40=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A40,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B40=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A40,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B40=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A40,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B40=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A40,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B40=\"\",\"\",H52-I52)",
      "=IF('البرادات'!$B40=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A40,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B40=\"\",\"\",H52+K52)"
    ],
    [
      "=IF('البرادات'!$B41=\"\",\"\",'البرادات'!$B41)",
      "=IF('البرادات'!$B41=\"\",\"\",'البرادات'!$C41)",
      "=IF('البرادات'!$B41=\"\",\"\",'البرادات'!$G41)",
      "=IF('البرادات'!$B41=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A41,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B41=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A41,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B41=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A41,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B41=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A41,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B41=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A41,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B41=\"\",\"\",H53-I53)",
      "=IF('البرادات'!$B41=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A41,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B41=\"\",\"\",H53+K53)"
    ],
    [
      "=IF('البرادات'!$B42=\"\",\"\",'البرادات'!$B42)",
      "=IF('البرادات'!$B42=\"\",\"\",'البرادات'!$C42)",
      "=IF('البرادات'!$B42=\"\",\"\",'البرادات'!$G42)",
      "=IF('البرادات'!$B42=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A42,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B42=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A42,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B42=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A42,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B42=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A42,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B42=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A42,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B42=\"\",\"\",H54-I54)",
      "=IF('البرادات'!$B42=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A42,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B42=\"\",\"\",H54+K54)"
    ],
    [
      "=IF('البرادات'!$B43=\"\",\"\",'البرادات'!$B43)",
      "=IF('البرادات'!$B43=\"\",\"\",'البرادات'!$C43)",
      "=IF('البرادات'!$B43=\"\",\"\",'البرادات'!$G43)",
      "=IF('البرادات'!$B43=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A43,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B43=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A43,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B43=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A43,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B43=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A43,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B43=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A43,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B43=\"\",\"\",H55-I55)",
      "=IF('البرادات'!$B43=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A43,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B43=\"\",\"\",H55+K55)"
    ],
    [
      "=IF('البرادات'!$B44=\"\",\"\",'البرادات'!$B44)",
      "=IF('البرادات'!$B44=\"\",\"\",'البرادات'!$C44)",
      "=IF('البرادات'!$B44=\"\",\"\",'البرادات'!$G44)",
      "=IF('البرادات'!$B44=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A44,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B44=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A44,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B44=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A44,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B44=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A44,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B44=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A44,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B44=\"\",\"\",H56-I56)",
      "=IF('البرادات'!$B44=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A44,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B44=\"\",\"\",H56+K56)"
    ],
    [
      "=IF('البرادات'!$B45=\"\",\"\",'البرادات'!$B45)",
      "=IF('البرادات'!$B45=\"\",\"\",'البرادات'!$C45)",
      "=IF('البرادات'!$B45=\"\",\"\",'البرادات'!$G45)",
      "=IF('البرادات'!$B45=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A45,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B45=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A45,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B45=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A45,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B45=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A45,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B45=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A45,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B45=\"\",\"\",H57-I57)",
      "=IF('البرادات'!$B45=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A45,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B45=\"\",\"\",H57+K57)"
    ],
    [
      "=IF('البرادات'!$B46=\"\",\"\",'البرادات'!$B46)",
      "=IF('البرادات'!$B46=\"\",\"\",'البرادات'!$C46)",
      "=IF('البرادات'!$B46=\"\",\"\",'البرادات'!$G46)",
      "=IF('البرادات'!$B46=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A46,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B46=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A46,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B46=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A46,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B46=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A46,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B46=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A46,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B46=\"\",\"\",H58-I58)",
      "=IF('البرادات'!$B46=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A46,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B46=\"\",\"\",H58+K58)"
    ],
    [
      "=IF('البرادات'!$B47=\"\",\"\",'البرادات'!$B47)",
      "=IF('البرادات'!$B47=\"\",\"\",'البرادات'!$C47)",
      "=IF('البرادات'!$B47=\"\",\"\",'البرادات'!$G47)",
      "=IF('البرادات'!$B47=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A47,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B47=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A47,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B47=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A47,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B47=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A47,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B47=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A47,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B47=\"\",\"\",H59-I59)",
      "=IF('البرادات'!$B47=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A47,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B47=\"\",\"\",H59+K59)"
    ],
    [
      "=IF('البرادات'!$B48=\"\",\"\",'البرادات'!$B48)",
      "=IF('البرادات'!$B48=\"\",\"\",'البرادات'!$C48)",
      "=IF('البرادات'!$B48=\"\",\"\",'البرادات'!$G48)",
      "=IF('البرادات'!$B48=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A48,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B48=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A48,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B48=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A48,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B48=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A48,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B48=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A48,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B48=\"\",\"\",H60-I60)",
      "=IF('البرادات'!$B48=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A48,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B48=\"\",\"\",H60+K60)"
    ],
    [
      "=IF('البرادات'!$B49=\"\",\"\",'البرادات'!$B49)",
      "=IF('البرادات'!$B49=\"\",\"\",'البرادات'!$C49)",
      "=IF('البرادات'!$B49=\"\",\"\",'البرادات'!$G49)",
      "=IF('البرادات'!$B49=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A49,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B49=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A49,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B49=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A49,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B49=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A49,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B49=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A49,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B49=\"\",\"\",H61-I61)",
      "=IF('البرادات'!$B49=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A49,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B49=\"\",\"\",H61+K61)"
    ],
    [
      "=IF('البرادات'!$B50=\"\",\"\",'البرادات'!$B50)",
      "=IF('البرادات'!$B50=\"\",\"\",'البرادات'!$C50)",
      "=IF('البرادات'!$B50=\"\",\"\",'البرادات'!$G50)",
      "=IF('البرادات'!$B50=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A50,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B50=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A50,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B50=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A50,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B50=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A50,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B50=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A50,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B50=\"\",\"\",H62-I62)",
      "=IF('البرادات'!$B50=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A50,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B50=\"\",\"\",H62+K62)"
    ],
    [
      "=IF('البرادات'!$B51=\"\",\"\",'البرادات'!$B51)",
      "=IF('البرادات'!$B51=\"\",\"\",'البرادات'!$C51)",
      "=IF('البرادات'!$B51=\"\",\"\",'البرادات'!$G51)",
      "=IF('البرادات'!$B51=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A51,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B51=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A51,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B51=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A51,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B51=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A51,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B51=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A51,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B51=\"\",\"\",H63-I63)",
      "=IF('البرادات'!$B51=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A51,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B51=\"\",\"\",H63+K63)"
    ],
    [
      "=IF('البرادات'!$B52=\"\",\"\",'البرادات'!$B52)",
      "=IF('البرادات'!$B52=\"\",\"\",'البرادات'!$C52)",
      "=IF('البرادات'!$B52=\"\",\"\",'البرادات'!$G52)",
      "=IF('البرادات'!$B52=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A52,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B52=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A52,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B52=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A52,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B52=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A52,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B52=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A52,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B52=\"\",\"\",H64-I64)",
      "=IF('البرادات'!$B52=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A52,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B52=\"\",\"\",H64+K64)"
    ],
    [
      "=IF('البرادات'!$B53=\"\",\"\",'البرادات'!$B53)",
      "=IF('البرادات'!$B53=\"\",\"\",'البرادات'!$C53)",
      "=IF('البرادات'!$B53=\"\",\"\",'البرادات'!$G53)",
      "=IF('البرادات'!$B53=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A53,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B53=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A53,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B53=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A53,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B53=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A53,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B53=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A53,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B53=\"\",\"\",H65-I65)",
      "=IF('البرادات'!$B53=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A53,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B53=\"\",\"\",H65+K65)"
    ],
    [
      "=IF('البرادات'!$B54=\"\",\"\",'البرادات'!$B54)",
      "=IF('البرادات'!$B54=\"\",\"\",'البرادات'!$C54)",
      "=IF('البرادات'!$B54=\"\",\"\",'البرادات'!$G54)",
      "=IF('البرادات'!$B54=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A54,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B54=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A54,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B54=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A54,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B54=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A54,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B54=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A54,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B54=\"\",\"\",H66-I66)",
      "=IF('البرادات'!$B54=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A54,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B54=\"\",\"\",H66+K66)"
    ],
    [
      "=IF('البرادات'!$B55=\"\",\"\",'البرادات'!$B55)",
      "=IF('البرادات'!$B55=\"\",\"\",'البرادات'!$C55)",
      "=IF('البرادات'!$B55=\"\",\"\",'البرادات'!$G55)",
      "=IF('البرادات'!$B55=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A55,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B55=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A55,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B55=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A55,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B55=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A55,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B55=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A55,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B55=\"\",\"\",H67-I67)",
      "=IF('البرادات'!$B55=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A55,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B55=\"\",\"\",H67+K67)"
    ],
    [
      "=IF('البرادات'!$B56=\"\",\"\",'البرادات'!$B56)",
      "=IF('البرادات'!$B56=\"\",\"\",'البرادات'!$C56)",
      "=IF('البرادات'!$B56=\"\",\"\",'البرادات'!$G56)",
      "=IF('البرادات'!$B56=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A56,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B56=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A56,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B56=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A56,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B56=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A56,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B56=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A56,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B56=\"\",\"\",H68-I68)",
      "=IF('البرادات'!$B56=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A56,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B56=\"\",\"\",H68+K68)"
    ],
    [
      "=IF('البرادات'!$B57=\"\",\"\",'البرادات'!$B57)",
      "=IF('البرادات'!$B57=\"\",\"\",'البرادات'!$C57)",
      "=IF('البرادات'!$B57=\"\",\"\",'البرادات'!$G57)",
      "=IF('البرادات'!$B57=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A57,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B57=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A57,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B57=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A57,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B57=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A57,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B57=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A57,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B57=\"\",\"\",H69-I69)",
      "=IF('البرادات'!$B57=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A57,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B57=\"\",\"\",H69+K69)"
    ],
    [
      "=IF('البرادات'!$B58=\"\",\"\",'البرادات'!$B58)",
      "=IF('البرادات'!$B58=\"\",\"\",'البرادات'!$C58)",
      "=IF('البرادات'!$B58=\"\",\"\",'البرادات'!$G58)",
      "=IF('البرادات'!$B58=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A58,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B58=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A58,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B58=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A58,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B58=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A58,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B58=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A58,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B58=\"\",\"\",H70-I70)",
      "=IF('البرادات'!$B58=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A58,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B58=\"\",\"\",H70+K70)"
    ],
    [
      "=IF('البرادات'!$B59=\"\",\"\",'البرادات'!$B59)",
      "=IF('البرادات'!$B59=\"\",\"\",'البرادات'!$C59)",
      "=IF('البرادات'!$B59=\"\",\"\",'البرادات'!$G59)",
      "=IF('البرادات'!$B59=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A59,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B59=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A59,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B59=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A59,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B59=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A59,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B59=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A59,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B59=\"\",\"\",H71-I71)",
      "=IF('البرادات'!$B59=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A59,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B59=\"\",\"\",H71+K71)"
    ],
    [
      "=IF('البرادات'!$B60=\"\",\"\",'البرادات'!$B60)",
      "=IF('البرادات'!$B60=\"\",\"\",'البرادات'!$C60)",
      "=IF('البرادات'!$B60=\"\",\"\",'البرادات'!$G60)",
      "=IF('البرادات'!$B60=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A60,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B60=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A60,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B60=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A60,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B60=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A60,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B60=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A60,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B60=\"\",\"\",H72-I72)",
      "=IF('البرادات'!$B60=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A60,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B60=\"\",\"\",H72+K72)"
    ],
    [
      "=IF('البرادات'!$B61=\"\",\"\",'البرادات'!$B61)",
      "=IF('البرادات'!$B61=\"\",\"\",'البرادات'!$C61)",
      "=IF('البرادات'!$B61=\"\",\"\",'البرادات'!$G61)",
      "=IF('البرادات'!$B61=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A61,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B61=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A61,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B61=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A61,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B61=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A61,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B61=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A61,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B61=\"\",\"\",H73-I73)",
      "=IF('البرادات'!$B61=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A61,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B61=\"\",\"\",H73+K73)"
    ],
    [
      "=IF('البرادات'!$B62=\"\",\"\",'البرادات'!$B62)",
      "=IF('البرادات'!$B62=\"\",\"\",'البرادات'!$C62)",
      "=IF('البرادات'!$B62=\"\",\"\",'البرادات'!$G62)",
      "=IF('البرادات'!$B62=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A62,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B62=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A62,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B62=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A62,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B62=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A62,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B62=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A62,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B62=\"\",\"\",H74-I74)",
      "=IF('البرادات'!$B62=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A62,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B62=\"\",\"\",H74+K74)"
    ],
    [
      "=IF('البرادات'!$B63=\"\",\"\",'البرادات'!$B63)",
      "=IF('البرادات'!$B63=\"\",\"\",'البرادات'!$C63)",
      "=IF('البرادات'!$B63=\"\",\"\",'البرادات'!$G63)",
      "=IF('البرادات'!$B63=\"\",\"\",COUNTIFS('مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A63,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B63=\"\",\"\",SUMIFS('مشتريات الرمان'!$G$4:$G$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A63,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B63=\"\",\"\",SUMIFS('مشتريات الرمان'!$L$4:$L$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A63,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B63=\"\",\"\",SUMIFS('مشتريات الرمان'!$N$4:$N$3000,'مشتريات الرمان'!$B$4:$B$3000,'البرادات'!$A63,'مشتريات الرمان'!$R$4:$R$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B63=\"\",\"\",SUMIFS('المدفوعات'!$J$4:$J$3000,'المدفوعات'!$H$4:$H$3000,'البرادات'!$A63,'المدفوعات'!$F$4:$F$3000,\"شراء رمان\",'المدفوعات'!$M$4:$M$3000,\"فعّالة\"))",
      "=IF('البرادات'!$B63=\"\",\"\",H75-I75)",
      "=IF('البرادات'!$B63=\"\",\"\",SUMIFS('مشتريات التعبئة'!$K$4:$K$3000,'مشتريات التعبئة'!$F$4:$F$3000,'البرادات'!$A63,'مشتريات التعبئة'!$H$4:$H$3000,\"معتمد\"))",
      "=IF('البرادات'!$B63=\"\",\"\",H75+K75)"
    ]
  ]
};

const FONT = 'Cairo';
const SUMMARY_TITLE = 'لوحة الملخص';
const MIN_ROWS = 1000;
const C = {
  red: '#A00B1E', redL: '#FBE9EC', green: '#1F6B2C', greenL: '#E5F1E9', ivory: '#FAF6EE',
  white: '#FFFFFF', ink: '#1C1714', ink2: '#5E554E', muted: '#6F655D', amber: '#8A4B00',
  amberL: '#FDF0D5', grayL: '#EEE9E2', line: '#E3DACC', idHead: '#3B4A3F',
};

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('حاسبة الرمان')
    .addItem('إعداد الصفحات والتنسيق', 'setupRummanSheet')
    .addToUi();
}

function setupRummanSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  ss.setSpreadsheetTimeZone('Africa/Cairo');
  SCHEMA.sheets.forEach((def, i) => buildDataSheet_(ss, def, i + 2));
  buildSummary_(ss);
  removeEmptyDefaultSheets_(ss);
  ss.setActiveSheet(ss.getSheetByName(SUMMARY_TITLE));
  ss.toast('تم إعداد الصفحات والتنسيق دون مسح أي بيانات.', 'حاسبة الرمان', 6);
}

function buildDataSheet_(ss, def, position) {
  const headerRow = SCHEMA.headerRow;
  const firstRow = SCHEMA.firstDataRow;
  let sh = ss.getSheetByName(def.title);
  const isNew = !sh;
  if (isNew) sh = ss.insertSheet(def.title, position - 1);
  sh.setRightToLeft(true);
  sh.setTabColor(def.tabColor);

  // ربط كل عمود في المخطط بموقعه الفعلي، وإضافة الناقص في النهاية فقط.
  const lastCol = Math.max(sh.getLastColumn(), 1);
  const existing = isNew ? [] : sh.getRange(headerRow, 1, 1, lastCol).getValues()[0].map(String);
  let next = existing.filter(String).length ? existing.length + 1 : 1;
  const positions = def.columns.map(col => {
    const found = existing.indexOf(col.name);
    return found >= 0 ? found + 1 : next++;
  });
  const width = Math.max(next - 1, ...positions);
  if (sh.getMaxColumns() < width) sh.insertColumnsAfter(sh.getMaxColumns(), width - sh.getMaxColumns());
  if (sh.getMaxRows() < MIN_ROWS) sh.insertRowsAfter(sh.getMaxRows(), MIN_ROWS - sh.getMaxRows());
  const maxRows = sh.getMaxRows();
  const dataRows = maxRows - firstRow + 1;

  // العنوان والوصف دون دمج خلايا، حتى يمكن تثبيت الأعمدة الأولى.
  const band = sh.getRange(1, 1, 2, width);
  band.breakApart().clearContent();
  sh.getRange(1, 1, 1, width).setBackground(def.tabColor);
  sh.getRange(2, 1, 1, width).setBackground(C.ivory);
  sh.getRange(1, 1).setValue(def.title)
    .setFontFamily(FONT).setFontSize(20).setFontWeight('bold').setFontColor(C.white)
    .setHorizontalAlignment('right').setVerticalAlignment('middle').setWrap(false);
  sh.getRange(2, 1).setValue(def.description)
    .setFontFamily(FONT).setFontSize(12).setFontColor(C.ink2)
    .setHorizontalAlignment('right').setVerticalAlignment('middle').setWrap(false);
  sh.setRowHeight(1, 44);
  sh.setRowHeight(2, 30);

  const rules = [];
  def.columns.forEach((col, i) => {
    const c = positions[i];
    sh.getRange(headerRow, c).setValue(col.name)
      .setFontFamily(FONT).setFontSize(13).setFontWeight('bold').setFontColor(C.white)
      .setBackground(col.kind === 'id' ? C.idHead : C.green)
      .setHorizontalAlignment('center').setVerticalAlignment('middle').setWrap(true);
    sh.setColumnWidth(c, Math.round(col.width * 7.5 + 10));
    const body = sh.getRange(firstRow, c, dataRows, 1);
    let color = C.ink;
    if (col.kind === 'id') color = C.muted;
    if (col.emphasis === 'paid') color = C.green;
    if (col.emphasis === 'due') color = C.amber;
    body.setFontFamily(FONT).setFontSize(col.kind === 'id' ? 10 : 13).setFontColor(color)
      .setFontWeight(['bold', 'paid', 'due'].indexOf(col.emphasis) >= 0 ? 'bold' : 'normal')
      .setNumberFormat(col.numberFormat).setHorizontalAlignment(col.align)
      .setVerticalAlignment('middle').setWrap(col.kind === 'long');
    if (col.hidden) sh.hideColumns(c); else sh.showColumns(c);
    if (col.options) {
      body.setDataValidation(SpreadsheetApp.newDataValidation()
        .requireValueInList(col.options, true).setAllowInvalid(false)
        .setHelpText('اختر قيمة من القائمة.').build());
      col.options.forEach(opt => {
        const st = VALUE_STYLES[opt];
        if (!st) return;
        const rule = SpreadsheetApp.newConditionalFormatRule().whenTextEqualTo(opt)
          .setBackground('#' + st[0]).setFontColor('#' + st[1]).setBold(true);
        if (st[2]) rule.setStrikethrough(true);
        rules.push(rule.setRanges([body]).build());
      });
    }
  });
  sh.setRowHeight(headerRow, 48);
  sh.setRowHeights(firstRow, dataRows, 28);
  sh.getRange(firstRow, 1, dataRows, width)
    .setBorder(null, true, true, true, true, true, C.line, SpreadsheetApp.BorderStyle.SOLID);

  const idCol = columnLetter_(positions[0]);
  rules.push(SpreadsheetApp.newConditionalFormatRule()
    .whenFormulaSatisfied(`=AND(ISODD(ROW()),$${idCol}${firstRow}<>"")`)
    .setBackground(C.ivory).setRanges([sh.getRange(firstRow, 1, dataRows, width)]).build());
  sh.setConditionalFormatRules(rules);

  sh.setFrozenRows(headerRow);
  sh.setFrozenColumns(def.freezeColumns);
  if (!sh.getFilter()) sh.getRange(headerRow, 1, maxRows - headerRow + 1, width).createFilter();

  // صفوف أولية (الإعدادات وأصناف التعبئة) تُكتب فقط إن كانت الصفحة فارغة.
  const base = BASE_ROWS[def.key];
  if (base && sh.getLastRow() < firstRow) {
    const values = base.map(r => r.map(v => (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}/.test(v)) ? new Date(v) : v));
    const out = values.map(r => {
      const row = new Array(width).fill('');
      r.forEach((v, i) => { row[positions[i] - 1] = v === null ? '' : v; });
      return row;
    });
    sh.getRange(firstRow, 1, out.length, width).setValues(out);
  }
}

function buildSummary_(ss) {
  let sh = ss.getSheetByName(SUMMARY_TITLE);
  if (!sh) sh = ss.insertSheet(SUMMARY_TITLE, 0);
  // صفحة الملخص محسوبة بالكامل، فإعادة بنائها لا تمس أي بيانات.
  sh.clear();
  sh.getRange(1, 1, sh.getMaxRows(), sh.getMaxColumns()).breakApart();
  sh.clearConditionalFormatRules();
  ss.setActiveSheet(sh);
  ss.moveActiveSheet(1);
  sh.setRightToLeft(true);
  sh.setHiddenGridlines(true);
  sh.setTabColor(C.red);
  sh.setColumnWidth(1, 24);
  for (let c = 2; c <= 13; c++) sh.setColumnWidth(c, 130);

  sh.getRange('B1:L1').merge().setValue('حاسبة الرمان — ملخص الموسم')
    .setFontFamily(FONT).setFontSize(24).setFontWeight('bold').setFontColor(C.white).setBackground(C.red)
    .setHorizontalAlignment('right').setVerticalAlignment('middle');
  sh.setRowHeight(1, 56);
  sh.getRange('B2:L2').merge().setValue('تتحدث هذه الأرقام تلقائيًا من الصفحات الأخرى. لا تكتب في هذه الصفحة.')
    .setFontFamily(FONT).setFontSize(12).setFontColor(C.ink2).setBackground(C.ivory)
    .setHorizontalAlignment('right').setVerticalAlignment('middle');
  sh.setRowHeight(2, 30);

  const palette = {
    plain: [C.grayL, C.white, C.ink, C.ink2], value: [C.redL, C.white, C.red, C.red],
    paid: [C.greenL, C.greenL, C.green, C.green], due: [C.amberL, C.amberL, C.amber, C.amber],
  };
  let row = SUMMARY.cardRow;
  SUMMARY.cards.forEach(line => {
    line.forEach((card, k) => {
      const [label, formula, fmt, kind] = card;
      const [labBg, valBg, valFg, labFg] = palette[kind];
      const lab = sh.getRange(row, 2 + 2 * k, 1, 2).merge();
      lab.setValue(label).setFontFamily(FONT).setFontSize(12).setFontWeight('bold').setFontColor(labFg)
        .setBackground(labBg).setHorizontalAlignment('center').setVerticalAlignment('middle').setWrap(true);
      const val = sh.getRange(row + 1, 2 + 2 * k, 1, 2).merge();
      val.setFormula(formula).setNumberFormat(fmt).setFontFamily(FONT).setFontSize(22).setFontWeight('bold')
        .setFontColor(valFg).setBackground(valBg).setHorizontalAlignment('center').setVerticalAlignment('middle');
      sh.getRange(row, 2 + 2 * k, 2, 2)
        .setBorder(true, true, true, true, null, null, C.white, SpreadsheetApp.BorderStyle.SOLID_MEDIUM);
    });
    sh.setRowHeight(row, 32);
    sh.setRowHeight(row + 1, 48);
    sh.setRowHeight(row + 2, 12);
    row += 3;
  });

  const top = SUMMARY.tableTitleRow;
  sh.getRange(top, 2, 1, 11).merge().setValue('ملخص البرادات')
    .setFontFamily(FONT).setFontSize(18).setFontWeight('bold').setFontColor(C.white).setBackground(C.green)
    .setHorizontalAlignment('right').setVerticalAlignment('middle');
  sh.setRowHeight(top, 40);
  sh.getRange(top + 1, 2, 1, 11).setValues([SUMMARY.tableHeads])
    .setFontFamily(FONT).setFontSize(12).setFontWeight('bold').setFontColor(C.ink).setBackground(C.greenL)
    .setHorizontalAlignment('center').setVerticalAlignment('middle').setWrap(true)
    .setBorder(null, null, true, null, null, null, C.green, SpreadsheetApp.BorderStyle.SOLID_MEDIUM);
  sh.setRowHeight(top + 1, 44);

  const first = SUMMARY.tableFirstRow;
  const n = SUMMARY.tableRows.length;
  const table = sh.getRange(first, 2, n, 11);
  table.setFormulas(SUMMARY.tableRows).setFontFamily(FONT).setFontSize(13)
    .setHorizontalAlignment('center').setVerticalAlignment('middle')
    .setBorder(null, null, true, null, null, true, C.line, SpreadsheetApp.BorderStyle.SOLID);
  SUMMARY.tableFormats.forEach((fmt, j) => sh.getRange(first, 2 + j, n, 1).setNumberFormat(fmt));
  sh.getRange(first, 3, n, 1).setHorizontalAlignment('right');
  [0, 6, 7, 8, 10].forEach(j => sh.getRange(first, 2 + j, n, 1).setFontWeight('bold'));
  sh.getRange(first, 9, n, 1).setFontColor(C.green);
  sh.getRange(first, 10, n, 1).setFontColor(C.amber);
  sh.setRowHeights(first, n, 28);

  const status = sh.getRange(first, 4, n, 1);
  sh.setConditionalFormatRules([
    SpreadsheetApp.newConditionalFormatRule().whenTextEqualTo('مفتوح')
      .setBackground(C.greenL).setFontColor(C.green).setBold(true).setRanges([status]).build(),
    SpreadsheetApp.newConditionalFormatRule().whenTextEqualTo('مقفّل')
      .setBackground(C.grayL).setFontColor('#4A423C').setBold(true).setRanges([status]).build(),
    SpreadsheetApp.newConditionalFormatRule().whenFormulaSatisfied(`=AND(ISODD(ROW()),$B${first}<>"")`)
      .setBackground(C.ivory).setRanges([table]).build(),
  ]);
  sh.setFrozenRows(2);
}

function removeEmptyDefaultSheets_(ss) {
  const keep = new Set([SUMMARY_TITLE, ...SCHEMA.sheets.map(s => s.title)]);
  ss.getSheets().forEach(sh => {
    if (!keep.has(sh.getName()) && sh.getLastRow() === 0 && sh.getLastColumn() === 0) ss.deleteSheet(sh);
  });
}

function columnLetter_(n) {
  let s = '';
  while (n > 0) {
    const m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = Math.floor((n - 1) / 26);
  }
  return s;
}

// ============================================================================================
// المصدر: backend/src/Config.gs
// ============================================================================================

/**
 * Config.gs — ثوابت الخادم وخصائص السكربت (Script Properties).
 *
 * العقد: docs/API.md. هذا الملف يشارك النطاق العام مع sheets/setup.gs، فلا تعرّف هنا
 * أي اسم معرَّف هناك (SCHEMA, BASE_ROWS, VALUE_STYLES, SUMMARY, FONT, SUMMARY_TITLE,
 * MIN_ROWS, C, ...). كل الأسماء العامة هنا تبدأ بـ RMN_ أو cfg.
 *
 * لا تعتمد القيم هنا على ملفات أخرى عند التحميل، لأن ترتيب تحميل الملفات غير مضمون.
 */

const RMN_CFG = Object.freeze({
  service: 'rumman-calculator',
  apiVersion: 1,

  // معرّفات OAuth العامة (ليست أسرارًا). يمكن استبدالها بالخاصية ALLOWED_CLIENT_IDS.
  defaultClientIds: Object.freeze([
    '833981951758-668sjormn0kp8lm4e8c0ioltdr0ctip8.apps.googleusercontent.com', // web
    '833981951758-pb57t33tr66q4b8c3r9tsd3gnbs4doi5.apps.googleusercontent.com', // iOS
    '833981951758-c4f37gpodur13gg933ka3hi14359alg1.apps.googleusercontent.com', // Android
  ]),
  tokenIssuers: Object.freeze(['accounts.google.com', 'https://accounts.google.com']),
  tokenInfoUrl: 'https://oauth2.googleapis.com/tokeninfo?id_token=',

  defaultSessionDays: 7,
  maxSessionDays: 90,
  defaultTimeZone: 'Africa/Cairo',

  // الأنماط الوحيدة المسموح تمريرها إلى Utilities.formatDate.
  fmtIso: "yyyy-MM-dd'T'HH:mm:ssXXX",
  fmtMinute: 'yyyy-MM-dd HH:mm',
  fmtDay: 'yyyy-MM-dd',
  fmtTime: 'HH:mm',

  lockWaitMs: 25000,
  requestCacheSeconds: 21600, // 6 ساعات
  requestCachePrefix: 'req:',
  dashboardCacheSeconds: 60,
  dashboardCachePrefix: 'dash:',

  compensationReason: 'تعذّر إكمال الحفظ',
  failedKeySuffix: '#failed',
  auditMaxCellChars: 45000,
});

// أسماء خصائص السكربت.
const RMN_PROP = Object.freeze({
  sessionSecret: 'SESSION_SECRET',
  bootstrapEmail: 'BOOTSTRAP_ADMIN_EMAIL',
  spreadsheetId: 'SPREADSHEET_ID',
  allowedClientIds: 'ALLOWED_CLIENT_IDS',
  sessionDays: 'SESSION_DAYS',
  lastWriteAt: 'LAST_WRITE_AT',
  lastError: 'LAST_ERROR',
  dataVersion: 'DATA_VERSION',
});

function cfgProps_() {
  return PropertiesService.getScriptProperties();
}

/** قيمة خاصية كنص ('' إن لم توجد). */
function cfgGet_(key) {
  const v = cfgProps_().getProperty(key);
  return v === null || v === undefined ? '' : String(v);
}

function cfgSet_(key, value) {
  cfgProps_().setProperty(key, String(value));
}

function cfgDelete_(key) {
  cfgProps_().deleteProperty(key);
}

/** معرّفات العملاء المسموح بها لرمز Google (aud). */
function cfgAllowedClientIds_() {
  const raw = cfgGet_(RMN_PROP.allowedClientIds).trim();
  if (!raw) return RMN_CFG.defaultClientIds.slice();
  const list = raw.split(',').map(function (s) { return s.trim(); }).filter(Boolean);
  return list.length ? list : RMN_CFG.defaultClientIds.slice();
}

/**
 * مدة الجلسة بالأيام (افتراضيًا 7، حتى 90). القيمة 0 تعني أن الجلسة تنتهي فورًا (للطوارئ).
 * الفارغ أو غير الصالح ⇒ 7.
 */
function cfgSessionDays_() {
  const raw = cfgGet_(RMN_PROP.sessionDays).trim();
  if (!raw) return RMN_CFG.defaultSessionDays;
  const n = Number(raw);
  if (!isFinite(n) || n < 0) return RMN_CFG.defaultSessionDays;
  return Math.min(n, RMN_CFG.maxSessionDays);
}

/** بريد المدير الأساسي بحروف صغيرة ('' إن لم يُضبط). */
function cfgBootstrapEmail_() {
  return cfgGet_(RMN_PROP.bootstrapEmail).trim().toLowerCase();
}

/**
 * سر توقيع الجلسات. يُولَّد تلقائيًا عند أول استخدام (معرّفان UUID متصلان) ولا يُعاد أبدًا.
 * يُولَّد تحت قفل السكربت حتى لا يكتب طلبان متزامنان سرّين مختلفين.
 */
function cfgSessionSecret_() {
  let secret = cfgGet_(RMN_PROP.sessionSecret);
  if (secret) return secret;
  const rq = rq_();
  let lock = null;
  if (!rq.lockHeld) {
    lock = LockService.getScriptLock();
    if (!lock.tryLock(10000)) lock = null;
  }
  try {
    secret = cfgGet_(RMN_PROP.sessionSecret);
    if (!secret) {
      secret = Utilities.getUuid() + Utilities.getUuid();
      cfgSet_(RMN_PROP.sessionSecret, secret);
    }
  } finally {
    if (lock) lock.releaseLock();
  }
  return secret;
}

/** يسجل آخر خطأ غير متوقع في LAST_ERROR = {at, message}. لا يرمي أبدًا. */
function cfgRecordError_(message) {
  try {
    let at;
    try { at = fmtIso_(new Date()); } catch (e) { at = new Date().toISOString(); }
    cfgSet_(RMN_PROP.lastError, JSON.stringify({ at: at, message: String(message).slice(0, 1500) }));
  } catch (e) {
    // لا شيء: تسجيل الخطأ لا يجوز أن يُفشل الرد.
  }
}

/** آخر خطأ مسجل أو null. */
function cfgLastError_() {
  const raw = cfgGet_(RMN_PROP.lastError);
  if (!raw) return null;
  try {
    const v = JSON.parse(raw);
    if (v && typeof v === 'object') return { at: v.at ? String(v.at) : null, message: v.message ? String(v.message) : '' };
  } catch (e) {
    return { at: null, message: raw };
  }
  return null;
}

// ============================================================================================
// المصدر: backend/src/Util.gs
// ============================================================================================

/**
 * Util.gs — الأخطاء، وتحويل القيم بين الصفحة والـ API، والمال والأوزان، والمعرّفات، والوقت،
 * والتحقق من المدخلات. أغلب الدوال هنا نقية (لا تلمس الصفحة) ليسهل اختبارها.
 */

// =====================================================================================
// الأخطاء
// =====================================================================================

/** خطأ معروف يُعاد للعميل كما هو: {code, message, field, details}. */
class RmnApiError extends Error {
  constructor(code, message, field, details) {
    super(message);
    this.name = 'RmnApiError';
    this.code = code;
    this.field = field === undefined || field === '' ? null : field;
    this.details = details && typeof details === 'object' ? details : {};
    this.isRmnApiError = true;
  }
}

function apiError_(code, message, field, details) {
  return new RmnApiError(code, message, field, details);
}

function isApiError_(err) {
  return !!(err && err.isRmnApiError === true && typeof err.code === 'string');
}

function failValidation_(field, message, details) {
  throw apiError_('VALIDATION', message, field || null, details);
}

function failNotFound_(field, thing, id) {
  throw apiError_('NOT_FOUND',
    'لم يتم العثور على ' + thing + ' بالمعرّف «' + id + '». حدّث البيانات واختره من القائمة مرة أخرى.',
    field || null, { id: id });
}

function failConflict_(thing, currentVersion, current) {
  throw apiError_('CONFLICT',
    'عدّل مستخدم آخر ' + thing + ' بعد أن فتحته. راجع البيانات الحالية ثم أعد الحفظ.',
    'expectedVersion', { currentVersion: currentVersion, current: current });
}

// =====================================================================================
// قيم القوائم (الصفحة ⇄ API) — القسم 4 من العقد
// =====================================================================================

const RMN_ENUMS = Object.freeze({
  role: { 'مدير': 'admin', 'موظف إدخال': 'entry', 'مشاهدة فقط': 'viewer' },
  userStatus: { 'نشط': 'active', 'معطّل': 'disabled' },
  coolerStatus: { 'مفتوح': 'open', 'مقفّل': 'closed' },
  recordStatus: { 'فعّالة': 'active', 'ملغاة': 'cancelled' },
  payStatus: { 'مدفوع': 'paid', 'جزئي': 'partial', 'غير مدفوع': 'unpaid' },
  weightMethod: { 'مباشر': 'direct', 'عينة': 'sample' },
  packagingStatus: { 'مسودة': 'draft', 'معتمد': 'approved', 'ملغى': 'cancelled' },
  itemStatus: { 'مكتمل': 'complete', 'غير مكتمل': 'incomplete', 'محذوف': 'removed' },
  payMethod: { 'نقدًا': 'cash', 'تحويل بنكي': 'bank', 'محفظة إلكترونية': 'wallet' },
  payeeType: { 'مزارع': 'farmer', 'مورد': 'supplier' },
  payTarget: { 'شراء رمان': 'purchase', 'شراء تعبئة': 'packaging' },
  farmerStatus: { 'نشط': 'active', 'موقوف': 'inactive' },
  yesNo: { 'نعم': true, 'لا': false },
});

// الوحدات المسموحة لأصناف التعبئة (كما في قائمة الصفحة).
const RMN_UNITS = Object.freeze(['قطعة', 'رزمة', 'لفة', 'رول', 'كرتونة', 'كغ']);

/** قيمة الصفحة → قيمة API. تتسامح مع التشكيل والمسافات. القيمة الفارغة/المجهولة → fallback. */
function enumToApi_(kind, value, fallback) {
  const map = RMN_ENUMS[kind];
  if (typeof value === 'boolean' && kind === 'yesNo') return value;
  const key = normText_(cellStr_(value));
  if (!key) return fallback;
  const names = Object.keys(map);
  for (let i = 0; i < names.length; i++) {
    if (normText_(names[i]) === key) return map[names[i]];
  }
  for (let i = 0; i < names.length; i++) {
    if (String(map[names[i]]).toLowerCase() === key) return map[names[i]];
  }
  return fallback;
}

/** قيمة API → قيمة الصفحة، أو null إن لم تكن معروفة. */
function enumToSheet_(kind, apiValue) {
  const map = RMN_ENUMS[kind];
  const names = Object.keys(map);
  for (let i = 0; i < names.length; i++) {
    if (map[names[i]] === apiValue) return names[i];
  }
  return null;
}

function yesNo_(b) {
  return b ? 'نعم' : 'لا';
}

// =====================================================================================
// النصوص
// =====================================================================================

/** يحوّل الأرقام العربية-الهندية والفارسية إلى أرقام لاتينية. */
function digitsToLatin_(s) {
  return String(s)
    .replace(/[٠-٩]/g, function (ch) { return String(ch.charCodeAt(0) - 0x0660); })
    .replace(/[۰-۹]/g, function (ch) { return String(ch.charCodeAt(0) - 0x06F0); });
}

/** تطبيع للمقارنة والبحث: بلا تشكيل أو تطويل، توحيد الألف والياء والتاء المربوطة، مسافات مفردة. */
function normText_(s) {
  return digitsToLatin_(s === null || s === undefined ? '' : String(s))
    .replace(/[ً-ٰٟـ​-‏‪-‮]/g, '')
    .replace(/[آأإٱ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .replace(/ؤ/g, 'و')
    .replace(/ئ/g, 'ي')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

function isPlainObject_(v) {
  return v !== null && typeof v === 'object' && !Array.isArray(v) && !isDate_(v);
}

function isDate_(v) {
  return Object.prototype.toString.call(v) === '[object Date]' && !isNaN(v.getTime());
}

/** نص المستخدم كما يُكتب في الأعمدة: «الاسم (البريد)». */
function userLabel_(user) {
  if (!user) return '';
  const email = String(user.email || '');
  const name = String(user.name || '').trim();
  if (!name || name.toLowerCase() === email.toLowerCase()) return email;
  return name + ' (' + email + ')';
}

/** يستخرج البريد من «الاسم (البريد)» أو من بريد مكتوب وحده. */
function labelEmail_(label) {
  const s = cellStr_(label);
  const m = /\(([^()\s]+@[^()\s]+)\)\s*$/.exec(s);
  if (m) return m[1].toLowerCase();
  if (/^[^@\s]+@[^@\s]+$/.test(s)) return s.toLowerCase();
  return '';
}

/** يستخرج الاسم المعروض من «الاسم (البريد)». */
function labelName_(label) {
  const s = cellStr_(label);
  const m = /^(.*?)\s*\(([^()\s]+@[^()\s]+)\)\s*$/.exec(s);
  if (m) return m[1].trim() || m[2];
  return s;
}

/** يضيف سطرًا إلى الملاحظات القائمة. */
function appendNote_(existing, line) {
  const base = cellStr_(existing);
  return base ? base + '\n' + line : line;
}

// =====================================================================================
// قراءة الخلايا (الخلية قد تحوي Date أو رقمًا أو نصًا أو "")
// =====================================================================================

/** نص الخلية بعد إزالة علامة الهروب ' التي نضيفها قبل = + - @. */
function cellStr_(v) {
  if (v === null || v === undefined) return '';
  if (isDate_(v)) return Utilities.formatDate(v, rqTzSafe_(), RMN_CFG.fmtMinute);
  if (typeof v === 'number') return isFinite(v) ? String(v) : '';
  let s = String(v);
  if (s.length > 1 && s.charAt(0) === "'" && /[=+\-@]/.test(s.charAt(1))) s = s.slice(1);
  return s.trim();
}

/**
 * يحوّل قيمة عشرية إلى عدد صحيح مضروب في 10^scale.
 * رقم ⇒ Math.round(x × 10^scale) (كما في العقد). نص ⇒ حساب نصي دون أعداد عشرية (النصف للأعلى).
 * يعيد null للفارغ وNaN لغير الصالح.
 */
function parseScaled_(value, scale) {
  if (value === null || value === undefined || value === '') return null;
  if (typeof value === 'number') return isFinite(value) ? Math.round(value * Math.pow(10, scale)) : NaN;
  if (typeof value !== 'string') return NaN;
  let s = digitsToLatin_(cellStr_(value))
    .replace(/[\s,٬،]/g, '')
    .replace(/٫/g, '.');
  if (s === '') return null;
  const m = /^([+-]?)(\d*)(?:\.(\d*))?$/.exec(s);
  if (!m || (m[2] === '' && !m[3])) return NaN;
  const frac = (m[3] || '') + '0'.repeat(scale + 1);
  let n = Number(m[2] || '0') * Math.pow(10, scale) + Number(frac.slice(0, scale) || '0');
  if (Number(frac.charAt(scale)) >= 5) n += 1;
  return m[1] === '-' ? -n : n;
}

function cellInt_(v) {
  const n = parseScaled_(v, 0);
  return n === null || isNaN(n) ? null : n;
}

/** مبلغ بالجنيه في الخلية → قروش (عدد صحيح) أو null. */
function cellMoney_(v) {
  const n = parseScaled_(v, 2);
  return n === null || isNaN(n) ? null : n;
}

/** وزن بالكيلو في الخلية → غرامات (عدد صحيح) أو null. */
function cellGrams_(v) {
  const n = parseScaled_(v, 3);
  return n === null || isNaN(n) ? null : n;
}

function cellBool_(v) {
  return enumToApi_('yesNo', v, false) === true;
}

/** تاريخ/وقت الخلية → Date أو null. النص بلا منطقة زمنية يُفهم بتوقيت العمل. */
function cellDate_(v) {
  if (v === null || v === undefined || v === '') return null;
  if (isDate_(v)) return new Date(v.getTime());
  const tz = rqTzSafe_();
  if (typeof v === 'number' && isFinite(v)) {
    // رقم تسلسلي لجداول البيانات (أيام منذ 1899-12-30) بتوقيت الملف.
    const wall = new Date(Math.round((v - 25569) * 86400000));
    return localToInstant_(wall.getUTCFullYear(), wall.getUTCMonth() + 1, wall.getUTCDate(),
      wall.getUTCHours(), wall.getUTCMinutes(), wall.getUTCSeconds(), tz);
  }
  if (typeof v !== 'string') return null;
  return parseDateText_(cellStr_(v), tz);
}

/** قيمة تُكتب في خلية: null → ""، والنص الذي يبدأ بـ = + - @ يُسبق بـ ' حتى لا يُفسَّر كصيغة. */
function cellOut_(v) {
  if (v === null || v === undefined) return '';
  if (typeof v === 'string' && /^[=+\-@]/.test(v)) return "'" + v;
  return v;
}

// =====================================================================================
// المال والأوزان (أعداد صحيحة فقط: قروش وغرامات)
// =====================================================================================

/** round_half_up(n / d) لأعداد صحيحة (d > 0) دون أعداد عشرية. */
function roundHalfUpDiv_(n, d) {
  if (n < 0) return -roundHalfUpDiv_(-n, d);
  const r = n % d;
  const q = (n - r) / d;
  return 2 * r >= d ? q + 1 : q;
}

/** totalWeightGrams = boxes × avgWeightGrams؛ valuePiasters = round_half_up(total × price / 1000). */
function purchaseMath_(boxes, avgWeightGrams, pricePerKgPiasters) {
  const totalWeightGrams = boxes * avgWeightGrams;
  return {
    totalWeightGrams: totalWeightGrams,
    valuePiasters: roundHalfUpDiv_(totalWeightGrams * pricePerKgPiasters, 1000),
  };
}

/** متوسط سعر الكيلو بالقروش = round_half_up(value × 1000 / weight). */
function avgPricePerKg_(valuePiasters, weightGrams) {
  return weightGrams > 0 ? roundHalfUpDiv_(valuePiasters * 1000, weightGrams) : 0;
}

/** round(mean(samples) − tare) بأعداد صحيحة. */
function sampleNetAverage_(samples, tareGrams) {
  let sum = 0;
  for (let i = 0; i < samples.length; i++) sum += samples[i];
  return roundHalfUpDiv_(sum - tareGrams * samples.length, samples.length);
}

/** حالة الدفع من القيمة والمدفوع. */
function payStatusOf_(valuePiasters, paidPiasters) {
  if (paidPiasters <= 0) return 'unpaid';
  if (paidPiasters >= valuePiasters) return 'paid';
  return 'partial';
}

/** قروش → جنيه (رقم) للكتابة في الصفحة. */
function toEgp_(piasters) {
  return piasters === null || piasters === undefined ? '' : piasters / 100;
}

/** غرامات → كيلو (رقم) للكتابة في الصفحة. */
function toKg_(grams) {
  return grams === null || grams === undefined ? '' : grams / 1000;
}

/** غرامات → نص بالكيلو بلا أصفار زائدة: 12400 → "12.4". */
function gramsText_(grams) {
  const neg = grams < 0;
  const g = Math.abs(grams);
  const whole = Math.floor(g / 1000);
  let frac = String(g % 1000);
  while (frac.length < 3) frac = '0' + frac;
  frac = frac.replace(/0+$/, '');
  return (neg ? '-' : '') + whole + (frac ? '.' + frac : '');
}

/** أوزان العينة كنص: "12.4، 12.9". */
function samplesText_(samples) {
  return samples.map(gramsText_).join('، ');
}

/** نص أوزان العينة (كغ) → غرامات. */
function samplesParse_(text) {
  const s = cellStr_(text);
  if (!s) return [];
  const out = [];
  s.split(/[،,;\n]+/).forEach(function (part) {
    const g = parseScaled_(part.trim(), 3);
    if (g !== null && !isNaN(g) && g > 0) out.push(g);
  });
  return out;
}

function groupThousands_(digits) {
  return digits.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

/** نص مبلغ للرسائل: 825000 → "8,250.00 ج.م". */
function fmtMoneyMsg_(piasters) {
  if (piasters === null || piasters === undefined) return '';
  const neg = piasters < 0;
  const p = Math.abs(piasters);
  let cents = String(p % 100);
  if (cents.length < 2) cents = '0' + cents;
  return (neg ? '-' : '') + groupThousands_(String(Math.floor(p / 100))) + '.' + cents + ' ج.م';
}

/** نص وزن للرسائل: 550000 → "550 كغ". */
function fmtKgMsg_(grams) {
  if (grams === null || grams === undefined) return '';
  return gramsText_(grams) + ' كغ';
}

// =====================================================================================
// المعرّفات
// =====================================================================================

/** الرقم التسلسلي في معرّف مثل CL-0012 (أو 0 إن لم يطابق البادئة). */
function seqNumber_(value, prefix) {
  const m = new RegExp('^' + prefix + '-?(\\d+)$', 'i').exec(cellStr_(value));
  return m ? parseInt(m[1], 10) : 0;
}

/** CL + 7 → "CL-0007" (4 أرقام على الأقل). */
function seqFormat_(prefix, n) {
  let s = String(n);
  while (s.length < 4) s = '0' + s;
  return prefix + '-' + s;
}

// =====================================================================================
// الوقت (ISO-8601 بتوقيت العمل مع الإزاحة)
// =====================================================================================

const RMN_DATE_RE = /^(\d{4})[-\/](\d{1,2})[-\/](\d{1,2})(?:(?:T|\s+)(\d{1,2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?)?\s*(Z|[+-]\d{2}(?::?\d{2})?)?$/i;

/** "+03:00" → 180، "Z" → 0، غير صالح → null. */
function offsetMinutes_(s) {
  if (!s) return null;
  if (s === 'Z' || s === 'z') return 0;
  const m = /^([+-])(\d{2}):?(\d{2})?$/.exec(s);
  if (!m) return null;
  const v = Number(m[2]) * 60 + (m[3] ? Number(m[3]) : 0);
  if (v > 14 * 60) return null;
  return m[1] === '-' ? -v : v;
}

function isoInTz_(date, tz) {
  return Utilities.formatDate(date, tz, RMN_CFG.fmtIso);
}

/** أجزاء الوقت المحلي في المنطقة tz مع الإزاحة بالدقائق. */
function partsInTz_(date, tz) {
  const iso = isoInTz_(date, tz);
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(.*)$/.exec(iso);
  if (!m) throw new Error('formatDate returned an unexpected value: ' + iso);
  const off = offsetMinutes_(m[7].trim());
  return {
    y: Number(m[1]), mo: Number(m[2]), d: Number(m[3]),
    h: Number(m[4]), mi: Number(m[5]), s: Number(m[6]),
    offset: off === null ? 0 : off, iso: iso,
  };
}

/** وقت محلي (جدار الساعة) في tz → لحظة Date. */
function localToInstant_(y, mo, d, h, mi, s, tz) {
  const wall = Date.UTC(y, mo - 1, d, h || 0, mi || 0, s || 0);
  const off1 = partsInTz_(new Date(wall), tz).offset;
  let t = wall - off1 * 60000;
  const off2 = partsInTz_(new Date(t), tz).offset;
  if (off2 !== off1) t = wall - off2 * 60000;
  return new Date(t);
}

/** يزيد أيامًا على تاريخ تقويمي. */
function addDaysYmd_(y, mo, d, n) {
  const t = new Date(Date.UTC(y, mo - 1, d + n));
  return { y: t.getUTCFullYear(), mo: t.getUTCMonth() + 1, d: t.getUTCDate() };
}

/** بداية اليوم المحلي الذي يقع فيه date. */
function startOfLocalDay_(date, tz) {
  const p = partsInTz_(date, tz);
  return localToInstant_(p.y, p.mo, p.d, 0, 0, 0, tz);
}

/** آخر لحظة في اليوم المحلي الذي يقع فيه date. */
function endOfLocalDay_(date, tz) {
  const p = partsInTz_(date, tz);
  const n = addDaysYmd_(p.y, p.mo, p.d, 1);
  return new Date(localToInstant_(n.y, n.mo, n.d, 0, 0, 0, tz).getTime() - 1);
}

function isDateOnlyText_(s) {
  return /^\d{4}-\d{1,2}-\d{1,2}$/.test(digitsToLatin_(String(s || '')).trim());
}

/**
 * يحلل نص تاريخ/وقت: ISO مع إزاحة، أو "yyyy-MM-dd HH:mm"، أو "yyyy-MM-dd".
 * بلا إزاحة ⇒ بتوقيت tz. يعيد Date أو null.
 */
function parseDateText_(text, tz) {
  const s = digitsToLatin_(String(text || '')).trim();
  const m = RMN_DATE_RE.exec(s);
  if (!m) return null;
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  const h = m[4] ? Number(m[4]) : 0;
  const mi = m[5] ? Number(m[5]) : 0;
  const se = m[6] ? Number(m[6]) : 0;
  if (y < 1900 || y > 2200 || mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59 || se > 59) return null;
  const check = new Date(Date.UTC(y, mo - 1, d));
  if (check.getUTCDate() !== d || check.getUTCMonth() !== mo - 1) return null;
  if (m[7]) {
    const off = offsetMinutes_(m[7].toUpperCase());
    if (off === null) return null;
    return new Date(Date.UTC(y, mo - 1, d, h, mi, se) - off * 60000);
  }
  return localToInstant_(y, mo, d, h, mi, se, tz);
}

/** Date → ISO بتوقيت العمل، أو null. */
function fmtIso_(date) {
  return isDate_(date) ? isoInTz_(date, rqTzSafe_()) : null;
}

/** Date → "yyyy-MM-dd" بتوقيت العمل، أو null. */
function fmtDay_(date) {
  return isDate_(date) ? Utilities.formatDate(date, rqTzSafe_(), RMN_CFG.fmtDay) : null;
}

/** Date → "yyyy-MM-dd HH:mm" بتوقيت العمل (للرسائل والسجل). */
function fmtMinute_(date) {
  return isDate_(date) ? Utilities.formatDate(date, rqTzSafe_(), RMN_CFG.fmtMinute) : '';
}

/** خلية تاريخ → ISO أو null. */
function cellIso_(v) {
  return fmtIso_(cellDate_(v));
}

// =====================================================================================
// التحقق من المدخلات
// =====================================================================================

function inPresent_(v) {
  return !(v === undefined || v === null || (typeof v === 'string' && v.trim() === ''));
}

/**
 * نص اختياري أو مطلوب. opts: {required, max, multiline, hint}.
 * يعيد '' إن كان غائبًا وغير مطلوب.
 */
function inStr_(v, field, label, opts) {
  opts = opts || {};
  if (!inPresent_(v)) {
    if (opts.required) failValidation_(field, '«' + label + '» مطلوب. ' + (opts.hint || 'اكتبه ثم أعد المحاولة.'));
    return '';
  }
  if (typeof v !== 'string' && typeof v !== 'number') {
    failValidation_(field, '«' + label + '» يجب أن يكون نصًا. صحّحه ثم أعد المحاولة.');
  }
  let s = String(v);
  s = opts.multiline ? s.replace(/\r\n?/g, '\n').trim() : s.replace(/\s+/g, ' ').trim();
  const max = opts.max || 200;
  if (s.length > max) {
    failValidation_(field, '«' + label + '» أطول من المسموح (' + max + ' حرفًا). اختصره ثم أعد المحاولة.', { max: max });
  }
  return s;
}

/**
 * عدد صحيح. opts: {required, min, max, fmt, hint}. يقبل أرقامًا عربية في النص.
 * يعيد null إن كان غائبًا وغير مطلوب.
 */
function inInt_(v, field, label, opts) {
  opts = opts || {};
  if (!inPresent_(v)) {
    if (opts.required) failValidation_(field, '«' + label + '» مطلوب. ' + (opts.hint || 'اكتب القيمة ثم أعد المحاولة.'));
    return null;
  }
  let n = NaN;
  if (typeof v === 'number') n = v;
  else if (typeof v === 'string') {
    const s = digitsToLatin_(v).trim();
    if (/^[+-]?\d+$/.test(s)) n = parseInt(s, 10);
  }
  if (!isFinite(n) || Math.floor(n) !== n) {
    failValidation_(field, '«' + label + '» يجب أن يكون رقمًا صحيحًا. صحّح القيمة ثم أعد المحاولة.');
  }
  const fmt = opts.fmt || function (x) { return String(x); };
  const hasMin = opts.min !== undefined && opts.min !== null;
  const hasMax = opts.max !== undefined && opts.max !== null;
  if ((hasMin && n < opts.min) || (hasMax && n > opts.max)) {
    let msg;
    if (hasMin && hasMax) msg = '«' + label + '» يجب أن يكون بين ' + fmt(opts.min) + ' و' + fmt(opts.max) + '.';
    else if (hasMin) msg = '«' + label + '» يجب ألا يقل عن ' + fmt(opts.min) + '.';
    else msg = '«' + label + '» يجب ألا يزيد على ' + fmt(opts.max) + '.';
    failValidation_(field, msg + ' صحّح القيمة ثم أعد المحاولة.', { min: hasMin ? opts.min : null, max: hasMax ? opts.max : null });
  }
  return n;
}

/**
 * قيمة من قائمة. choices: {apiValue: 'وصف عربي'}. opts: {required}.
 * يعيد null إن كانت غائبة وغير مطلوبة.
 */
function inEnum_(v, field, label, choices, opts) {
  opts = opts || {};
  const list = Object.keys(choices).map(function (k) { return '«' + choices[k] + '»'; }).join(' أو ');
  if (!inPresent_(v)) {
    if (opts.required) failValidation_(field, '«' + label + '» مطلوب. اختر ' + list + '.');
    return null;
  }
  const s = String(v).trim();
  if (!Object.prototype.hasOwnProperty.call(choices, s)) {
    failValidation_(field, 'قيمة «' + label + '» غير صحيحة. اختر ' + list + '.', { allowed: Object.keys(choices) });
  }
  return s;
}

/** قيمة منطقية؛ الغائبة → def. */
function inBool_(v, field, label, def) {
  if (v === undefined || v === null || v === '') return def;
  if (typeof v === 'boolean') return v;
  if (v === 'true' || v === 1 || v === '1') return true;
  if (v === 'false' || v === 0 || v === '0') return false;
  failValidation_(field, '«' + label + '» يجب أن يكون نعم أو لا. صحّحه ثم أعد المحاولة.');
  return def;
}

/** تاريخ ووقت بصيغة ISO (أو "yyyy-MM-dd HH:mm" بتوقيت العمل). الغائب → null. */
function inTime_(v, field, label) {
  if (!inPresent_(v)) return null;
  const d = typeof v === 'string' ? parseDateText_(v, rqTzSafe_()) : null;
  if (!d) {
    failValidation_(field, '«' + label + '» بتنسيق غير صحيح. أرسل التاريخ والوقت مثل 2026-10-02T06:40:00+03:00.');
  }
  return d;
}

/** رقم الإصدار المتوقع (مطلوب لكل تعديل). */
function inExpectedVersion_(v) {
  return inInt_(v, 'expectedVersion', 'رقم الإصدار', {
    required: true, min: 1, max: 1000000000,
    hint: 'حدّث البيانات ثم أعد الحفظ.',
  });
}

/** معرّف مطلوب (نص). */
function inId_(v, field, label) {
  return inStr_(v, field, label, { required: true, max: 64, hint: 'اختره من القائمة ثم أعد المحاولة.' });
}

/** سبب مطلوب للإلغاء أو إعادة الفتح. purpose: مثل «لإلغاء الدفعة». */
function inReason_(v, purpose) {
  return inStr_(v, 'reason', 'السبب', {
    required: true, max: 500, multiline: true,
    hint: (purpose ? 'اكتب سببًا واضحًا ' + purpose : 'اكتب سببًا واضحًا') + ' ثم أعد المحاولة.',
  });
}

// =====================================================================================
// التخزين المؤقت (CacheService) — فشله لا يُفشل الطلب
// =====================================================================================

function cacheGet_(key) {
  try {
    const v = CacheService.getScriptCache().get(key);
    return v === undefined ? null : v;
  } catch (e) {
    return null;
  }
}

function cachePut_(key, value, seconds) {
  try {
    CacheService.getScriptCache().put(key, value, seconds);
  } catch (e) {
    // القيمة أكبر من الحد أو الخدمة غير متاحة: نتجاهل.
  }
}

function cacheRemove_(key) {
  try {
    CacheService.getScriptCache().remove(key);
  } catch (e) {
    // نتجاهل.
  }
}

// ============================================================================================
// المصدر: backend/src/Auth.gs
// ============================================================================================

/**
 * Auth.gs — التحقق من رمز Google (tokeninfo)، وجلسات موقّعة بـ HMAC، والصلاحيات.
 *
 * الجلسة: base64url(JSON) + "." + base64url(HMAC_SHA256(الجزء الأول, SESSION_SECRET))
 * والحمولة {uid, email, uv, iat, exp}. لا تُخزَّن الجلسات في الخادم.
 */

// =====================================================================================
// رمز Google
// =====================================================================================

function authInvalidToken_(message, reason) {
  return apiError_('AUTH_INVALID_TOKEN', message, 'idToken', { reason: reason });
}

/**
 * يتحقق من ID token عبر tokeninfo ويعيد {email, name, sub}.
 * تُفحص: الرد 200، aud ضمن المعرّفات المسموحة، iss، email_verified، exp.
 */
function authVerifyGoogleToken_(idToken) {
  let resp;
  try {
    resp = UrlFetchApp.fetch(RMN_CFG.tokenInfoUrl + encodeURIComponent(idToken), { muteHttpExceptions: true });
  } catch (e) {
    // العقد: أي رد غير 200 ⇒ AUTH_INVALID_TOKEN. نسجل السبب للتشخيص.
    cfgRecordError_('tokeninfo fetch failed: ' + (e && e.message ? e.message : e));
    throw authInvalidToken_('تعذّر الاتصال بخدمة Google للتحقق من حسابك. تأكد من الاتصال ثم سجّل الدخول مرة أخرى بعد قليل.',
      'unavailable');
  }
  const code = resp.getResponseCode();
  if (code >= 500) {
    cfgRecordError_('tokeninfo HTTP ' + code);
    throw authInvalidToken_('خدمة Google للتحقق من الحساب لا ترد الآن. سجّل الدخول مرة أخرى بعد قليل.', 'unavailable');
  }
  if (code !== 200) {
    throw authInvalidToken_('رفضت Google رمز الدخول (ربما انتهت صلاحيته). سجّل الدخول بحساب Google مرة أخرى.', 'rejected');
  }
  let info;
  try {
    info = JSON.parse(resp.getContentText());
  } catch (e) {
    throw authInvalidToken_('تعذّر قراءة رد Google على رمز الدخول. سجّل الدخول مرة أخرى.', 'unreadable');
  }
  if (!info || typeof info !== 'object') {
    throw authInvalidToken_('تعذّر قراءة رد Google على رمز الدخول. سجّل الدخول مرة أخرى.', 'unreadable');
  }
  if (cfgAllowedClientIds_().indexOf(String(info.aud || '')) < 0) {
    throw authInvalidToken_('رمز الدخول صادر لتطبيق غير معروف. استخدم تطبيق حاسبة الرمان الرسمي ثم سجّل الدخول مرة أخرى.', 'audience');
  }
  if (RMN_CFG.tokenIssuers.indexOf(String(info.iss || '')) < 0) {
    throw authInvalidToken_('رمز الدخول ليس صادرًا من Google. سجّل الدخول بحساب Google مرة أخرى.', 'issuer');
  }
  if (!(info.email_verified === true || info.email_verified === 'true')) {
    throw authInvalidToken_('بريد حساب Google غير مؤكَّد. أكّد البريد من إعدادات حساب Google ثم سجّل الدخول مرة أخرى.', 'email_unverified');
  }
  const exp = Number(info.exp);
  if (!isFinite(exp) || exp * 1000 <= rq_().now.getTime()) {
    throw authInvalidToken_('انتهت صلاحية رمز الدخول من Google. سجّل الدخول مرة أخرى.', 'expired');
  }
  const email = String(info.email || '').trim().toLowerCase();
  if (!email) {
    throw authInvalidToken_('رمز الدخول لا يحتوي على بريد إلكتروني. سجّل الدخول بحساب Google يحتوي على بريد Gmail.', 'no_email');
  }
  return { email: email, name: info.name ? String(info.name).trim() : '', sub: info.sub ? String(info.sub) : '' };
}

// =====================================================================================
// الجلسات
// =====================================================================================

function authSignPart_(part) {
  return Utilities.base64EncodeWebSafe(Utilities.computeHmacSha256Signature(part, cfgSessionSecret_()));
}

/** مقارنة نصين في زمن ثابت. */
function authSafeEqual_(a, b) {
  a = String(a);
  b = String(b);
  let diff = a.length ^ b.length;
  const n = Math.max(a.length, b.length);
  for (let i = 0; i < n; i++) {
    diff |= (i < a.length ? a.charCodeAt(i) : 0) ^ (i < b.length ? b.charCodeAt(i) : 0);
  }
  return diff === 0;
}

/** ينشئ جلسة للمستخدم ويعيد {session, expiresAt, user}. */
function authIssueSession_(user) {
  const iat = Math.floor(rq_().now.getTime() / 1000);
  const exp = iat + Math.floor(cfgSessionDays_() * 86400);
  const payload = { uid: user.id || '', email: user.email, uv: user.version || 0, iat: iat, exp: exp };
  const part = Utilities.base64EncodeWebSafe(JSON.stringify(payload));
  const token = part + '.' + authSignPart_(part);
  const out = Object.assign({}, user);
  delete out.synthetic;
  return { session: token, expiresAt: fmtIso_(new Date(exp * 1000)), user: out };
}

function authExpired_(message, reason) {
  return apiError_('AUTH_EXPIRED', message, null, { reason: reason });
}

/** يفك الجلسة ويتحقق من التوقيع والانتهاء. يعيد الحمولة. */
function authDecodeSession_(token) {
  if (typeof token !== 'string' || !token.trim()) {
    throw apiError_('AUTH_REQUIRED', 'يجب تسجيل الدخول أولًا. سجّل الدخول بحساب Google ثم أعد المحاولة.', null, {});
  }
  const parts = token.trim().split('.');
  if (parts.length !== 2 || !parts[0] || !parts[1]) {
    throw authExpired_('الجلسة غير صالحة. سجّل الدخول مرة أخرى.', 'malformed');
  }
  if (!authSafeEqual_(authSignPart_(parts[0]), parts[1])) {
    throw authExpired_('الجلسة غير صالحة أو صادرة من خادم آخر. سجّل الدخول مرة أخرى.', 'signature');
  }
  let payload;
  try {
    payload = JSON.parse(Utilities.newBlob(Utilities.base64DecodeWebSafe(parts[0])).getDataAsString());
  } catch (e) {
    throw authExpired_('الجلسة غير صالحة. سجّل الدخول مرة أخرى.', 'malformed');
  }
  if (!payload || typeof payload !== 'object' || typeof payload.email !== 'string' || typeof payload.exp !== 'number') {
    throw authExpired_('الجلسة غير صالحة. سجّل الدخول مرة أخرى.', 'malformed');
  }
  if (payload.exp * 1000 <= rq_().now.getTime()) {
    throw authExpired_('انتهت الجلسة. سجّل الدخول مرة أخرى.', 'expired');
  }
  return payload;
}

function authStale_() {
  return apiError_('SESSION_STALE', 'تغيّرت بيانات حسابك أو صلاحياتك. سجّل الدخول مرة أخرى لتحديثها.', null, {});
}

function authNotAllowed_(email, reason) {
  const msg = reason === 'disabled'
    ? 'الحساب ' + email + ' معطّل. اطلب من المدير تفعيله ثم سجّل الدخول مرة أخرى.'
    : 'الحساب ' + email + ' غير مسجّل في قائمة المستخدمين. اطلب من المدير إضافته ثم سجّل الدخول مرة أخرى.';
  return apiError_('NOT_ALLOWED', msg, null, { email: email, reason: reason });
}

/**
 * يتحقق من الجلسة مع كل إجراء محمي ويعيد المستخدم الحالي.
 * الفحوص: التوقيع، الانتهاء، وجود الصف، تطابق البريد، الحالة نشط (إلا المدير الأساسي)، والإصدار = uv.
 * decoded: حمولة سبق فكّها بـ authDecodeSession_ (اختياري).
 */
function authVerifySession_(token, decoded) {
  const payload = decoded || authDecodeSession_(token);
  const email = payload.email.trim().toLowerCase();
  const isBootstrap = usersIsBootstrapEmail_(email);
  try {
    stRequire_(['users']);
  } catch (e) {
    // الملف غير متاح: يُسمح للمدير الأساسي فقط (لإصلاح الملف أو ربطه).
    if (isBootstrap && isSheetError_(e)) {
      const u = usersSyntheticBootstrap_(email, '', payload.uid, payload.uv);
      rq_().user = u;
      return u;
    }
    throw e;
  }
  let rec = payload.uid ? stFindById_(stTable_('users'), payload.uid) : null;
  if (rec && usersEmailOf_(rec) !== email) rec = null;
  if (!rec) {
    // الصف تغيّر (مثلًا بعد ربط ملف آخر): إن وُجد البريد في صف آخر يكفي تسجيل الدخول من جديد.
    if (usersFindByEmail_(email)) throw authStale_();
    if (isBootstrap) {
      const u = usersSyntheticBootstrap_(email, '', '', payload.uv);
      rq_().user = u;
      return u;
    }
    throw authNotAllowed_(email, 'not_listed');
  }
  const user = usersToApi_(rec);
  if (!isBootstrap && user.status !== 'active') throw authNotAllowed_(email, 'disabled');
  if (user.version !== payload.uv) throw authStale_();
  rq_().user = user;
  return user;
}

/** يرمي FORBIDDEN إن لم تكن للمستخدم الصلاحية. */
function requirePermission(user, key) {
  if (user && user.permissions && user.permissions[key] === true) return;
  throw apiError_('FORBIDDEN',
    'ليس لديك صلاحية «' + (RMN_PERM_LABELS[key] || key) + '». اطلب من المدير منحك هذه الصلاحية.',
    null, { permission: key });
}

// =====================================================================================
// الإجراءات
// =====================================================================================

/** auth.login — payload {idToken}. */
function authLoginAction_(p) {
  const idToken = inStr_(p.idToken, 'idToken', 'رمز الدخول من Google', {
    required: true, max: 8192, hint: 'سجّل الدخول بحساب Google مرة أخرى.',
  });
  const info = authVerifyGoogleToken_(idToken);
  const email = info.email;
  const isBootstrap = usersIsBootstrapEmail_(email);

  try {
    stRequire_(['users']);
  } catch (e) {
    if (isBootstrap && isSheetError_(e)) {
      // دخول طوارئ للمدير الأساسي حتى يصلح الملف أو يربط ملفًا آخر.
      return authIssueSession_(usersSyntheticBootstrap_(email, info.name, '', 0));
    }
    throw e;
  }

  let rec = usersFindByEmail_(email);
  if (isBootstrap && (!rec || usersBootstrapNeedsRepair_(rec))) {
    mainWithLock_(function () {
      rqResetTables_();
      stRequire_(['users']);
      let auditOk = true;
      try { stRequire_(['audit']); } catch (e) { auditOk = false; }
      rec = usersFindByEmail_(email);
      if (!rec) {
        rec = usersProvisionBootstrap_(email, info.name);
        rq_().user = usersToApi_(rec);
        if (auditOk) {
          auditAdd_('إنشاء', 'مستخدم', cellStr_(rec['المعرّف']),
            'إضافة المدير الأساسي ' + email + ' تلقائيًا عند أول دخول', null, { email: email, role: 'admin' }, '');
        }
      } else if (usersBootstrapNeedsRepair_(rec)) {
        const d = usersRepairBootstrap_(rec);
        rq_().user = usersToApi_(rec);
        if (auditOk) {
          auditAdd_('تعديل', 'مستخدم', cellStr_(rec['المعرّف']),
            'إصلاح صف المدير الأساسي ' + email + ' (إعادته مديرًا نشطًا)', d.prev, d.next, '');
        }
      }
      if (auditOk) auditFlush_();
      SpreadsheetApp.flush();
    });
  }
  if (!rec) throw authNotAllowed_(email, 'not_listed');
  const user = usersToApi_(rec);
  if (!isBootstrap && user.status !== 'active') throw authNotAllowed_(email, 'disabled');
  return authIssueSession_(user);
}

function authMeAction_(p, user) {
  const out = Object.assign({}, user);
  delete out.synthetic;
  return { user: out };
}

function authLogoutAction_() {
  return {};
}

// ============================================================================================
// المصدر: backend/src/Coolers.gs
// ============================================================================================

/**
 * Coolers.gs — صفحة «البرادات»: الفتح والتقفيل وإعادة الفتح، وملخص كل براد.
 * أعمدة «عند التقفيل» تُكتب لحظة التقفيل فقط، وإعادة الفتح تُبقيها كما هي.
 */

const RMN_SNAPSHOT_COLUMNS = Object.freeze({
  farmers: 'عدد المزارعين عند التقفيل',
  purchases: 'عدد العمليات عند التقفيل',
  boxes: 'الصناديق عند التقفيل',
  weightGrams: 'الوزن عند التقفيل (كغ)',
  valuePiasters: 'قيمة الرمان عند التقفيل (ج.م)',
  paidPiasters: 'المدفوع عند التقفيل (ج.م)',
  remainingPiasters: 'المتبقي عند التقفيل (ج.م)',
  packagingPiasters: 'التعبئة عند التقفيل (ج.م)',
  totalCostPiasters: 'إجمالي التكلفة عند التقفيل (ج.م)',
});

function coolerIsClosed_(rec) {
  return enumToApi_('coolerStatus', rec['الحالة'], 'open') === 'closed';
}

function coolerClosedError_(rec, message) {
  const no = cellInt_(rec['رقم البراد']);
  return apiError_('COOLER_CLOSED', message ||
    ('البراد رقم ' + no + ' مقفّل، فلا يمكن إضافة مشتريات رمان إليه أو تعديلها أو إلغاؤها. ' +
      'اطلب من المدير إعادة فتحه إن لزم التعديل.'),
    'coolerId', { coolerId: cellStr_(rec['المعرّف']), coolerNo: no });
}

/** لقطة «عند التقفيل» من الأعمدة، أو null إن لم يُقفَل البراد من قبل. */
function coolerSnapshot_(rec) {
  const C2 = RMN_SNAPSHOT_COLUMNS;
  if (!inPresent_(rec[C2.purchases]) && !inPresent_(rec[C2.valuePiasters])) return null;
  return {
    farmers: cellInt_(rec[C2.farmers]) || 0,
    purchases: cellInt_(rec[C2.purchases]) || 0,
    boxes: cellInt_(rec[C2.boxes]) || 0,
    weightGrams: cellGrams_(rec[C2.weightGrams]) || 0,
    valuePiasters: cellMoney_(rec[C2.valuePiasters]) || 0,
    paidPiasters: cellMoney_(rec[C2.paidPiasters]) || 0,
    remainingPiasters: cellMoney_(rec[C2.remainingPiasters]) || 0,
    packagingPiasters: cellMoney_(rec[C2.packagingPiasters]) || 0,
    totalCostPiasters: cellMoney_(rec[C2.totalCostPiasters]) || 0,
  };
}

/** CoolerSummary بالأرقام الحية من العمليات والدفعات الفعّالة. */
function coolerSummary_(rec) {
  const id = cellStr_(rec['المعرّف']);
  const a = dmCoolerAgg_(id);
  return {
    id: id,
    no: cellInt_(rec['رقم البراد']),
    name: cellStr_(rec['الاسم / الوصف']),
    status: enumToApi_('coolerStatus', rec['الحالة'], 'open'),
    carNo: cellStr_(rec['رقم السيارة']),
    driver: cellStr_(rec['السائق']),
    notes: cellStr_(rec['ملاحظات']),
    openedAt: cellIso_(rec['تاريخ ووقت الفتح']),
    openedBy: labelName_(rec['فتحه']),
    closedAt: cellIso_(rec['تاريخ ووقت التقفيل']),
    closedBy: labelName_(rec['قفّله']),
    farmers: a.farmers,
    purchases: a.purchases,
    boxes: a.boxes,
    weightGrams: a.weightGrams,
    valuePiasters: a.valuePiasters,
    paidPiasters: a.paidPiasters,
    remainingPiasters: a.valuePiasters - a.paidPiasters,
    packagingApprovedPiasters: a.packagingApprovedPiasters,
    packagingLatePiasters: a.packagingLatePiasters,
    totalCostPiasters: a.valuePiasters + a.packagingApprovedPiasters,
    avgPricePerKgPiasters: avgPricePerKg_(a.valuePiasters, a.weightGrams),
    version: stVersion_(rec),
    closeSnapshot: coolerSnapshot_(rec),
  };
}

function coolersSorted_() {
  const rows = stTable_('coolers').rows.slice();
  rows.sort(function (a, b) { return (cellInt_(b['رقم البراد']) || 0) - (cellInt_(a['رقم البراد']) || 0); });
  return rows;
}

/** يجد البراد أو NOT_FOUND. */
function coolersMustFind_(id, field) {
  const rec = stFindById_(stTable_('coolers'), id);
  if (!rec) failNotFound_(field || 'id', 'البراد', id);
  return rec;
}

// =====================================================================================
// الإجراءات
// =====================================================================================

/** coolers.list {status?: open|closed|all} — الأحدث أولًا. */
function coolersListAction_(p) {
  dmIndex_();
  const status = inEnum_(p.status, 'status', 'حالة البراد', { open: 'مفتوح', closed: 'مقفّل', all: 'الكل' }) || 'all';
  const list = coolersSorted_().map(coolerSummary_).filter(function (c) {
    return status === 'all' || c.status === status;
  });
  return { coolers: list };
}

/** coolers.get {id} → {cooler, purchases, packaging}. */
function coolersGetAction_(p) {
  dmIndex_();
  const id = inId_(p.id, 'id', 'البراد');
  const rec = coolersMustFind_(id, 'id');
  const purchases = stTable_('purchases').rows
    .filter(function (r) { return cellStr_(r['معرّف البراد']) === id; })
    .map(purchaseToApi_);
  purchases.sort(dmByTimeDesc_(function (x) { return x._t; }, function (x) { return x.id; }));
  const packaging = stTable_('packaging').rows
    .filter(function (r) { return cellStr_(r['معرّف البراد']) === id; })
    .map(packagingSummary_);
  packaging.sort(dmByTimeDesc_(function (x) { return x._t; }, function (x) { return x.id; }));
  return {
    cooler: coolerSummary_(rec),
    purchases: purchases.map(dmStripPrivate_),
    packaging: packaging.map(dmStripPrivate_),
  };
}

/** coolers.create {name?, carNo?, driver?, notes?} — رقم البراد = الأكبر + 1، والحالة مفتوح. */
function coolersCreateAction_(p) {
  stRequire_(stDataKeys_().concat(['audit']));
  const t = stTable_('coolers');
  const name = inStr_(p.name, 'name', 'اسم البراد / الوصف', { max: 80 });
  const carNo = inStr_(p.carNo, 'carNo', 'رقم السيارة', { max: 30 });
  const driver = inStr_(p.driver, 'driver', 'اسم السائق', { max: 80 });
  const notes = inStr_(p.notes, 'notes', 'الملاحظات', { max: 1000, multiline: true });
  const row = {
    'المعرّف': stNextId_(t, 'CL'),
    'رقم البراد': stNextNumber_(t, 'رقم البراد'),
    'الاسم / الوصف': name,
    'رقم السيارة': carNo,
    'السائق': driver,
    'تاريخ ووقت الفتح': rqNow_(),
    'الحالة': 'مفتوح',
    'فتحه': userLabel_(rq_().user),
    'ملاحظات': notes,
  };
  const rec = stAppend_(t, [row])[0];
  auditAdd_('إنشاء', 'براد', row['المعرّف'], 'فتح البراد رقم ' + row['رقم البراد'], null, row, '');
  return { cooler: coolerSummary_(rec) };
}

/** coolers.close {id, expectedVersion, clientPendingCount} — يكتب لقطة «عند التقفيل». */
function coolersCloseAction_(p) {
  stRequire_(stDataKeys_().concat(['audit']));
  const t = stTable_('coolers');
  const id = inId_(p.id, 'id', 'البراد');
  // مطلوب (العقد §6 لا يعلّمه اختياريًا): بدونه لا نعرف إن كان على الجهاز عمليات لم تُرسل بعد.
  const pending = inInt_(p.clientPendingCount, 'clientPendingCount', 'عدد العمليات بانتظار المزامنة', {
    required: true, min: 0, max: 100000,
    hint: 'حدّث التطبيق، وانتظر حتى تُرسل كل العمليات بانتظار المزامنة، ثم أعد التقفيل.',
  });
  if (pending > 0) {
    failValidation_('clientPendingCount',
      'توجد ' + pending + ' عمليات بانتظار المزامنة على هذا الجهاز. انتظر حتى تُرسل كلها (أو اتصل بالإنترنت) ثم أعد التقفيل.',
      { pending: pending });
  }
  const rec = coolersMustFind_(id, 'id');
  if (coolerIsClosed_(rec)) {
    throw coolerClosedError_(rec, 'البراد رقم ' + cellInt_(rec['رقم البراد']) + ' مقفّل بالفعل. لا حاجة لتقفيله مرة أخرى.');
  }
  const expected = inExpectedVersion_(p.expectedVersion);
  if (stVersion_(rec) !== expected) failConflict_('هذا البراد', stVersion_(rec), coolerSummary_(rec));

  const live = coolerSummary_(rec);
  const prevSnapshot = coolerSnapshot_(rec);
  const S = RMN_SNAPSHOT_COLUMNS;
  const c = {
    'الحالة': 'مقفّل',
    'تاريخ ووقت التقفيل': rqNow_(),
    'قفّله': userLabel_(rq_().user),
  };
  c[S.farmers] = live.farmers;
  c[S.purchases] = live.purchases;
  c[S.boxes] = live.boxes;
  c[S.weightGrams] = toKg_(live.weightGrams);
  c[S.valuePiasters] = toEgp_(live.valuePiasters);
  c[S.paidPiasters] = toEgp_(live.paidPiasters);
  c[S.remainingPiasters] = toEgp_(live.remainingPiasters);
  c[S.packagingPiasters] = toEgp_(live.packagingApprovedPiasters);
  c[S.totalCostPiasters] = toEgp_(live.totalCostPiasters);
  stUpdate_(t, rec, c);
  const after = coolerSummary_(rec);
  auditAdd_('تقفيل', 'براد', id,
    'تقفيل البراد رقم ' + after.no + ': ' + after.purchases + ' عملية، ' + fmtKgMsg_(after.weightGrams) +
    '، قيمة ' + fmtMoneyMsg_(after.valuePiasters),
    prevSnapshot ? { closeSnapshot: prevSnapshot } : { status: 'open' },
    { status: 'closed', closeSnapshot: after.closeSnapshot }, '');
  return { cooler: after };
}

/** coolers.reopen {id, reason} — للمدير فقط؛ تبقى اللقطة. */
function coolersReopenAction_(p) {
  stRequire_(stDataKeys_().concat(['audit']));
  const t = stTable_('coolers');
  const id = inId_(p.id, 'id', 'البراد');
  const reason = inReason_(p.reason, 'لإعادة فتح البراد');
  const rec = coolersMustFind_(id, 'id');
  if (!coolerIsClosed_(rec)) {
    failValidation_('id', 'البراد رقم ' + cellInt_(rec['رقم البراد']) + ' مفتوح بالفعل. لا حاجة لإعادة فتحه.');
  }
  if (inPresent_(p.expectedVersion)) {
    const expected = inExpectedVersion_(p.expectedVersion);
    if (stVersion_(rec) !== expected) failConflict_('هذا البراد', stVersion_(rec), coolerSummary_(rec));
  }
  stUpdate_(t, rec, { 'الحالة': 'مفتوح' });
  auditAdd_('إعادة فتح', 'براد', id, 'إعادة فتح البراد رقم ' + cellInt_(rec['رقم البراد']),
    { status: 'closed' }, { status: 'open' }, reason);
  return { cooler: coolerSummary_(rec) };
}

// ============================================================================================
// المصدر: backend/src/Dashboard.gs
// ============================================================================================

/**
 * Dashboard.gs — لوحة التحكم (dashboard.get).
 *
 * الفترة تصفّي المشتريات بتاريخ العملية، والدفعات بتاريخ الدفعة، والتعبئة بتاريخ الشراء.
 * عدد البرادات لا يتأثر بالفترة. coolerId يقصر كل شيء على براد واحد.
 * النتيجة تُحفظ في CacheService 60 ثانية بمفتاح يضم المدخلات ونسخة البيانات (تزيد مع كل كتابة).
 */

const RMN_PERIODS = Object.freeze({
  season: 'هذا الموسم',
  today: 'اليوم',
  week: 'آخر 7 أيام',
  month: 'هذا الشهر',
  all: 'كل الفترات',
});

const RMN_RECENT_LIMIT = 10;

const RMN_STATUS_LABELS = Object.freeze({
  paid: 'مدفوع', partial: 'جزئي', unpaid: 'غير مدفوع', cancelled: 'ملغاة', active: 'فعّالة',
  draft: 'مسودة', approved: 'معتمد',
});

/** حدود الفترة {from, to} (Date أو null) بتوقيت العمل. */
function dashboardRange_(key, seasonStart, now, tz) {
  const endToday = endOfLocalDay_(now, tz);
  const p = partsInTz_(now, tz);
  if (key === 'all') return { from: null, to: null };
  if (key === 'today') return { from: startOfLocalDay_(now, tz), to: endToday };
  if (key === 'week') {
    const d = addDaysYmd_(p.y, p.mo, p.d, -6);
    return { from: localToInstant_(d.y, d.mo, d.d, 0, 0, 0, tz), to: endToday };
  }
  if (key === 'month') return { from: localToInstant_(p.y, p.mo, 1, 0, 0, 0, tz), to: endToday };
  // season
  let from = null;
  if (seasonStart) {
    const d = parseDateText_(seasonStart, tz);
    if (d) from = startOfLocalDay_(d, tz);
  }
  return { from: from, to: endToday };
}

/** هل التاريخ داخل الفترة؟ (السجل بلا تاريخ يدخل فقط في فترة بلا حدود.) */
function dmInRange_(date, range) {
  if (!range || (!range.from && !range.to)) return true;
  if (!date) return false;
  const t = date.getTime();
  if (range.from && t < range.from.getTime()) return false;
  if (range.to && t > range.to.getTime()) return false;
  return true;
}

/** dashboard.get {period?, coolerId?} */
function dashboardGetAction_(p) {
  const period = inEnum_(p.period, 'period', 'الفترة', RMN_PERIODS) || 'season';
  const coolerId = inStr_(p.coolerId, 'coolerId', 'البراد', { max: 64 });
  const tz = rqTzSafe_();
  const now = rqNow_();
  const key = RMN_CFG.dashboardCachePrefix + stDataVersion_() + ':' + period + ':' + coolerId + ':' +
    Utilities.formatDate(now, tz, RMN_CFG.fmtDay) + ':' + tz;
  const hit = cacheGet_(key);
  if (hit) {
    try {
      return JSON.parse(hit);
    } catch (e) {
      // نعيد الحساب.
    }
  }
  const data = dashboardCompute_(period, coolerId, now, tz);
  cachePut_(key, JSON.stringify(data), RMN_CFG.dashboardCacheSeconds);
  return data;
}

function dashboardCompute_(period, coolerId, now, tz) {
  stRequire_(stDataKeys_().concat(['settings']));
  const settings = settingsRead_();
  const ix = dmIndex_();
  if (coolerId) coolersMustFind_(coolerId, 'coolerId');
  const range = dashboardRange_(period, settings.seasonStart, now, tz);
  const inScope = function (cid) { return !coolerId || cid === coolerId; };

  const k = {
    closedCoolers: 0, openCoolers: 0, distinctFarmers: 0, purchases: 0, boxes: 0, weightGrams: 0,
    purchaseValuePiasters: 0, packagingApprovedPiasters: 0, paidPiasters: 0, remainingPiasters: 0,
    remainingFarmersPiasters: 0, remainingSuppliersPiasters: 0, avgPricePerKgPiasters: 0,
  };
  const recent = [];
  let records = 0;

  // البرادات (لا تتأثر بالفترة)
  const coolerRows = coolersSorted_().filter(function (r) { return inScope(cellStr_(r['المعرّف'])); });
  coolerRows.forEach(function (r) {
    if (coolerIsClosed_(r)) k.closedCoolers++;
    else k.openCoolers++;
  });

  // المشتريات
  const farmers = {};
  stTable_('purchases').rows.forEach(function (r) {
    if (!inScope(cellStr_(r['معرّف البراد']))) return;
    const x = purchaseToApi_(r);
    if (!dmInRange_(x._t, range)) return;
    records++;
    recent.push({
      type: 'purchase', id: x.id, title: x.farmerName || 'مزارع',
      subtitle: dashboardSubtitle_('شراء', x.coolerNo, x.createdBy),
      coolerNo: x.coolerNo, at: x.occurredAt || x.createdAt, amountPiasters: x.valuePiasters,
      status: x.status === 'cancelled' ? 'cancelled' : x.payStatus,
      statusLabel: RMN_STATUS_LABELS[x.status === 'cancelled' ? 'cancelled' : x.payStatus],
      _t: x._t, _c: cellDate_(r['تاريخ الإنشاء الفعلي']),
    });
    if (x.status !== 'active') return;
    k.purchases++;
    k.boxes += x.boxes;
    k.weightGrams += x.totalWeightGrams;
    k.purchaseValuePiasters += x.valuePiasters;
    if (x.farmerId && !farmers[x.farmerId]) {
      farmers[x.farmerId] = true;
      k.distinctFarmers++;
    }
  });

  // مشتريات التعبئة
  stTable_('packaging').rows.forEach(function (r) {
    if (!inScope(cellStr_(r['معرّف البراد']))) return;
    const x = packagingSummary_(r);
    if (!dmInRange_(x._t, range)) return;
    records++;
    recent.push({
      type: 'packaging', id: x.id, title: x.supplier || ('شراء تعبئة ' + x.no),
      subtitle: dashboardSubtitle_('تعبئة', x.coolerNo, x.createdBy),
      coolerNo: x.coolerNo, at: x.occurredAt || x.createdAt, amountPiasters: x.completeTotalPiasters,
      status: x.status, statusLabel: RMN_STATUS_LABELS[x.status],
      _t: x._t, _c: cellDate_(r['تاريخ الإنشاء']),
    });
    if (x.status === 'approved') k.packagingApprovedPiasters += x.completeTotalPiasters;
  });

  // الدفعات
  let paidFarmers = 0;
  let paidSuppliers = 0;
  stTable_('payments').rows.forEach(function (r) {
    if (!inScope(cellStr_(r['معرّف البراد']))) return;
    const x = paymentToApi_(r);
    if (!dmInRange_(x._t, range)) return;
    records++;
    recent.push({
      type: 'payment', id: x.id, title: x.payeeName || (x.payeeType === 'supplier' ? 'مورد' : 'مزارع'),
      subtitle: dashboardSubtitle_('دفعة', x.coolerNo, x.createdBy),
      coolerNo: x.coolerNo, at: x.paidAt || x.createdAt, amountPiasters: x.amountPiasters,
      status: x.status, statusLabel: RMN_STATUS_LABELS[x.status],
      _t: x._t, _c: cellDate_(r['تاريخ الإنشاء']),
    });
    if (x.status !== 'active') return;
    k.paidPiasters += x.amountPiasters;
    if (x.targetType === 'packaging') paidSuppliers += x.amountPiasters;
    else paidFarmers += x.amountPiasters;
  });

  k.remainingPiasters = k.purchaseValuePiasters + k.packagingApprovedPiasters - k.paidPiasters;
  k.remainingFarmersPiasters = k.purchaseValuePiasters - paidFarmers;
  k.remainingSuppliersPiasters = k.packagingApprovedPiasters - paidSuppliers;
  k.avgPricePerKgPiasters = avgPricePerKg_(k.purchaseValuePiasters, k.weightGrams);

  // البراد الحالي والبرادات المفتوحة
  const open = coolerRows.filter(function (r) { return !coolerIsClosed_(r); });
  let current = null;
  if (coolerId) {
    current = coolerRows[0] || null;
  } else if (open.length) {
    current = open.slice().sort(dmByTimeDesc_(function (r) { return cellDate_(r['تاريخ ووقت الفتح']); },
      function (r) { return seqNumber_(r['المعرّف'], 'CL'); }))[0];
  }

  recent.sort(function (a, b) {
    const ta = a._t ? a._t.getTime() : 0;
    const tb = b._t ? b._t.getTime() : 0;
    if (ta !== tb) return tb - ta;
    const ca = a._c ? a._c.getTime() : 0;
    const cb = b._c ? b._c.getTime() : 0;
    if (ca !== cb) return cb - ca;
    return a.id < b.id ? 1 : (a.id > b.id ? -1 : 0);
  });

  return {
    period: {
      key: period, label: RMN_PERIODS[period],
      from: range.from ? fmtIso_(range.from) : null, to: range.to ? fmtIso_(range.to) : null,
    },
    empty: records === 0,
    kpis: k,
    currentCooler: current ? coolerSummary_(current) : null,
    openCoolers: open.map(coolerSummary_),
    recent: recent.slice(0, RMN_RECENT_LIMIT).map(dmStripPrivate_),
  };
}

function dashboardSubtitle_(kind, coolerNo, by) {
  const parts = [kind];
  if (coolerNo !== null && coolerNo !== undefined) parts.push('براد ' + coolerNo);
  if (by) parts.push(by);
  return parts.join(' · ');
}

// ============================================================================================
// المصدر: backend/src/Farmers.gs
// ============================================================================================

/**
 * Farmers.gs — صفحة «المزارعون». كل شراء مرتبط بمعرّف المزارع لا باسمه.
 */

function farmerToApi_(rec) {
  return {
    id: cellStr_(rec['المعرّف']),
    no: cellInt_(rec['رقم المزارع']),
    name: cellStr_(rec['الاسم']),
    phone: cellStr_(rec['الهاتف']),
    village: cellStr_(rec['القرية / المنطقة']),
    notes: cellStr_(rec['ملاحظات']),
    status: enumToApi_('farmerStatus', rec['الحالة'], 'active'),
    version: stVersion_(rec),
  };
}

/** رقم هاتف اختياري: أرقام مع + ومسافات وشرطات وأقواس، حتى 20 رقمًا. يُحفظ نصًا كما كُتب. */
function farmersPhoneInput_(v, field) {
  const raw = inStr_(v, field, 'رقم الهاتف', { max: 30 });
  if (!raw) return '';
  const s = digitsToLatin_(raw).replace(/\s+/g, ' ').trim();
  const digits = s.replace(/\D/g, '');
  if (!/^\+?[\d\s\-()]+$/.test(s) || digits.length < 1 || digits.length > 20) {
    failValidation_(field, 'رقم الهاتف «' + raw + '» غير صحيح. اكتب الأرقام فقط مثل 01001234567.');
  }
  return s;
}

/** مزارع بنفس الاسم بعد التطبيع (أو null). activeOnly: تجاهل الموقوفين. */
function farmersFindDuplicate_(name, excludeId, activeOnly) {
  const want = normText_(name);
  if (!want) return null;
  const rows = stTable_('farmers').rows;
  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
    if (excludeId && cellStr_(r['المعرّف']) === excludeId) continue;
    const inactive = enumToApi_('farmerStatus', r['الحالة'], 'active') !== 'active';
    if (activeOnly && inactive) continue;
    // صف أُلغي تعويضًا عن حفظ فاشل لا يمنع إعادة المحاولة.
    if (inactive && cellStr_(r['ملاحظات']).indexOf(RMN_CFG.compensationReason) >= 0) continue;
    if (normText_(r['الاسم']) === want) return r;
  }
  return null;
}

function farmersDuplicateError_(field, dup) {
  const f = farmerToApi_(dup);
  failValidation_(field,
    'يوجد مزارع مسجل بالاسم «' + f.name + '» (رقم ' + f.no + '). اختره من القائمة، أو أكّد أنه شخص مختلف لإضافته باسم مكرر.',
    { existing: f });
}

/** يضيف صف مزارع جديد ويعيد السجل (يُستخدم أيضًا من purchases.create). */
function farmersAppend_(fields) {
  const t = stTable_('farmers');
  const row = {
    'المعرّف': stNextId_(t, 'FR'),
    'رقم المزارع': stNextNumber_(t, 'رقم المزارع'),
    'الاسم': fields.name,
    'الهاتف': fields.phone || '',
    'القرية / المنطقة': fields.village || '',
    'ملاحظات': fields.notes || '',
    'الحالة': 'نشط',
    'تاريخ الإضافة': rqNow_(),
    'أضافه': userLabel_(rq_().user),
  };
  const rec = stAppend_(t, [row])[0];
  auditAdd_('إنشاء', 'مزارع', row['المعرّف'], 'إضافة المزارع «' + fields.name + '» برقم ' + row['رقم المزارع'], null, row, '');
  return rec;
}

// =====================================================================================
// الإجراءات
// =====================================================================================

/** farmers.list {query?, includeInactive?} */
function farmersListAction_(p) {
  stRequire_(['farmers']);
  const includeInactive = inBool_(p.includeInactive, 'includeInactive', 'إظهار الموقوفين', false);
  const q = normText_(p.query === undefined || p.query === null ? '' : String(p.query));
  const qDigits = q.replace(/\D/g, '');
  const list = stTable_('farmers').rows.map(farmerToApi_).filter(function (f) {
    if (!includeInactive && f.status !== 'active') return false;
    if (!q) return true;
    if (normText_(f.name).indexOf(q) >= 0) return true;
    if (normText_(f.village).indexOf(q) >= 0) return true;
    if (qDigits && qDigits === q && f.phone.replace(/\D/g, '').indexOf(qDigits) >= 0) return true;
    return String(f.no) === q;
  });
  list.sort(function (a, b) { return (a.no || 0) - (b.no || 0); });
  return { farmers: list };
}

/** farmers.create {name, phone?, village?, notes?, allowDuplicate?} */
function farmersCreateAction_(p) {
  stRequire_(['farmers', 'audit']);
  const name = inStr_(p.name, 'name', 'الاسم', { required: true, max: 80, hint: 'اكتب اسم المزارع ثم أعد المحاولة.' });
  const phone = farmersPhoneInput_(p.phone, 'phone');
  const village = inStr_(p.village, 'village', 'القرية / المنطقة', { max: 80 });
  const notes = inStr_(p.notes, 'notes', 'الملاحظات', { max: 1000, multiline: true });
  const allowDuplicate = inBool_(p.allowDuplicate, 'allowDuplicate', 'السماح بالاسم المكرر', false);
  const dup = farmersFindDuplicate_(name, null, false);
  if (dup && !allowDuplicate) farmersDuplicateError_('name', dup);
  const rec = farmersAppend_({ name: name, phone: phone, village: village, notes: notes });
  return { farmer: farmerToApi_(rec) };
}

/** farmers.update {id, expectedVersion, name?, phone?, village?, notes?, status?} */
function farmersUpdateAction_(p) {
  stRequire_(['farmers', 'audit']);
  const t = stTable_('farmers');
  const id = inId_(p.id, 'id', 'المزارع');
  const expected = inExpectedVersion_(p.expectedVersion);
  const rec = stFindById_(t, id);
  if (!rec) failNotFound_('id', 'المزارع', id);
  const current = farmerToApi_(rec);
  if (current.version !== expected) failConflict_('بيانات هذا المزارع', current.version, current);

  const c = {};
  if (p.name !== undefined) {
    const name = inStr_(p.name, 'name', 'الاسم', { required: true, max: 80, hint: 'اكتب اسم المزارع ثم أعد المحاولة.' });
    const allowDuplicate = inBool_(p.allowDuplicate, 'allowDuplicate', 'السماح بالاسم المكرر', false);
    const dup = farmersFindDuplicate_(name, id, false);
    if (dup && !allowDuplicate) farmersDuplicateError_('name', dup);
    c['الاسم'] = name;
  }
  if (p.phone !== undefined) c['الهاتف'] = farmersPhoneInput_(p.phone, 'phone');
  if (p.village !== undefined) c['القرية / المنطقة'] = inStr_(p.village, 'village', 'القرية / المنطقة', { max: 80 });
  if (p.notes !== undefined) c['ملاحظات'] = inStr_(p.notes, 'notes', 'الملاحظات', { max: 1000, multiline: true });
  if (p.status !== undefined) {
    const st = inEnum_(p.status, 'status', 'حالة المزارع', { active: 'نشط', inactive: 'موقوف' }, { required: true });
    c['الحالة'] = enumToSheet_('farmerStatus', st);
  }
  const diff = auditDiff_(rec, c);
  if (!diff.changed) return { farmer: current };
  const changes = {};
  Object.keys(diff.next).forEach(function (k) { changes[k] = c[k]; });
  stUpdate_(t, rec, changes);
  auditAdd_('تعديل', 'مزارع', id, 'تعديل بيانات المزارع «' + cellStr_(rec['الاسم']) + '»', diff.prev, diff.next, '');
  return { farmer: farmerToApi_(rec) };
}

// ============================================================================================
// المصدر: backend/src/ItemTypes.gs
// ============================================================================================

/**
 * ItemTypes.gs — صفحة «أصناف التعبئة»: قائمة الأصناف ووحداتها الافتراضية وترتيبها.
 * الصفحة بلا عمود إصدار، فالحفظ لا يتطلب expectedVersion.
 */

function itemTypeToApi_(rec) {
  return {
    id: cellStr_(rec['المعرّف']),
    name: cellStr_(rec['الصنف']),
    unit: cellStr_(rec['الوحدة الافتراضية']),
    order: cellInt_(rec['الترتيب']),
    active: rec['نشط'] === '' || rec['نشط'] === null || rec['نشط'] === undefined ? true : cellBool_(rec['نشط']),
  };
}

/** itemTypes.list → {itemTypes} مرتبة حسب «الترتيب» ثم الاسم. */
function itemTypesListAction_() {
  stRequire_(['item_types']);
  const list = stTable_('item_types').rows.map(itemTypeToApi_);
  list.sort(function (a, b) {
    const oa = a.order === null ? 1e9 : a.order;
    const ob = b.order === null ? 1e9 : b.order;
    if (oa !== ob) return oa - ob;
    return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0);
  });
  return { itemTypes: list };
}

/** itemTypes.save {id?, name, unit, order?, active?} → {itemType} */
function itemTypesSaveAction_(p) {
  stRequire_(['item_types', 'audit']);
  const t = stTable_('item_types');
  const id = inStr_(p.id, 'id', 'الصنف', { max: 64 });
  const rec = id ? stFindById_(t, id) : null;
  if (id && !rec) failNotFound_('id', 'صنف التعبئة', id);

  const name = inStr_(p.name, 'name', 'اسم الصنف', { required: true, max: 60 });
  const unit = inStr_(p.unit, 'unit', 'الوحدة الافتراضية', { required: true, max: 20, hint: 'اختر الوحدة من القائمة.' });
  if (RMN_UNITS.indexOf(unit) < 0) {
    failValidation_('unit', 'الوحدة «' + unit + '» غير معروفة. اختر واحدة من: ' + RMN_UNITS.join('، ') + '.',
      { allowed: RMN_UNITS.slice() });
  }
  const want = normText_(name);
  const dup = t.rows.filter(function (r) {
    return r !== rec && normText_(r['الصنف']) === want;
  })[0];
  if (dup) {
    failValidation_('name', 'يوجد صنف بالاسم «' + cellStr_(dup['الصنف']) + '» بالفعل' +
      (cellBool_(dup['نشط']) ? '' : ' (غير نشط، يمكنك تفعيله بدل إضافته)') + '. اختر اسمًا مختلفًا.',
      { existing: itemTypeToApi_(dup) });
  }
  let order = inInt_(p.order, 'order', 'الترتيب', { min: 1, max: 100000 });
  if (order === null) order = rec ? cellInt_(rec['الترتيب']) : stNextNumber_(t, 'الترتيب');
  const active = inBool_(p.active, 'active', 'نشط', rec ? itemTypeToApi_(rec).active : true);

  const c = {
    'الصنف': name,
    'الوحدة الافتراضية': unit,
    'الترتيب': order === null ? '' : order,
    'نشط': yesNo_(active),
  };
  if (!rec) {
    const row = Object.assign({ 'المعرّف': stNextId_(t, 'IT') }, c);
    const created = stAppend_(t, [row])[0];
    auditAdd_('إنشاء', 'إعدادات', row['المعرّف'], 'إضافة صنف التعبئة «' + name + '» بوحدة ' + unit, null, row, '');
    return { itemType: itemTypeToApi_(created) };
  }
  const diff = auditDiff_(rec, c);
  if (!diff.changed) return { itemType: itemTypeToApi_(rec) };
  const changes = {};
  Object.keys(diff.next).forEach(function (k) { changes[k] = c[k]; });
  stUpdate_(t, rec, changes);
  auditAdd_('تعديل', 'إعدادات', id, 'تعديل صنف التعبئة «' + name + '»', diff.prev, diff.next, '');
  return { itemType: itemTypeToApi_(rec) };
}

// ============================================================================================
// المصدر: backend/src/Main.gs
// ============================================================================================

/**
 * Main.gs — نقطة الدخول: doGet (فحص الصحة) وdoPost (توجيه الإجراءات).
 *
 * الرد دائمًا JSON: {ok:true, data, serverTime} أو {ok:false, error:{code, message, field, details}, serverTime}.
 * لا يخرج أي استثناء من doPost: الأخطاء غير المتوقعة تصبح INTERNAL وتُسجَّل في LAST_ERROR.
 *
 * الإجراءات التي تغيّر البيانات:
 *   1. تتطلب requestId، وتُعاد نتيجتها المحفوظة في CacheService («req:» + requestId، 6 ساعات) كما هي.
 *   2. تأخذ قفل السكربت (waitLock 25 ثانية) طوال القراءة والتحقق والكتابة.
 *   3. عند فشل كتابة لاحقة: تعويض ما كُتب، وتسجيل LAST_ERROR، وإرجاع INTERNAL دون حفظ النتيجة.
 *   4. لا يُرجع نجاح إلا بعد SpreadsheetApp.flush().
 */

/**
 * جدول الإجراءات. perm: الصلاحية المطلوبة (null = أي جلسة نشطة). write: إجراء يغيّر البيانات.
 * auth:false: لا يتطلب جلسة.
 */
function mainActions_() {
  return {
    'auth.login': { fn: authLoginAction_, auth: false },
    'auth.logout': { fn: authLogoutAction_, auth: false },
    'auth.me': { fn: authMeAction_, perm: null },

    'dashboard.get': { fn: dashboardGetAction_, perm: 'viewData' },
    'coolers.list': { fn: coolersListAction_, perm: 'viewData' },
    'coolers.get': { fn: coolersGetAction_, perm: 'viewData' },
    'farmers.list': { fn: farmersListAction_, perm: 'viewData' },
    'purchases.list': { fn: purchasesListAction_, perm: 'viewData' },
    'payments.list': { fn: paymentsListAction_, perm: 'viewData' },
    'packaging.list': { fn: packagingListAction_, perm: 'viewData' },
    'packaging.get': { fn: packagingGetAction_, perm: 'viewData' },
    'itemTypes.list': { fn: itemTypesListAction_, perm: 'viewData' },
    'settings.get': { fn: settingsGetAction_, perm: 'viewData' },

    'coolers.create': { fn: coolersCreateAction_, perm: 'recordPurchases', write: true },
    'coolers.close': { fn: coolersCloseAction_, perm: 'closeCoolers', write: true },
    'coolers.reopen': { fn: coolersReopenAction_, perm: 'reopenCoolers', write: true },
    'farmers.create': { fn: farmersCreateAction_, perm: 'addFarmers', write: true },
    'farmers.update': { fn: farmersUpdateAction_, perm: 'addFarmers', write: true },
    'purchases.create': { fn: purchasesCreateAction_, perm: 'recordPurchases', write: true },
    'purchases.update': { fn: purchasesUpdateAction_, perm: 'recordPurchases', write: true },
    'purchases.cancel': { fn: purchasesCancelAction_, perm: 'recordPurchases', write: true },
    'payments.create': { fn: paymentsCreateAction_, perm: 'recordPayments', write: true },
    'payments.cancel': { fn: paymentsCancelAction_, perm: 'recordPayments', write: true },
    'packaging.save': { fn: packagingSaveAction_, perm: 'packaging', write: true },
    'packaging.approve': { fn: packagingApproveAction_, perm: 'packaging', write: true },
    'packaging.cancel': { fn: packagingCancelAction_, perm: 'packaging', write: true },
    'itemTypes.save': { fn: itemTypesSaveAction_, perm: 'manageSettings', write: true },
    'users.list': { fn: usersListAction_, perm: 'manageUsers' },
    'users.add': { fn: usersAddAction_, perm: 'manageUsers', write: true },
    'users.update': { fn: usersUpdateAction_, perm: 'manageUsers', write: true },
    'settings.update': { fn: settingsUpdateAction_, perm: 'manageSettings', write: true },
    'sheet.status': { fn: sheetStatusAction_, perm: 'manageSettings' },
    'sheet.repair': { fn: sheetRepairAction_, perm: 'manageSettings', write: true },
    'sheet.connect': { fn: sheetConnectAction_, perm: 'manageSettings', write: true },
  };
}

// =====================================================================================
// نقاط الدخول
// =====================================================================================

/** فحص الصحة: لا يقرأ أي بيانات. */
function doGet(e) {
  rqBegin_();
  let text;
  try {
    text = mainJson_({ ok: true, data: { service: RMN_CFG.service, version: RMN_CFG.apiVersion }, serverTime: mainServerTime_() });
  } catch (err) {
    text = mainFallbackJson_(err);
  }
  return mainOutput_(text);
}

function doPost(e) {
  rqBegin_();
  let text;
  try {
    text = mainHandle_(e);
  } catch (err) {
    text = mainFallbackJson_(err);
  }
  return mainOutput_(text);
}

function mainOutput_(text) {
  return ContentService.createTextOutput(text).setMimeType(ContentService.MimeType.JSON);
}

/** آخر خط دفاع: يبني ردًا دون الاعتماد على أي شيء قد يرمي. */
function mainFallbackJson_(err) {
  try {
    return mainJson_(mainErrorEnvelope_(err));
  } catch (e2) {
    let at;
    try { at = Utilities.formatDate(new Date(), RMN_CFG.defaultTimeZone, RMN_CFG.fmtIso); } catch (e3) { at = new Date().toISOString(); }
    return JSON.stringify({
      ok: false,
      error: { code: 'INTERNAL', message: 'حدث خطأ غير متوقع في الخادم. أعد المحاولة بعد قليل، وإن تكرر فأبلغ المدير.', field: null, details: {} },
      serverTime: at,
    });
  }
}

// =====================================================================================
// التوجيه
// =====================================================================================

function mainHandle_(e) {
  const rq = rq_();
  try {
    const req = mainParseBody_(e);
    const spec = Object.prototype.hasOwnProperty.call(mainActions_(), req.action) ? mainActions_()[req.action] : null;
    if (!spec) {
      throw apiError_('UNKNOWN_ACTION', 'الإجراء «' + String(req.action).slice(0, 60) + '» غير معروف للخادم. حدّث التطبيق إلى آخر إصدار ثم أعد المحاولة.',
        'action', { action: req.action });
    }
    rq.action = req.action;

    if (spec.auth === false) {
      const data = spec.fn(req.payload, null, req);
      mainFinishWrites_();
      return mainJson_(mainOk_(data));
    }

    const session = authDecodeSession_(req.session); // AUTH_REQUIRED / AUTH_EXPIRED دون قراءة الملف

    if (!spec.write) {
      const user = authVerifySession_(req.session, session);
      if (spec.perm) requirePermission(user, spec.perm);
      const data = spec.fn(req.payload, user, req);
      mainFinishWrites_();
      return mainJson_(mainOk_(data));
    }

    req.requestId = mainRequestId_(req.requestId);
    rq.requestId = req.requestId;
    const cacheKey = RMN_CFG.requestCachePrefix + req.requestId;
    const owner = mainCacheOwner_(session);
    const cached = mainCachedResult_(cacheKey, owner);
    if (cached) return cached;

    return mainWithLock_(function () {
      rq.now = new Date();
      const again = mainCachedResult_(cacheKey, owner);
      if (again) return again;
      const user = authVerifySession_(req.session, session);
      if (spec.perm) requirePermission(user, spec.perm);
      let data;
      try {
        data = spec.fn(req.payload, user, req);
        auditFlush_();
        if (rq.wrote) SpreadsheetApp.flush();
      } catch (err) {
        mainCompensate_();
        throw err;
      }
      if (rq.wrote) stBumpDataVersion_();
      const text = mainJson_(mainOk_(data));
      cachePut_(cacheKey, JSON.stringify({ owner: owner, text: text }), RMN_CFG.requestCacheSeconds);
      return text;
    });
  } catch (err) {
    if (rq.journal && rq.journal.length) mainCompensate_();
    return mainJson_(mainErrorEnvelope_(err));
  }
}

/** صاحب النتيجة المحفوظة: من الجلسة الموقّعة نفسها (لا يحتاج قراءة الملف). */
function mainCacheOwner_(session) {
  return String(session.uid || '') + '|' + String(session.email || '').trim().toLowerCase();
}

/**
 * نتيجة طلب سابق بنفس requestId (العقد §7) تُعاد كما هي، لكن لصاحبها فقط: مستخدم آخر يعرف المعرّف
 * لا يحصل على نتيجة غيره دون فحص صلاحياته، بل يمر طلبه بالفحوص كاملة.
 */
function mainCachedResult_(cacheKey, owner) {
  const raw = cacheGet_(cacheKey);
  if (!raw) return null;
  try {
    const entry = JSON.parse(raw);
    if (entry && entry.owner === owner && typeof entry.text === 'string') return entry.text;
  } catch (e) {
    // قيمة تالفة: نتجاهلها ونكمل الطلب بالفحوص كاملة.
  }
  return null;
}

/** بعد إجراء بلا قفل كتب شيئًا (مثل إضافة المدير الأساسي عند الدخول). */
function mainFinishWrites_() {
  const rq = rq_();
  if (rq.audit.length) auditFlush_();
  if (rq.wrote) {
    SpreadsheetApp.flush();
    stBumpDataVersion_();
  }
}

/** يعوّض ما كُتب في هذا الطلب ثم يحفظ. لا يرمي. */
function mainCompensate_() {
  const rq = rq_();
  if (!rq.journal.length) {
    rq.audit = [];
    return;
  }
  try {
    stCompensate_();
  } catch (e) {
    // stCompensate_ لا يرمي عادة.
  }
  try {
    SpreadsheetApp.flush();
  } catch (e) {
    // نتجاهل.
  }
  stBumpDataVersion_();
}

/** يأخذ قفل السكربت (25 ثانية) وينفذ fn ثم يحرره دائمًا. */
function mainWithLock_(fn) {
  const rq = rq_();
  if (rq.lockHeld) return fn();
  const lock = LockService.getScriptLock();
  try {
    lock.waitLock(RMN_CFG.lockWaitMs);
  } catch (e) {
    throw apiError_('LOCK_TIMEOUT',
      'الخادم مشغول بحفظ عملية أخرى. انتظر لحظات ثم أعد المحاولة؛ لن تُسجَّل العملية مرتين.', null, {});
  }
  rq.lockHeld = true;
  try {
    return fn();
  } finally {
    rq.lockHeld = false;
    try {
      lock.releaseLock();
    } catch (e) {
      // نتجاهل.
    }
  }
}

// =====================================================================================
// الطلب والرد
// =====================================================================================

/** يقرأ جسم الطلب: {action, session, requestId, payload, client}. */
function mainParseBody_(e) {
  const raw = e && e.postData && typeof e.postData.contents === 'string' ? e.postData.contents : '';
  if (!raw.trim()) {
    throw apiError_('VALIDATION', 'الطلب فارغ. أرسل الإجراء والبيانات بصيغة JSON، أو حدّث التطبيق.', 'body', {});
  }
  let body;
  try {
    body = JSON.parse(raw);
  } catch (err) {
    throw apiError_('VALIDATION', 'تعذّر قراءة الطلب لأنه ليس JSON صالحًا. حدّث التطبيق ثم أعد المحاولة.', 'body', {});
  }
  if (!isPlainObject_(body)) {
    throw apiError_('VALIDATION', 'صيغة الطلب غير صحيحة. حدّث التطبيق ثم أعد المحاولة.', 'body', {});
  }
  if (typeof body.action !== 'string' || !body.action.trim()) {
    throw apiError_('UNKNOWN_ACTION', 'الطلب لا يحدد الإجراء المطلوب. حدّث التطبيق ثم أعد المحاولة.', 'action', { action: null });
  }
  let payload = body.payload;
  if (payload === undefined || payload === null) payload = {};
  if (!isPlainObject_(payload)) {
    throw apiError_('VALIDATION', 'بيانات الطلب (payload) يجب أن تكون كائنًا. حدّث التطبيق ثم أعد المحاولة.', 'payload', {});
  }
  return {
    action: body.action.trim(),
    session: typeof body.session === 'string' ? body.session : null,
    requestId: body.requestId,
    payload: payload,
    client: isPlainObject_(body.client) ? body.client : {},
  };
}

/** requestId مطلوب لكل إجراء يغيّر البيانات (UUID عادة). */
function mainRequestId_(v) {
  const s = typeof v === 'string' ? v.trim() : (typeof v === 'number' && isFinite(v) ? String(v) : '');
  if (!s) {
    throw apiError_('VALIDATION', 'معرّف الطلب (requestId) مطلوب لكل عملية حفظ حتى لا تتكرر. حدّث التطبيق ثم أعد المحاولة.',
      'requestId', {});
  }
  if (s.length > 128 || !/^[A-Za-z0-9._:-]+$/.test(s)) {
    throw apiError_('VALIDATION', 'معرّف الطلب (requestId) غير صالح. يجب أن يكون UUID. حدّث التطبيق ثم أعد المحاولة.',
      'requestId', {});
  }
  return s;
}

function mainOk_(data) {
  return { ok: true, data: data === undefined ? null : data, serverTime: mainServerTime_() };
}

/** يحوّل أي خطأ إلى غلاف الخطأ. غير المتوقع ⇒ INTERNAL مع تسجيل LAST_ERROR. */
function mainErrorEnvelope_(err) {
  let error;
  if (isApiError_(err)) {
    error = { code: err.code, message: err.message, field: err.field === undefined ? null : err.field, details: err.details || {} };
  } else {
    const msg = err && err.message ? String(err.message) : String(err);
    const stack = err && err.stack ? String(err.stack).split('\n').slice(0, 4).join(' | ') : '';
    const rq = rq_();
    cfgRecordError_((rq.action ? '[' + rq.action + '] ' : '') + msg + (stack ? ' :: ' + stack : ''));
    try {
      if (typeof console !== 'undefined' && console.error) console.error('INTERNAL', rq.action, msg, stack);
    } catch (e) {
      // نتجاهل.
    }
    error = {
      code: 'INTERNAL',
      message: 'حدث خطأ غير متوقع في الخادم ولم يُحفظ شيء من هذه العملية. أعد المحاولة بعد قليل، وإن تكرر فأبلغ المدير.',
      field: null,
      details: {},
    };
  }
  return { ok: false, error: error, serverTime: mainServerTime_() };
}

/** وقت الخادم ISO بتوقيت العمل. لا يفتح الملف لهذا الغرض فقط. */
function mainServerTime_() {
  const rq = rq_();
  let tz = rq.tz;
  if (!tz && rq.ss) tz = rqTzSafe_();
  if (!tz) tz = RMN_CFG.defaultTimeZone;
  try {
    return Utilities.formatDate(new Date(), tz, RMN_CFG.fmtIso);
  } catch (e) {
    return Utilities.formatDate(new Date(), RMN_CFG.defaultTimeZone, RMN_CFG.fmtIso);
  }
}

/** JSON مع تحويل أي Date إلى ISO بتوقيت العمل. */
function mainJson_(obj) {
  return JSON.stringify(obj, function (k, v) {
    const raw = this[k];
    if (isDate_(raw)) return fmtIso_(raw);
    return v;
  });
}

// ============================================================================================
// المصدر: backend/src/Packaging.gs
// ============================================================================================

/**
 * Packaging.gs — صفحتا «مشتريات التعبئة» و«تفاصيل التعبئة».
 *
 * - المسودة تُنشأ وتُعدَّل كاملة (العميل يرسل قائمة الأصناف كلها في كل حفظ).
 * - الكمية أو السعر الفارغ يبقى فارغًا (ليس صفرًا) ويجعل الصنف «غير مكتمل».
 * - الأصناف التي لم تعد في القائمة تُعلَّم «محذوف» ولا تُحذف.
 * - الاعتماد يتطلب صنفًا واحدًا على الأقل وكل الأصناف مكتملة. «تكلفة متأخرة» = نعم إن كان البراد مقفّلًا.
 */

const RMN_PACKAGING_STATUS_CHOICES = Object.freeze({ draft: 'مسودة', approved: 'معتمد', cancelled: 'ملغى', all: 'الكل' });
const RMN_PACKAGING_MAX_ITEMS = 200;
const RMN_ITEM_QTY_MAX = 10000000;
const RMN_ITEM_PRICE_MAX = 100000000;

/** إجماليات أصناف شراء تعبئة (غير المحذوفة) من فهرس الطلب (يُعاد بناؤه بعد كل كتابة). */
function packagingTotals_(packagingId) {
  const ix = dmIndex_();
  const want = cellStr_(packagingId);
  const s = ix.pk[want] || { itemsCount: 0, incompleteCount: 0, completeTotal: 0 };
  return {
    itemsCount: s.itemsCount,
    incompleteCount: s.incompleteCount,
    completeTotal: s.completeTotal,
    items: (ix.items[want] || []).slice(),
  };
}

function packagingItemToApi_(rec) {
  const f = dmItemFields_(rec);
  return {
    id: cellStr_(rec['المعرّف']),
    name: cellStr_(rec['الصنف']),
    quantity: f.quantity,
    unit: cellStr_(rec['الوحدة']),
    unitPricePiasters: f.unitPricePiasters,
    totalPiasters: f.totalPiasters,
    status: f.status,
    notes: cellStr_(rec['ملاحظات']),
    version: stVersion_(rec),
  };
}

/** صف شراء التعبئة → PackagingSummary (مع _t للترتيب). */
function packagingSummary_(rec) {
  const id = cellStr_(rec['المعرّف']);
  const tot = packagingTotals_(id);
  const status = enumToApi_('packagingStatus', rec['الحالة'], 'draft');
  const paid = dmIndex_().paid[id] || 0;
  const occurred = cellDate_(rec['تاريخ ووقت الشراء']);
  const created = cellDate_(rec['تاريخ الإنشاء']);
  const coolerId = cellStr_(rec['معرّف البراد']);
  const creator = dmWho_(rec['أنشأه']);
  return {
    id: id,
    no: cellStr_(rec['رقم الشراء']),
    supplier: cellStr_(rec['المورد']),
    invoiceNo: cellStr_(rec['رقم الفاتورة']),
    occurredAt: fmtIso_(occurred),
    coolerId: coolerId,
    coolerNo: coolerId ? dmCoolerNo_(coolerId, rec['رقم البراد']) : null,
    status: status,
    itemsCount: tot.itemsCount,
    incompleteCount: tot.incompleteCount,
    completeTotalPiasters: tot.completeTotal,
    paidPiasters: paid,
    remainingPiasters: status === 'approved' ? tot.completeTotal - paid : 0,
    late: cellBool_(rec['تكلفة متأخرة']),
    notes: cellStr_(rec['ملاحظات']),
    createdAt: fmtIso_(created),
    createdBy: creator.name,
    createdByEmail: creator.email,
    version: stVersion_(rec),
    _t: occurred || created,
  };
}

function packagingPublic_(rec) {
  return dmStripPrivate_(packagingSummary_(rec));
}

function packagingItemsPublic_(rec) {
  return packagingTotals_(rec['المعرّف']).items.map(packagingItemToApi_);
}

/** {packaging, items} كما ترجعها إجراءات الحفظ والاعتماد. */
function packagingBundle_(rec) {
  return { packaging: packagingPublic_(rec), items: packagingItemsPublic_(rec) };
}

/** الأعمدة المخزنة (العدد، غير المكتمل، الإجمالي، المدفوع، المتبقي). */
function packagingCacheColumns_(rec) {
  const id = cellStr_(rec['المعرّف']);
  const tot = packagingTotals_(id);
  const status = enumToApi_('packagingStatus', rec['الحالة'], 'draft');
  const paid = dmActivePaid_(id);
  return {
    'عدد العناصر': tot.itemsCount,
    'عناصر غير مكتملة': tot.incompleteCount,
    'إجمالي العناصر المكتملة (ج.م)': toEgp_(tot.completeTotal),
    'المدفوع (ج.م)': toEgp_(paid),
    'المتبقي (ج.م)': toEgp_(status === 'approved' ? tot.completeTotal - paid : 0),
  };
}

/** يعيد كتابة الأعمدة المخزنة إن اختلفت. كل كتابة تزيد «الإصدار» وتضع «آخر تعديل» (العقد §7). */
function packagingSyncCache_(rec, opts) {
  const c = packagingCacheColumns_(rec);
  const diff = auditDiff_(rec, c);
  if (!diff.changed) return false;
  stUpdate_(stTable_('packaging'), rec, c, opts || {});
  return true;
}

function packagingMustFind_(id, field) {
  const rec = stFindById_(stTable_('packaging'), id);
  if (!rec) failNotFound_(field || 'id', 'شراء التعبئة', id);
  return rec;
}

function packagingLabel_(rec) {
  const no = cellStr_(rec['رقم الشراء']);
  const supplier = cellStr_(rec['المورد']);
  return 'شراء التعبئة ' + no + (supplier ? ' من «' + supplier + '»' : '');
}

/** يتحقق من قائمة الأصناف كاملة قبل أي كتابة. يعيد [{id, name, quantity, unit, price, notes}]. */
function packagingItemsIn_(items, packagingId) {
  if (!Array.isArray(items)) {
    failValidation_('items', '«الأصناف» مطلوبة كقائمة. أضف الأصناف ثم احفظ.');
  }
  if (items.length > RMN_PACKAGING_MAX_ITEMS) {
    failValidation_('items', 'عدد الأصناف أكثر من ' + RMN_PACKAGING_MAX_ITEMS + '. قسّم الشراء إلى أكثر من فاتورة.',
      { max: RMN_PACKAGING_MAX_ITEMS });
  }
  const it = stTable_('packaging_items');
  const seen = {};
  return items.map(function (x, i) {
    const f = 'items[' + i + ']';
    const n = i + 1;
    if (!isPlainObject_(x)) failValidation_(f, 'الصنف رقم ' + n + ' غير صالح. احذفه وأضفه من جديد.', { index: i });
    let id = '';
    if (inPresent_(x.id)) {
      id = inStr_(x.id, f + '.id', 'معرّف الصنف رقم ' + n, { max: 64 });
      const rec = stFindById_(it, id);
      if (!rec || !packagingId || cellStr_(rec['معرّف الشراء']) !== packagingId) {
        failValidation_(f + '.id', 'الصنف رقم ' + n + ' لا يتبع هذا الشراء. حدّث البيانات ثم أعد الحفظ.', { index: i, id: id });
      }
      if (seen[id]) failValidation_(f + '.id', 'الصنف رقم ' + n + ' مكرر في القائمة. احذف التكرار ثم احفظ.', { index: i, id: id });
      seen[id] = true;
    }
    const name = inStr_(x.name, f + '.name', 'اسم الصنف رقم ' + n, { required: true, max: 80 });
    const unit = inStr_(x.unit, f + '.unit', 'وحدة الصنف رقم ' + n, { required: true, max: 20, hint: 'اختر الوحدة من القائمة.' });
    if (RMN_UNITS.indexOf(unit) < 0) {
      failValidation_(f + '.unit', 'وحدة الصنف رقم ' + n + ' («' + unit + '») غير معروفة. اختر واحدة من: ' + RMN_UNITS.join('، ') + '.',
        { index: i, allowed: RMN_UNITS.slice() });
    }
    const quantity = inInt_(x.quantity, f + '.quantity', 'كمية الصنف رقم ' + n, { min: 1, max: RMN_ITEM_QTY_MAX });
    const price = inInt_(x.unitPricePiasters, f + '.unitPricePiasters', 'سعر الوحدة للصنف رقم ' + n, {
      min: 1, max: RMN_ITEM_PRICE_MAX, fmt: fmtMoneyMsg_,
    });
    const notes = inStr_(x.notes, f + '.notes', 'ملاحظات الصنف رقم ' + n, { max: 500, multiline: true });
    return { id: id, name: name, unit: unit, quantity: quantity, price: price, notes: notes };
  });
}

/** أعمدة صف الصنف من المدخلات. */
function packagingItemColumns_(x) {
  const complete = x.quantity !== null && x.price !== null;
  return {
    'الصنف': x.name,
    'الكمية': x.quantity === null ? '' : x.quantity,
    'الوحدة': x.unit,
    'السعر المفرد (ج.م)': x.price === null ? '' : toEgp_(x.price),
    'الإجمالي (ج.م)': complete ? toEgp_(x.quantity * x.price) : '',
    'الحالة': complete ? 'مكتمل' : 'غير مكتمل',
    'ملاحظات': x.notes,
  };
}

// =====================================================================================
// الإجراءات
// =====================================================================================

/** packaging.list {status?, coolerId?} — الأحدث أولًا. */
function packagingListAction_(p) {
  dmIndex_();
  const status = inEnum_(p.status, 'status', 'حالة شراء التعبئة', RMN_PACKAGING_STATUS_CHOICES) || 'all';
  const coolerId = inStr_(p.coolerId, 'coolerId', 'البراد', { max: 64 });
  const list = stTable_('packaging').rows.filter(function (r) {
    if (coolerId && cellStr_(r['معرّف البراد']) !== coolerId) return false;
    return status === 'all' || enumToApi_('packagingStatus', r['الحالة'], 'draft') === status;
  }).map(packagingSummary_);
  list.sort(dmByTimeDesc_(function (x) { return x._t; }, function (x) { return x.id; }));
  return { packaging: list.map(dmStripPrivate_) };
}

/** packaging.get {id} → {packaging, items} */
function packagingGetAction_(p) {
  dmIndex_();
  const id = inId_(p.id, 'id', 'شراء التعبئة');
  return packagingBundle_(packagingMustFind_(id, 'id'));
}

/** packaging.save — ينشئ مسودة أو يعدّلها. الإنشاء idempotent على requestId. */
function packagingSaveAction_(p, user, req) {
  stRequire_(stDataKeys_().concat(['audit']));
  const pt = stTable_('packaging');
  const it = stTable_('packaging_items');
  const id = inStr_(p.id, 'id', 'شراء التعبئة', { max: 64 });

  let rec = null;
  if (!id) {
    const replay = stFindByKey_(pt, req.requestId);
    if (replay) return Object.assign(packagingBundle_(replay), { replayed: true });
  } else {
    rec = packagingMustFind_(id, 'id');
    const status = enumToApi_('packagingStatus', rec['الحالة'], 'draft');
    if (status !== 'draft') {
      failValidation_('id', packagingLabel_(rec) + (status === 'approved'
        ? ' معتمد، فلا يمكن تعديله. ألغِه وسجّل شراءً جديدًا إن لزم التصحيح.'
        : ' ملغى، فلا يمكن تعديله. سجّل شراءً جديدًا.'));
    }
    const expected = inExpectedVersion_(p.expectedVersion);
    if (stVersion_(rec) !== expected) {
      throw apiError_('CONFLICT', 'عدّل مستخدم آخر ' + packagingLabel_(rec) + ' بعد أن فتحته. راجع البيانات الحالية ثم أعد الحفظ.',
        'expectedVersion', { currentVersion: stVersion_(rec), current: packagingPublic_(rec), items: packagingItemsPublic_(rec) });
    }
  }

  const keep = function (v, col) { return v === undefined ? (rec ? cellStr_(rec[col]) : '') : null; };
  let supplier = keep(p.supplier, 'المورد');
  if (supplier === null) supplier = inStr_(p.supplier, 'supplier', 'اسم المورد', { max: 80 });
  let invoiceNo = keep(p.invoiceNo, 'رقم الفاتورة');
  if (invoiceNo === null) invoiceNo = inStr_(p.invoiceNo, 'invoiceNo', 'رقم الفاتورة', { max: 40 });
  let notes = keep(p.notes, 'ملاحظات');
  if (notes === null) notes = inStr_(p.notes, 'notes', 'الملاحظات', { max: 1000, multiline: true });
  let coolerId = keep(p.coolerId, 'معرّف البراد');
  let coolerNo = rec ? cellInt_(rec['رقم البراد']) : null;
  if (coolerId === null) {
    coolerId = inStr_(p.coolerId, 'coolerId', 'البراد', { max: 64 });
    coolerNo = null;
    if (coolerId) coolerNo = cellInt_(coolersMustFind_(coolerId, 'coolerId')['رقم البراد']);
  }
  let occurredAt = inTime_(p.occurredAt, 'occurredAt', 'تاريخ ووقت الشراء');
  if (!occurredAt) occurredAt = rec ? (cellDate_(rec['تاريخ ووقت الشراء']) || rqNow_()) : rqNow_();
  const items = packagingItemsIn_(p.items, id);

  // الكتابة
  const now = rqNow_();
  if (!rec) {
    const newId = stNextId_(pt, 'PK');
    const no = seqFormat_('P', stNextSeq_(pt, 'رقم الشراء', 'P'));
    let complete = 0;
    let incomplete = 0;
    items.forEach(function (x) {
      if (x.quantity !== null && x.price !== null) complete += x.quantity * x.price;
      else incomplete++;
    });
    const row = {
      'المعرّف': newId,
      'رقم الشراء': no,
      'المورد': supplier,
      'رقم الفاتورة': invoiceNo,
      'تاريخ ووقت الشراء': occurredAt,
      'معرّف البراد': coolerId,
      'رقم البراد': coolerNo === null ? '' : coolerNo,
      'الحالة': 'مسودة',
      'عدد العناصر': items.length,
      'عناصر غير مكتملة': incomplete,
      'إجمالي العناصر المكتملة (ج.م)': toEgp_(complete),
      'المدفوع (ج.م)': 0,
      'المتبقي (ج.م)': 0,
      'تكلفة متأخرة': 'لا',
      'ملاحظات': notes,
      'تاريخ الإنشاء': now,
      'أنشأه': userLabel_(user),
      'مفتاح عدم التكرار': req.requestId,
    };
    rec = stAppend_(pt, [row])[0];
    if (items.length) {
      let seq = stNextSeq_(it, 'المعرّف', 'PD');
      stAppend_(it, items.map(function (x) {
        return Object.assign({
          'المعرّف': seqFormat_('PD', seq++),
          'معرّف الشراء': newId,
          'رقم الشراء': no,
        }, packagingItemColumns_(x));
      }));
    }
    auditAdd_('إنشاء', 'شراء تعبئة', newId, 'إنشاء مسودة ' + packagingLabel_(rec) + ' بعدد ' + items.length + ' صنف', null,
      Object.assign({}, row, { items: items }), '');
    return Object.assign(packagingBundle_(rec), { replayed: false });
  }

  // تعديل مسودة قائمة
  const pid = cellStr_(rec['المعرّف']);
  const no = cellStr_(rec['رقم الشراء']);
  const before = packagingPublic_(rec);
  const beforeItems = packagingItemsPublic_(rec);
  const listed = {};
  items.forEach(function (x) { if (x.id) listed[x.id] = true; });
  const existing = packagingTotals_(pid).items;
  let touched = false;
  existing.forEach(function (r) {
    const rid = cellStr_(r['المعرّف']);
    if (!listed[rid]) {
      stUpdate_(it, r, { 'الحالة': 'محذوف' });
      touched = true;
    }
  });
  const fresh = [];
  items.forEach(function (x) {
    if (!x.id) { fresh.push(x); return; }
    const r = stFindById_(it, x.id);
    const c = packagingItemColumns_(x);
    const d = auditDiff_(r, c);
    if (d.changed) {
      const changes = {};
      Object.keys(d.next).forEach(function (k) { changes[k] = c[k]; });
      stUpdate_(it, r, changes);
      touched = true;
    }
  });
  if (fresh.length) {
    let seq = stNextSeq_(it, 'المعرّف', 'PD');
    stAppend_(it, fresh.map(function (x) {
      return Object.assign({ 'المعرّف': seqFormat_('PD', seq++), 'معرّف الشراء': pid, 'رقم الشراء': no }, packagingItemColumns_(x));
    }));
    touched = true;
  }
  const c = Object.assign({
    'المورد': supplier,
    'رقم الفاتورة': invoiceNo,
    'تاريخ ووقت الشراء': occurredAt,
    'معرّف البراد': coolerId,
    'رقم البراد': coolerNo === null ? '' : coolerNo,
    'ملاحظات': notes,
  }, packagingCacheColumns_(rec));
  const diff = auditDiff_(rec, c);
  if (!diff.changed && !touched) return Object.assign(packagingBundle_(rec), { replayed: false });
  const changes = {};
  Object.keys(c).forEach(function (k) { changes[k] = c[k]; });
  stUpdate_(pt, rec, changes);
  auditAdd_('تعديل', 'شراء تعبئة', pid, 'تعديل مسودة ' + packagingLabel_(rec),
    { packaging: before, items: beforeItems }, { packaging: packagingPublic_(rec), items: packagingItemsPublic_(rec) }, '');
  return Object.assign(packagingBundle_(rec), { replayed: false });
}

/** packaging.approve {id, expectedVersion} */
function packagingApproveAction_(p) {
  stRequire_(stDataKeys_().concat(['audit']));
  const pt = stTable_('packaging');
  const id = inId_(p.id, 'id', 'شراء التعبئة');
  const rec = packagingMustFind_(id, 'id');
  const status = enumToApi_('packagingStatus', rec['الحالة'], 'draft');
  if (status === 'approved') failValidation_('id', packagingLabel_(rec) + ' معتمد بالفعل. لا حاجة لاعتماده مرة أخرى.');
  if (status === 'cancelled') failValidation_('id', packagingLabel_(rec) + ' ملغى، فلا يمكن اعتماده. سجّل شراءً جديدًا.');
  const expected = inExpectedVersion_(p.expectedVersion);
  if (stVersion_(rec) !== expected) {
    throw apiError_('CONFLICT', 'عدّل مستخدم آخر ' + packagingLabel_(rec) + ' بعد أن فتحته. راجع البيانات الحالية ثم أعد الاعتماد.',
      'expectedVersion', { currentVersion: stVersion_(rec), current: packagingPublic_(rec), items: packagingItemsPublic_(rec) });
  }
  const tot = packagingTotals_(id);
  if (tot.itemsCount === 0) {
    failValidation_('items', 'لا يمكن اعتماد ' + packagingLabel_(rec) + ' بدون أصناف. أضف صنفًا واحدًا على الأقل ثم اعتمد.');
  }
  if (tot.incompleteCount > 0) {
    const names = tot.items.filter(function (r) { return dmItemFields_(r).status !== 'complete'; })
      .map(function (r) { return cellStr_(r['الصنف']); });
    failValidation_('items', 'لا يمكن الاعتماد: ' + tot.incompleteCount + ' صنف غير مكتمل (' + names.join('، ') +
      '). أكمل الكمية والسعر لكل صنف ثم اعتمد.', {
      incomplete: tot.items.filter(function (r) { return dmItemFields_(r).status !== 'complete'; })
        .map(function (r) { return cellStr_(r['المعرّف']); }),
    });
  }
  const coolerId = cellStr_(rec['معرّف البراد']);
  const cooler = coolerId ? stFindById_(stTable_('coolers'), coolerId) : null;
  const late = !!(cooler && coolerIsClosed_(cooler));
  const c = { 'الحالة': 'معتمد', 'تكلفة متأخرة': yesNo_(late) };
  stUpdate_(pt, rec, Object.assign(c, packagingCacheColumns_(Object.assign({}, rec, { 'الحالة': 'معتمد' }))));
  auditAdd_('تعديل', 'شراء تعبئة', id, 'اعتماد ' + packagingLabel_(rec) + ' بإجمالي ' + fmtMoneyMsg_(tot.completeTotal) +
    (late ? ' (تكلفة متأخرة: البراد ' + cellInt_(cooler['رقم البراد']) + ' مقفّل)' : ''),
    { status: 'draft' }, { status: 'approved', completeTotalPiasters: tot.completeTotal, late: late }, '');
  return packagingBundle_(rec);
}

/** packaging.cancel {id, reason} */
function packagingCancelAction_(p) {
  stRequire_(stDataKeys_().concat(['audit']));
  const pt = stTable_('packaging');
  const id = inId_(p.id, 'id', 'شراء التعبئة');
  const reason = inReason_(p.reason, 'لإلغاء شراء التعبئة');
  const rec = packagingMustFind_(id, 'id');
  const status = enumToApi_('packagingStatus', rec['الحالة'], 'draft');
  if (status === 'cancelled') failValidation_('id', packagingLabel_(rec) + ' ملغى بالفعل. لا حاجة لإلغائه مرة أخرى.');
  if (inPresent_(p.expectedVersion)) {
    const expected = inExpectedVersion_(p.expectedVersion);
    if (stVersion_(rec) !== expected) failConflict_(packagingLabel_(rec), stVersion_(rec), packagingPublic_(rec));
  }
  const count = dmActivePaymentsCount_(id);
  if (count > 0) {
    failValidation_('id', 'على ' + packagingLabel_(rec) + ' ' + count + ' دفعة فعّالة بمبلغ ' + fmtMoneyMsg_(dmActivePaid_(id)) +
      '. ألغِ الدفعات أولًا ثم ألغِ الشراء.', { activePayments: count });
  }
  stUpdate_(pt, rec, {
    'الحالة': 'ملغى',
    'المتبقي (ج.م)': 0,
    'ملاحظات': appendNote_(rec['ملاحظات'], 'سبب الإلغاء: ' + reason),
  });
  auditAdd_('إلغاء', 'شراء تعبئة', id, 'إلغاء ' + packagingLabel_(rec), { status: status }, { status: 'cancelled' }, reason);
  return { packaging: packagingPublic_(rec) };
}

// ============================================================================================
// المصدر: backend/src/Payments.gs
// ============================================================================================

/**
 * Payments.gs — صفحة «المدفوعات». كل دفعة سجل مستقل مرتبط بعملية شراء رمان أو شراء تعبئة.
 * إجمالي المدفوع في كل التقارير = مجموع الدفعات الفعّالة. الدفع مسموح حتى لو كان البراد مقفّلًا.
 */

const RMN_TARGET_TYPES = Object.freeze({ purchase: 'شراء رمان', packaging: 'شراء تعبئة' });

/** صف الدفعة → كائن Payment (مع _t للترتيب). */
function paymentToApi_(rec) {
  const paidAt = cellDate_(rec['تاريخ الدفعة']);
  const created = cellDate_(rec['تاريخ الإنشاء']);
  const coolerId = cellStr_(rec['معرّف البراد']);
  const creator = dmWho_(rec['أنشأها']);
  return {
    id: cellStr_(rec['المعرّف']),
    no: cellStr_(rec['رقم الدفعة']),
    payeeType: enumToApi_('payeeType', rec['نوع المستفيد'], 'farmer'),
    payeeName: cellStr_(rec['اسم المستفيد']),
    payeeId: cellStr_(rec['معرّف المستفيد']),
    targetType: enumToApi_('payTarget', rec['نوع العملية'], 'purchase'),
    targetId: cellStr_(rec['معرّف العملية']),
    coolerId: coolerId,
    coolerNo: coolerId ? dmCoolerNo_(coolerId, rec['رقم البراد']) : cellInt_(rec['رقم البراد']),
    amountPiasters: cellMoney_(rec['المبلغ (ج.م)']) || 0,
    method: enumToApi_('payMethod', rec['طريقة الدفع'], 'cash'),
    paidAt: fmtIso_(paidAt),
    status: enumToApi_('recordStatus', rec['الحالة'], 'active'),
    cancelReason: cellStr_(rec['سبب الإلغاء']),
    notes: cellStr_(rec['ملاحظات']),
    createdAt: fmtIso_(created),
    createdBy: creator.name,
    createdByEmail: creator.email,
    version: stVersion_(rec),
    _t: paidAt || created,
  };
}

function paymentPublic_(rec) {
  return dmStripPrivate_(paymentToApi_(rec));
}

/**
 * يضيف صف دفعة. f: {payeeType, payeeName, payeeId, targetType, targetId, coolerId, coolerNo,
 * amount, method, paidAt, notes, key}. يسجل سطر «دفعة» في سجل التعديلات.
 */
function paymentsAppend_(f) {
  const t = stTable_('payments');
  const id = stNextId_(t, 'PY');
  const no = seqFormat_('D', stNextSeq_(t, 'رقم الدفعة', 'D'));
  const row = {
    'المعرّف': id,
    'رقم الدفعة': no,
    'نوع المستفيد': enumToSheet_('payeeType', f.payeeType),
    'اسم المستفيد': f.payeeName || '',
    'معرّف المستفيد': f.payeeId || '',
    'نوع العملية': RMN_TARGET_TYPES[f.targetType],
    'معرّف العملية': f.targetId,
    'معرّف البراد': f.coolerId || '',
    'رقم البراد': f.coolerNo === null || f.coolerNo === undefined ? '' : f.coolerNo,
    'المبلغ (ج.م)': toEgp_(f.amount),
    'طريقة الدفع': RMN_PAY_METHODS[f.method],
    'تاريخ الدفعة': f.paidAt,
    'الحالة': 'فعّالة',
    'سبب الإلغاء': '',
    'ملاحظات': f.notes || '',
    'تاريخ الإنشاء': rqNow_(),
    'أنشأها': userLabel_(rq_().user),
    'مفتاح عدم التكرار': f.key || '',
  };
  const rec = stAppend_(t, [row])[0];
  const who = f.payeeType === 'farmer' ? 'للمزارع' : 'للمورد';
  auditAdd_('دفعة', 'دفعة', id, 'دفعة ' + no + ' بمبلغ ' + fmtMoneyMsg_(f.amount) + ' ' + who + ' «' + (f.payeeName || '') +
    '» عن ' + RMN_TARGET_TYPES[f.targetType] + ' ' + f.targetId + ' (' + RMN_PAY_METHODS[f.method] + ')', null, row, '');
  return rec;
}

/** يعيد حساب أعمدة المدفوع/المتبقي المخزنة على العملية المرتبطة. */
function paymentsRefreshTarget_(type, id, opts) {
  if (type === 'packaging') {
    const rec = stFindById_(stTable_('packaging'), id);
    if (rec) packagingSyncCache_(rec, opts);
    return rec;
  }
  const rec = stFindById_(stTable_('purchases'), id);
  if (rec) purchasesSyncCache_(rec, opts);
  return rec;
}

/** كائن العملية المرتبطة بالدفعة (Purchase أو PackagingSummary) أو null. */
function paymentsTargetApi_(type, id) {
  if (type === 'packaging') {
    const rec = stFindById_(stTable_('packaging'), id);
    return rec ? packagingPublic_(rec) : null;
  }
  const rec = stFindById_(stTable_('purchases'), id);
  return rec ? purchasePublic_(rec) : null;
}

// =====================================================================================
// الإجراءات
// =====================================================================================

/** payments.list {targetId?, payeeId?, coolerId?} — الأحدث أولًا، مع الملغاة. */
function paymentsListAction_(p) {
  dmIndex_();
  const targetId = inStr_(p.targetId, 'targetId', 'العملية', { max: 64 });
  const payeeId = inStr_(p.payeeId, 'payeeId', 'المستفيد', { max: 64 });
  const coolerId = inStr_(p.coolerId, 'coolerId', 'البراد', { max: 64 });
  const list = stTable_('payments').rows.filter(function (r) {
    if (targetId && cellStr_(r['معرّف العملية']) !== targetId) return false;
    if (payeeId && cellStr_(r['معرّف المستفيد']) !== payeeId) return false;
    if (coolerId && cellStr_(r['معرّف البراد']) !== coolerId) return false;
    return true;
  }).map(paymentToApi_);
  list.sort(dmByTimeDesc_(function (x) { return x._t; }, function (x) { return x.id; }));
  return { payments: list.map(dmStripPrivate_) };
}

/** payments.create {targetType, targetId, amountPiasters, method, paidAt?, notes?} — idempotent على requestId. */
function paymentsCreateAction_(p, user, req) {
  stRequire_(stDataKeys_().concat(['audit']));
  const t = stTable_('payments');
  const replay = stFindByKey_(t, req.requestId);
  if (replay) {
    const r = paymentToApi_(replay);
    return { payment: dmStripPrivate_(r), target: paymentsTargetApi_(r.targetType, r.targetId), replayed: true };
  }

  const targetType = inEnum_(p.targetType, 'targetType', 'نوع العملية', RMN_TARGET_TYPES, { required: true });
  const targetLabel = targetType === 'purchase' ? 'عملية شراء الرمان' : 'شراء التعبئة';
  const targetId = inId_(p.targetId, 'targetId', targetLabel);
  const amount = inInt_(p.amountPiasters, 'amountPiasters', 'المبلغ', {
    required: true, min: 1, max: RMN_LIMITS.amountMax, fmt: fmtMoneyMsg_,
  });
  const method = inEnum_(p.method, 'method', 'طريقة الدفع', RMN_PAY_METHODS, { required: true });
  const paidAt = inTime_(p.paidAt, 'paidAt', 'تاريخ الدفعة') || rqNow_();
  const notes = inStr_(p.notes, 'notes', 'الملاحظات', { max: 1000, multiline: true });

  let f;
  let total;
  if (targetType === 'purchase') {
    const rec = stFindById_(stTable_('purchases'), targetId);
    if (!rec) failNotFound_('targetId', 'عملية الشراء', targetId);
    if (!purchaseIsActive_(rec)) {
      failValidation_('targetId', 'عملية الشراء ' + targetId + ' ملغاة، فلا يمكن الدفع لها. حدّث البيانات واختر عملية شراء فعّالة.');
    }
    total = purchaseMeasures_(rec).valuePiasters;
    const farmerId = cellStr_(rec['معرّف المزارع']);
    const coolerId = cellStr_(rec['معرّف البراد']);
    f = {
      payeeType: 'farmer', payeeName: dmFarmerName_(farmerId, rec['اسم المزارع']), payeeId: farmerId,
      coolerId: coolerId, coolerNo: dmCoolerNo_(coolerId, rec['رقم البراد']),
    };
  } else {
    const rec = stFindById_(stTable_('packaging'), targetId);
    if (!rec) failNotFound_('targetId', 'شراء التعبئة', targetId);
    const status = enumToApi_('packagingStatus', rec['الحالة'], 'draft');
    if (status !== 'approved') {
      failValidation_('targetId', 'شراء التعبئة ' + cellStr_(rec['رقم الشراء']) + ' ' +
        (status === 'draft' ? 'ما زال مسودة. اعتمده أولًا ثم سجّل الدفعة.' : 'ملغى، فلا يمكن الدفع له.'));
    }
    total = packagingTotals_(targetId).completeTotal;
    const coolerId = cellStr_(rec['معرّف البراد']);
    f = {
      payeeType: 'supplier', payeeName: cellStr_(rec['المورد']), payeeId: '',
      coolerId: coolerId, coolerNo: coolerId ? dmCoolerNo_(coolerId, rec['رقم البراد']) : null,
    };
  }
  const paid = dmActivePaid_(targetId);
  const remaining = total - paid;
  if (remaining <= 0) {
    failValidation_('amountPiasters', 'هذه العملية مدفوعة بالكامل (' + fmtMoneyMsg_(total) + '). لا يوجد مبلغ متبقٍ للدفع.',
      { remainingPiasters: Math.max(remaining, 0) });
  }
  if (amount > remaining) {
    failValidation_('amountPiasters', '«المبلغ» (' + fmtMoneyMsg_(amount) + ') أكبر من المتبقي (' + fmtMoneyMsg_(remaining) +
      '). اكتب مبلغًا لا يزيد على المتبقي.', { remainingPiasters: remaining });
  }

  const rec = paymentsAppend_(Object.assign(f, {
    targetType: targetType, targetId: targetId, amount: amount, method: method, paidAt: paidAt, notes: notes,
    key: req.requestId,
  }));
  paymentsRefreshTarget_(targetType, targetId);
  return { payment: paymentPublic_(rec), target: paymentsTargetApi_(targetType, targetId), replayed: false };
}

/** payments.cancel {id, reason} */
function paymentsCancelAction_(p) {
  stRequire_(stDataKeys_().concat(['audit']));
  const t = stTable_('payments');
  const id = inId_(p.id, 'id', 'الدفعة');
  const reason = inReason_(p.reason, 'لإلغاء الدفعة');
  const rec = stFindById_(t, id);
  if (!rec) failNotFound_('id', 'الدفعة', id);
  const cur = paymentToApi_(rec);
  if (cur.status !== 'active') {
    failValidation_('id', 'الدفعة ' + cur.no + ' ملغاة بالفعل. لا حاجة لإلغائها مرة أخرى.');
  }
  if (inPresent_(p.expectedVersion)) {
    const expected = inExpectedVersion_(p.expectedVersion);
    if (cur.version !== expected) failConflict_('هذه الدفعة', cur.version, dmStripPrivate_(cur));
  }
  stUpdate_(t, rec, { 'الحالة': 'ملغاة', 'سبب الإلغاء': reason });
  paymentsRefreshTarget_(cur.targetType, cur.targetId);
  auditAdd_('إلغاء', 'دفعة', id, 'إلغاء الدفعة ' + cur.no + ' بمبلغ ' + fmtMoneyMsg_(cur.amountPiasters) + ' لـ «' +
    cur.payeeName + '» عن ' + RMN_TARGET_TYPES[cur.targetType] + ' ' + cur.targetId,
    { status: 'active', amountPiasters: cur.amountPiasters }, { status: 'cancelled' }, reason);
  return { payment: paymentPublic_(rec), target: paymentsTargetApi_(cur.targetType, cur.targetId) };
}

// ============================================================================================
// المصدر: backend/src/Purchases.gs
// ============================================================================================

/**
 * Purchases.gs — صفحة «مشتريات الرمان».
 *
 * الحساب (العقد §5) بأعداد صحيحة فقط:
 *   totalWeightGrams = boxes × avgWeightGrams
 *   valuePiasters    = round_half_up(totalWeightGrams × pricePerKgPiasters / 1000)
 * الصفحة تُكتب بالوحدات البشرية (كغ، ج.م). أعمدة المدفوع/المتبقي/حالة الدفع نسخة مخزنة تُعاد
 * حسابها من الدفعات الفعّالة مع كل كتابة.
 */

const RMN_WEIGHT_METHODS = Object.freeze({ direct: 'مباشر', sample: 'عينة' });
const RMN_PAY_METHODS = Object.freeze({ cash: 'نقدًا', bank: 'تحويل بنكي', wallet: 'محفظة إلكترونية' });
const RMN_PAY_MODES = Object.freeze({ full: 'دفع كامل', partial: 'دفع جزئي', none: 'بدون دفع' });

const RMN_LIMITS = Object.freeze({
  boxesMax: 100000,
  avgWeightMax: 60000,
  priceMax: 100000,
  sampleMaxCount: 200,
  sampleWeightMax: 100000,
  tareMax: 60000,
  amountMax: 1000000000000,
});

// =====================================================================================
// القراءة
// =====================================================================================

/** القياسات المخزنة للعملية (القيم المخزنة أولًا، وإلا تُحسب من المدخلات). */
function purchaseMeasures_(rec) {
  const boxes = cellInt_(rec['عدد الصناديق']) || 0;
  const avg = cellGrams_(rec['متوسط وزن الصندوق (كغ)']) || 0;
  const price = cellMoney_(rec['سعر الكيلو (ج.م)']) || 0;
  const calc = purchaseMath_(boxes, avg, price);
  const total = cellGrams_(rec['إجمالي الوزن (كغ)']);
  const value = cellMoney_(rec['إجمالي السعر (ج.م)']);
  return {
    boxes: boxes,
    avgWeightGrams: avg,
    pricePerKgPiasters: price,
    totalWeightGrams: total === null ? calc.totalWeightGrams : total,
    valuePiasters: value === null ? calc.valuePiasters : value,
  };
}

function purchaseIsActive_(rec) {
  return enumToApi_('recordStatus', rec['الحالة'], 'active') === 'active';
}

/** صف الشراء → كائن Purchase (مع _t للترتيب). */
function purchaseToApi_(rec) {
  const ix = dmIndex_();
  const id = cellStr_(rec['المعرّف']);
  const m = purchaseMeasures_(rec);
  const status = enumToApi_('recordStatus', rec['الحالة'], 'active');
  const paid = ix.paid[id] || 0;
  const method = enumToApi_('weightMethod', rec['طريقة حساب الوزن'], 'direct');
  const occurred = cellDate_(rec['تاريخ ووقت العملية']);
  const created = cellDate_(rec['تاريخ الإنشاء الفعلي']);
  const coolerId = cellStr_(rec['معرّف البراد']);
  const farmerId = cellStr_(rec['معرّف المزارع']);
  const creator = dmWho_(rec['أنشأها']);
  const editor = dmWho_(rec['عدّلها']);
  return {
    id: id,
    coolerId: coolerId,
    coolerNo: dmCoolerNo_(coolerId, rec['رقم البراد']),
    farmerId: farmerId,
    farmerName: dmFarmerName_(farmerId, rec['اسم المزارع']),
    occurredAt: fmtIso_(occurred),
    boxes: m.boxes,
    avgWeightGrams: m.avgWeightGrams,
    weightMethod: method,
    sampleWeightsGrams: method === 'sample' ? samplesParse_(rec['أوزان العينة (كغ)']) : [],
    tareGrams: method === 'sample' ? cellGrams_(rec['وزن الصندوق الفارغ (كغ)']) : null,
    totalWeightGrams: m.totalWeightGrams,
    pricePerKgPiasters: m.pricePerKgPiasters,
    valuePiasters: m.valuePiasters,
    paidPiasters: paid,
    remainingPiasters: status === 'active' ? m.valuePiasters - paid : 0,
    payStatus: payStatusOf_(m.valuePiasters, paid),
    status: status,
    cancelReason: cellStr_(rec['سبب الإلغاء']),
    notes: cellStr_(rec['ملاحظات']),
    createdAt: fmtIso_(created),
    createdBy: creator.name,
    createdByEmail: creator.email,
    updatedAt: cellIso_(rec['آخر تعديل']),
    updatedBy: editor.name,
    version: stVersion_(rec),
    _t: occurred || created,
  };
}

function purchasePublic_(rec) {
  return dmStripPrivate_(purchaseToApi_(rec));
}

/** أعمدة المدفوع/المتبقي/حالة الدفع المخزنة، محسوبة من الدفعات الفعّالة. */
function purchasesCacheColumns_(rec) {
  const m = purchaseMeasures_(rec);
  const paid = dmActivePaid_(rec['المعرّف']);
  const active = purchaseIsActive_(rec);
  return {
    'المدفوع (ج.م)': toEgp_(paid),
    'المتبقي (ج.م)': toEgp_(active ? m.valuePiasters - paid : 0),
    'حالة الدفع': enumToSheet_('payStatus', payStatusOf_(m.valuePiasters, paid)),
  };
}

/**
 * يعيد كتابة الأعمدة المخزنة (المدفوع/المتبقي/حالة الدفع) إن اختلفت.
 * العقد §7: كل كتابة على الصف تزيد «الإصدار» وتضع «آخر تعديل/عدّلها»، فتسجيل دفعة أو إلغاؤها
 * يغيّر إصدار العملية أيضًا (والرد يعيد العملية المحدّثة في target).
 */
function purchasesSyncCache_(rec, opts) {
  const c = purchasesCacheColumns_(rec);
  const diff = auditDiff_(rec, c);
  if (!diff.changed) return false;
  stUpdate_(stTable_('purchases'), rec, c, opts || {});
  return true;
}

function purchasesMustFind_(id, field) {
  const rec = stFindById_(stTable_('purchases'), id);
  if (!rec) failNotFound_(field || 'id', 'عملية الشراء', id);
  return rec;
}

/** يتحقق أن المستخدم أنشأ العملية، وإلا يطلب صلاحية «تعديل عمليات الآخرين». */
function purchasesRequireOwnerOrEditOthers_(user, rec) {
  const creator = labelEmail_(rec['أنشأها']);
  if (creator && user && creator === String(user.email || '').toLowerCase()) return;
  requirePermission(user, 'editOthers');
}

// =====================================================================================
// التحقق من المدخلات
// =====================================================================================

function purchasesBoxesIn_(v, field) {
  return inInt_(v, field, 'عدد الصناديق', { required: true, min: 1, max: RMN_LIMITS.boxesMax });
}

function purchasesAvgIn_(v, field) {
  return inInt_(v, field, 'متوسط الوزن الصافي للصندوق', { required: true, min: 1, max: RMN_LIMITS.avgWeightMax, fmt: fmtKgMsg_ });
}

function purchasesPriceIn_(v, field) {
  return inInt_(v, field, 'سعر الكيلو', { required: true, min: 1, max: RMN_LIMITS.priceMax, fmt: fmtMoneyMsg_ });
}

/** أوزان العينة: 1 إلى 200 وزن صحيح بالغرام، كل وزن > 0. */
function purchasesSamplesIn_(v, field) {
  if (!Array.isArray(v) || v.length === 0) {
    failValidation_(field, '«أوزان العينة» مطلوبة عند اختيار طريقة العينة. أدخل وزن صندوق واحد على الأقل.');
  }
  if (v.length > RMN_LIMITS.sampleMaxCount) {
    failValidation_(field, '«أوزان العينة» أكثر من ' + RMN_LIMITS.sampleMaxCount + ' وزنًا. قلّل عدد الصناديق في العينة.',
      { max: RMN_LIMITS.sampleMaxCount });
  }
  return v.map(function (x, i) {
    return inInt_(x, field, 'وزن الصندوق رقم ' + (i + 1) + ' في العينة', {
      required: true, min: 1, max: RMN_LIMITS.sampleWeightMax, fmt: fmtKgMsg_,
    });
  });
}

function purchasesTareIn_(v, field, fallback) {
  const n = inInt_(v, field, 'وزن الصندوق الفارغ', { min: 0, max: RMN_LIMITS.tareMax, fmt: fmtKgMsg_ });
  return n === null ? fallback : n;
}

/** يتحقق من أن متوسط الوزن = round(متوسط العينة − الفارغ) بفرق غرام واحد على الأكثر. */
function purchasesCheckSample_(avg, samples, tare, avgField, samplesField) {
  const expected = sampleNetAverage_(samples, tare);
  if (expected <= 0) {
    failValidation_(samplesField, 'متوسط أوزان العينة (' + fmtKgMsg_(sampleNetAverage_(samples, 0)) +
      ') لا يزيد على وزن الصندوق الفارغ (' + fmtKgMsg_(tare) + '). راجع أوزان العينة أو وزن الصندوق الفارغ.');
  }
  if (Math.abs(avg - expected) > 1) {
    failValidation_(avgField, '«متوسط الوزن الصافي للصندوق» (' + fmtKgMsg_(avg) + ') لا يطابق العينة. المتوسط الصافي المحسوب من العينة هو ' +
      fmtKgMsg_(expected) + '. أعد حساب المتوسط ثم احفظ.', { expectedGrams: expected });
  }
}

/** المزارع المختار (موجود ونشط). */
function purchasesFarmerFor_(farmerId, field) {
  const rec = stFindById_(stTable_('farmers'), farmerId);
  if (!rec) failNotFound_(field, 'المزارع', farmerId);
  if (enumToApi_('farmerStatus', rec['الحالة'], 'active') !== 'active') {
    failValidation_(field, 'المزارع «' + cellStr_(rec['الاسم']) + '» موقوف. اختر مزارعًا آخر، أو اطلب تفعيله من صفحة المزارعين.');
  }
  return rec;
}

function purchasesDescribe_(farmerName, coolerNo, boxes, avg, total, price, value) {
  return 'شراء من «' + farmerName + '» في البراد ' + coolerNo + ': ' + boxes + ' صندوق × ' + fmtKgMsg_(avg) +
    ' = ' + fmtKgMsg_(total) + ' × ' + fmtMoneyMsg_(price) + ' = ' + fmtMoneyMsg_(value);
}

// =====================================================================================
// الإجراءات
// =====================================================================================

/** purchases.list {coolerId?, farmerId?, from?, to?, includeCancelled?} — الأحدث أولًا. */
function purchasesListAction_(p) {
  dmIndex_();
  const coolerId = inStr_(p.coolerId, 'coolerId', 'البراد', { max: 64 });
  const farmerId = inStr_(p.farmerId, 'farmerId', 'المزارع', { max: 64 });
  const range = purchasesRangeIn_(p.from, p.to);
  const includeCancelled = inBool_(p.includeCancelled, 'includeCancelled', 'إظهار العمليات الملغاة', false);
  const list = stTable_('purchases').rows.filter(function (r) {
    if (coolerId && cellStr_(r['معرّف البراد']) !== coolerId) return false;
    if (farmerId && cellStr_(r['معرّف المزارع']) !== farmerId) return false;
    if (!includeCancelled && !purchaseIsActive_(r)) return false;
    return true;
  }).map(purchaseToApi_).filter(function (x) {
    return dmInRange_(x._t, range);
  });
  list.sort(dmByTimeDesc_(function (x) { return x._t; }, function (x) { return x.id; }));
  return { purchases: list.map(dmStripPrivate_) };
}

/** from/to: تاريخ ووقت ISO أو تاريخ فقط (yyyy-MM-dd ⇒ بداية اليوم / نهايته). */
function purchasesRangeIn_(from, to) {
  const tz = rqTzSafe_();
  const parse = function (v, field, label, end) {
    if (!inPresent_(v)) return null;
    const s = typeof v === 'string' ? v : '';
    const d = parseDateText_(s, tz);
    if (!d) failValidation_(field, '«' + label + '» بتنسيق غير صحيح. أرسل التاريخ مثل 2026-10-02 أو 2026-10-02T06:40:00+03:00.');
    if (isDateOnlyText_(s)) return end ? endOfLocalDay_(d, tz) : startOfLocalDay_(d, tz);
    return d;
  };
  const range = { from: parse(from, 'from', 'من تاريخ', false), to: parse(to, 'to', 'إلى تاريخ', true) };
  if (range.from && range.to && range.from.getTime() > range.to.getTime()) {
    failValidation_('to', '«إلى تاريخ» قبل «من تاريخ». صحّح الفترة ثم أعد المحاولة.');
  }
  return range;
}

/**
 * purchases.create — العقد §6. idempotent على requestId (مفتاح عدم التكرار).
 * يتحقق من كل شيء أولًا، ثم يكتب: المزارع الجديد (إن وُجد) ← الشراء ← الدفعة.
 */
function purchasesCreateAction_(p, user, req) {
  stRequire_(stDataKeys_().concat(['settings', 'audit']));
  const pt = stTable_('purchases');
  const payt = stTable_('payments');

  const replay = stFindByKey_(pt, req.requestId);
  if (replay) return purchasesReplay_(replay, req.requestId);

  // شكل الطلب والصلاحيات الإضافية
  const hasFarmerId = inPresent_(p.farmerId);
  const hasNewName = inPresent_(p.newFarmerName);
  if (hasFarmerId && hasNewName) {
    failValidation_('farmerId', 'اختر مزارعًا من القائمة أو اكتب اسم مزارع جديد، وليس الاثنين معًا.');
  }
  if (!hasFarmerId && !hasNewName) {
    failValidation_('farmerId', '«المزارع» مطلوب. اختره من القائمة أو اكتب اسم مزارع جديد.');
  }
  // payment مطلوب في العقد §6 (ليس اختياريًا)، حتى لا يضيع اختيار «دفع كامل» بسبب خطأ في التطبيق.
  const pay = p.payment;
  if (!isPlainObject_(pay)) {
    failValidation_('payment', '«الدفع مع الشراء» مطلوب. اختر «دفع كامل» أو «دفع جزئي» أو «بدون دفع» ثم أعد المحاولة.');
  }
  const mode = inEnum_(pay.mode, 'payment.mode', 'طريقة الدفع مع الشراء', RMN_PAY_MODES, { required: true });
  if (hasNewName) requirePermission(user, 'addFarmers');
  if (mode !== 'none') requirePermission(user, 'recordPayments');

  // البراد
  const coolerId = inId_(p.coolerId, 'coolerId', 'البراد');
  const cooler = coolersMustFind_(coolerId, 'coolerId');
  if (coolerIsClosed_(cooler)) throw coolerClosedError_(cooler);

  // المزارع
  let farmer = null;
  let newFarmerName = '';
  if (hasFarmerId) {
    farmer = purchasesFarmerFor_(inId_(p.farmerId, 'farmerId', 'المزارع'), 'farmerId');
  } else {
    newFarmerName = inStr_(p.newFarmerName, 'newFarmerName', 'اسم المزارع الجديد', { required: true, max: 80 });
    const dup = farmersFindDuplicate_(newFarmerName, null, true);
    if (dup) {
      const f = farmerToApi_(dup);
      failValidation_('newFarmerName', 'يوجد مزارع مسجل بالاسم «' + f.name + '» (رقم ' + f.no +
        '). اختره من القائمة بدل إضافته مرة أخرى.', { existing: f });
    }
  }

  // الوزن والسعر
  const boxes = purchasesBoxesIn_(p.boxes, 'boxes');
  const avg = purchasesAvgIn_(p.avgWeightGrams, 'avgWeightGrams');
  const method = inEnum_(p.weightMethod, 'weightMethod', 'طريقة حساب الوزن', RMN_WEIGHT_METHODS, { required: true });
  let samples = [];
  let tare = null;
  if (method === 'sample') {
    samples = purchasesSamplesIn_(p.sampleWeightsGrams, 'sampleWeightsGrams');
    tare = purchasesTareIn_(p.tareGrams, 'tareGrams', settingsRead_().emptyBoxGrams);
    purchasesCheckSample_(avg, samples, tare, 'avgWeightGrams', 'sampleWeightsGrams');
  }
  const price = purchasesPriceIn_(p.pricePerKgPiasters, 'pricePerKgPiasters');
  const occurredAt = inTime_(p.occurredAt, 'occurredAt', 'تاريخ ووقت العملية') || rqNow_();
  const notes = inStr_(p.notes, 'notes', 'الملاحظات', { max: 1000, multiline: true });
  const calc = purchaseMath_(boxes, avg, price);

  // الدفع
  let amount = 0;
  let payMethod = 'cash';
  if (mode !== 'none') {
    if (calc.valuePiasters <= 0) {
      failValidation_('payment.mode', 'قيمة العملية صفر، فلا يمكن تسجيل دفعة معها. راجع الأرقام أو اختر «بدون دفع».');
    }
    payMethod = inEnum_(pay.method, 'payment.method', 'طريقة الدفع', RMN_PAY_METHODS) || 'cash';
    if (mode === 'full') {
      amount = calc.valuePiasters;
    } else {
      amount = inInt_(pay.amountPiasters, 'payment.amountPiasters', 'المبلغ المدفوع', {
        required: true, min: 1, max: RMN_LIMITS.amountMax, fmt: fmtMoneyMsg_,
      });
      if (amount >= calc.valuePiasters) {
        failValidation_('payment.amountPiasters', '«المبلغ المدفوع» (' + fmtMoneyMsg_(amount) + ') يجب أن يكون أقل من قيمة العملية (' +
          fmtMoneyMsg_(calc.valuePiasters) + ') في الدفع الجزئي. اختر «دفع كامل» إن دُفعت القيمة كلها.',
          { valuePiasters: calc.valuePiasters });
      }
    }
  }

  // الكتابة
  let createdFarmer = null;
  if (!farmer) {
    farmer = farmersAppend_({ name: newFarmerName });
    createdFarmer = farmer;
  }
  const farmerId = cellStr_(farmer['المعرّف']);
  const farmerName = cellStr_(farmer['الاسم']);
  const coolerNo = cellInt_(cooler['رقم البراد']);
  const now = rqNow_();
  const who = userLabel_(user);
  const id = stNextId_(pt, 'PU');
  const row = {
    'المعرّف': id,
    'معرّف البراد': coolerId,
    'رقم البراد': coolerNo,
    'معرّف المزارع': farmerId,
    'اسم المزارع': farmerName,
    'تاريخ ووقت العملية': occurredAt,
    'عدد الصناديق': boxes,
    'متوسط وزن الصندوق (كغ)': toKg_(avg),
    'طريقة حساب الوزن': RMN_WEIGHT_METHODS[method],
    'أوزان العينة (كغ)': method === 'sample' ? samplesText_(samples) : '',
    'وزن الصندوق الفارغ (كغ)': method === 'sample' ? toKg_(tare) : '',
    'إجمالي الوزن (كغ)': toKg_(calc.totalWeightGrams),
    'سعر الكيلو (ج.م)': toEgp_(price),
    'إجمالي السعر (ج.م)': toEgp_(calc.valuePiasters),
    'المدفوع (ج.م)': toEgp_(amount),
    'المتبقي (ج.م)': toEgp_(calc.valuePiasters - amount),
    'حالة الدفع': enumToSheet_('payStatus', payStatusOf_(calc.valuePiasters, amount)),
    'الحالة': 'فعّالة',
    'سبب الإلغاء': '',
    'ملاحظات': notes,
    'تاريخ الإنشاء الفعلي': now,
    'أنشأها': who,
    'مفتاح عدم التكرار': req.requestId,
  };
  const rec = stAppend_(pt, [row])[0];
  auditAdd_('إنشاء', 'شراء رمان', id,
    purchasesDescribe_(farmerName, coolerNo, boxes, avg, calc.totalWeightGrams, price, calc.valuePiasters),
    null, row, '');

  let payRec = null;
  if (mode !== 'none') {
    payRec = paymentsAppend_({
      payeeType: 'farmer', payeeName: farmerName, payeeId: farmerId,
      targetType: 'purchase', targetId: id, coolerId: coolerId, coolerNo: coolerNo,
      amount: amount, method: payMethod, paidAt: occurredAt, notes: '', key: req.requestId,
    });
  }

  return {
    purchase: purchasePublic_(rec),
    payment: payRec ? paymentPublic_(payRec) : null,
    farmer: createdFarmer ? farmerToApi_(createdFarmer) : null,
    replayed: false,
  };
}

/** يعيد نتيجة purchases.create المحفوظة (نفس requestId). */
function purchasesReplay_(rec, requestId) {
  const id = cellStr_(rec['المعرّف']);
  let payment = null;
  stTable_('payments').rows.forEach(function (r) {
    if (!payment && cellStr_(r['مفتاح عدم التكرار']) === requestId && cellStr_(r['معرّف العملية']) === id) payment = r;
  });
  let farmer = null;
  const f = stFindById_(stTable_('farmers'), rec['معرّف المزارع']);
  const fAt = f ? cellDate_(f['تاريخ الإضافة']) : null;
  const pAt = cellDate_(rec['تاريخ الإنشاء الفعلي']);
  if (fAt && pAt && Math.floor(fAt.getTime() / 1000) === Math.floor(pAt.getTime() / 1000) &&
    labelEmail_(f['أضافه']) === labelEmail_(rec['أنشأها'])) {
    farmer = f; // أُنشئ المزارع في الطلب نفسه
  }
  return {
    purchase: purchasePublic_(rec),
    payment: payment ? paymentPublic_(payment) : null,
    farmer: farmer ? farmerToApi_(farmer) : null,
    replayed: true,
  };
}

/** purchases.update {id, expectedVersion, changes} */
function purchasesUpdateAction_(p, user) {
  stRequire_(stDataKeys_().concat(['settings', 'audit']));
  const pt = stTable_('purchases');
  const id = inId_(p.id, 'id', 'عملية الشراء');
  const rec = purchasesMustFind_(id, 'id');
  purchasesRequireOwnerOrEditOthers_(user, rec);
  const cooler = stFindById_(stTable_('coolers'), rec['معرّف البراد']);
  if (cooler && coolerIsClosed_(cooler)) throw coolerClosedError_(cooler);
  if (!purchaseIsActive_(rec)) {
    failValidation_('id', 'عملية الشراء ' + id + ' ملغاة، فلا يمكن تعديلها. سجّل عملية جديدة إن لزم.');
  }
  const expected = inExpectedVersion_(p.expectedVersion);
  if (stVersion_(rec) !== expected) failConflict_('عملية الشراء هذه', stVersion_(rec), purchasePublic_(rec));

  const ch = p.changes;
  if (!isPlainObject_(ch)) {
    failValidation_('changes', '«التغييرات» مطلوبة. أرسل الحقول التي تريد تعديلها.');
  }
  const has = function (k) { return Object.prototype.hasOwnProperty.call(ch, k) && ch[k] !== undefined; };
  const m = purchaseMeasures_(rec);
  const curMethod = enumToApi_('weightMethod', rec['طريقة حساب الوزن'], 'direct');
  const settings = settingsRead_();

  const boxes = has('boxes') ? purchasesBoxesIn_(ch.boxes, 'boxes') : m.boxes;
  const avg = has('avgWeightGrams') ? purchasesAvgIn_(ch.avgWeightGrams, 'avgWeightGrams') : m.avgWeightGrams;
  const price = has('pricePerKgPiasters') ? purchasesPriceIn_(ch.pricePerKgPiasters, 'pricePerKgPiasters') : m.pricePerKgPiasters;
  const method = has('weightMethod')
    ? inEnum_(ch.weightMethod, 'weightMethod', 'طريقة حساب الوزن', RMN_WEIGHT_METHODS, { required: true })
    : curMethod;
  let samples = [];
  let tare = null;
  if (method === 'sample') {
    samples = has('sampleWeightsGrams')
      ? purchasesSamplesIn_(ch.sampleWeightsGrams, 'sampleWeightsGrams')
      : (curMethod === 'sample' ? samplesParse_(rec['أوزان العينة (كغ)']) : []);
    if (!samples.length) purchasesSamplesIn_(samples, 'sampleWeightsGrams');
    const curTare = curMethod === 'sample' ? cellGrams_(rec['وزن الصندوق الفارغ (كغ)']) : null;
    tare = has('tareGrams')
      ? purchasesTareIn_(ch.tareGrams, 'tareGrams', settings.emptyBoxGrams)
      : (curTare === null ? settings.emptyBoxGrams : curTare);
    if (has('avgWeightGrams') || has('sampleWeightsGrams') || has('tareGrams') || has('weightMethod')) {
      purchasesCheckSample_(avg, samples, tare, 'avgWeightGrams', 'sampleWeightsGrams');
    }
  }

  let farmer = null;
  if (has('farmerId')) {
    const fid = inId_(ch.farmerId, 'farmerId', 'المزارع');
    if (fid !== cellStr_(rec['معرّف المزارع'])) {
      farmer = purchasesFarmerFor_(fid, 'farmerId');
      if (dmActivePaymentsCount_(id) > 0) {
        failValidation_('farmerId', 'لا يمكن تغيير المزارع لعملية عليها دفعات مسجلة باسم المزارع الحالي. ' +
          'ألغِ الدفعات أولًا، ثم غيّر المزارع وسجّل الدفعات من جديد.');
      }
    }
  }
  const occurredAt = has('occurredAt') ? inTime_(ch.occurredAt, 'occurredAt', 'تاريخ ووقت العملية') : null;
  const notes = has('notes') ? inStr_(ch.notes, 'notes', 'الملاحظات', { max: 1000, multiline: true }) : null;

  const calc = purchaseMath_(boxes, avg, price);
  const paid = dmActivePaid_(id);
  if (calc.valuePiasters < paid) {
    const field = ['pricePerKgPiasters', 'avgWeightGrams', 'boxes'].filter(has)[0] || 'boxes';
    failValidation_(field, 'القيمة الجديدة للعملية (' + fmtMoneyMsg_(calc.valuePiasters) + ') أقل من المدفوع فعلًا (' +
      fmtMoneyMsg_(paid) + '). ألغِ دفعة أولًا أو صحّح الأرقام.', { valuePiasters: calc.valuePiasters, paidPiasters: paid });
  }

  const c = {
    'عدد الصناديق': boxes,
    'متوسط وزن الصندوق (كغ)': toKg_(avg),
    'طريقة حساب الوزن': RMN_WEIGHT_METHODS[method],
    'أوزان العينة (كغ)': method === 'sample' ? samplesText_(samples) : '',
    'وزن الصندوق الفارغ (كغ)': method === 'sample' ? toKg_(tare) : '',
    'إجمالي الوزن (كغ)': toKg_(calc.totalWeightGrams),
    'سعر الكيلو (ج.م)': toEgp_(price),
    'إجمالي السعر (ج.م)': toEgp_(calc.valuePiasters),
    'المدفوع (ج.م)': toEgp_(paid),
    'المتبقي (ج.م)': toEgp_(calc.valuePiasters - paid),
    'حالة الدفع': enumToSheet_('payStatus', payStatusOf_(calc.valuePiasters, paid)),
  };
  if (farmer) {
    c['معرّف المزارع'] = cellStr_(farmer['المعرّف']);
    c['اسم المزارع'] = cellStr_(farmer['الاسم']);
  }
  if (occurredAt) c['تاريخ ووقت العملية'] = occurredAt;
  if (notes !== null) c['ملاحظات'] = notes;

  const diff = auditDiff_(rec, c);
  if (!diff.changed) return { purchase: purchasePublic_(rec) };
  const changes = {};
  Object.keys(diff.next).forEach(function (k) { changes[k] = c[k]; });
  stUpdate_(pt, rec, changes);
  auditAdd_('تعديل', 'شراء رمان', id, 'تعديل عملية الشراء ' + id + ' من «' + cellStr_(rec['اسم المزارع']) +
    '» (القيمة الآن ' + fmtMoneyMsg_(calc.valuePiasters) + ')', diff.prev, diff.next, '');
  return { purchase: purchasePublic_(rec) };
}

/** purchases.cancel {id, reason} */
function purchasesCancelAction_(p, user) {
  stRequire_(stDataKeys_().concat(['audit']));
  const pt = stTable_('purchases');
  const id = inId_(p.id, 'id', 'عملية الشراء');
  const reason = inReason_(p.reason, 'لإلغاء عملية الشراء');
  const rec = purchasesMustFind_(id, 'id');
  purchasesRequireOwnerOrEditOthers_(user, rec);
  const cooler = stFindById_(stTable_('coolers'), rec['معرّف البراد']);
  if (cooler && coolerIsClosed_(cooler)) throw coolerClosedError_(cooler);
  if (!purchaseIsActive_(rec)) {
    failValidation_('id', 'عملية الشراء ' + id + ' ملغاة بالفعل. لا حاجة لإلغائها مرة أخرى.');
  }
  if (inPresent_(p.expectedVersion)) {
    const expected = inExpectedVersion_(p.expectedVersion);
    if (stVersion_(rec) !== expected) failConflict_('عملية الشراء هذه', stVersion_(rec), purchasePublic_(rec));
  }
  const count = dmActivePaymentsCount_(id);
  if (count > 0) {
    failValidation_('id', 'على عملية الشراء ' + id + ' ' + count + ' دفعة فعّالة بمبلغ ' + fmtMoneyMsg_(dmActivePaid_(id)) +
      '. ألغِ الدفعات أولًا ثم ألغِ العملية.', { activePayments: count });
  }
  const m = purchaseMeasures_(rec);
  const before = { status: 'active', valuePiasters: m.valuePiasters };
  stUpdate_(pt, rec, {
    'الحالة': 'ملغاة',
    'سبب الإلغاء': reason,
    'المدفوع (ج.م)': 0,
    'المتبقي (ج.م)': 0,
    'حالة الدفع': enumToSheet_('payStatus', 'unpaid'),
  });
  auditAdd_('إلغاء', 'شراء رمان', id, 'إلغاء عملية الشراء ' + id + ' من «' + cellStr_(rec['اسم المزارع']) + '» بقيمة ' +
    fmtMoneyMsg_(m.valuePiasters), before, { status: 'cancelled' }, reason);
  return { purchase: purchasePublic_(rec) };
}

// ============================================================================================
// المصدر: backend/src/Records.gs
// ============================================================================================

/**
 * Records.gs — فهرس مشترك لكل طلب يربط السجلات ببعضها ويحسب المجاميع الحية:
 * المدفوع لكل عملية (من الدفعات الفعّالة)، وأصناف كل شراء تعبئة، ومجاميع كل براد.
 * يُبنى مرة واحدة من الصفحات المحفوظة في الذاكرة، ويُعاد بناؤه تلقائيًا بعد أي كتابة.
 */

function dmEmptyAgg_() {
  return {
    farmerIds: {}, farmers: 0, purchases: 0, boxes: 0, weightGrams: 0, valuePiasters: 0, paidPiasters: 0,
    packagingApprovedPiasters: 0, packagingLatePiasters: 0,
  };
}

/** يحسب بيانات صنف التعبئة من صفه (الحالة «مكتمل» تُشتق من وجود الكمية والسعر). */
function dmItemFields_(rec) {
  const quantity = cellInt_(rec['الكمية']);
  const price = cellMoney_(rec['السعر المفرد (ج.م)']);
  const stored = enumToApi_('itemStatus', rec['الحالة'], 'incomplete');
  const complete = quantity !== null && price !== null;
  let total = null;
  if (complete) {
    total = cellMoney_(rec['الإجمالي (ج.م)']);
    if (total === null) total = quantity * price;
  }
  return {
    quantity: quantity,
    unitPricePiasters: price,
    totalPiasters: total,
    status: stored === 'removed' ? 'removed' : (complete ? 'complete' : 'incomplete'),
  };
}

function dmIndex_() {
  const rq = rq_();
  if (rq.index) return rq.index;
  stRequire_(stDataKeys_());
  const ix = {
    coolers: Object.create(null),
    farmers: Object.create(null),
    paid: Object.create(null),
    payments: Object.create(null), // targetId → [سجلات الدفعات الفعّالة]
    items: Object.create(null), // packagingId → [سجلات الأصناف غير المحذوفة]
    pk: Object.create(null), // packagingId → {itemsCount, incompleteCount, completeTotal}
    coolerAgg: Object.create(null),
  };
  stTable_('coolers').rows.forEach(function (r) { ix.coolers[cellStr_(r['المعرّف'])] = r; });
  stTable_('farmers').rows.forEach(function (r) { ix.farmers[cellStr_(r['المعرّف'])] = r; });

  stTable_('payments').rows.forEach(function (r) {
    if (enumToApi_('recordStatus', r['الحالة'], 'active') !== 'active') return;
    const target = cellStr_(r['معرّف العملية']);
    if (!target) return;
    ix.paid[target] = (ix.paid[target] || 0) + (cellMoney_(r['المبلغ (ج.م)']) || 0);
    (ix.payments[target] = ix.payments[target] || []).push(r);
  });

  stTable_('packaging_items').rows.forEach(function (r) {
    const pkId = cellStr_(r['معرّف الشراء']);
    if (!pkId) return;
    const f = dmItemFields_(r);
    if (f.status === 'removed') return;
    (ix.items[pkId] = ix.items[pkId] || []).push(r);
    const s = ix.pk[pkId] = ix.pk[pkId] || { itemsCount: 0, incompleteCount: 0, completeTotal: 0 };
    s.itemsCount++;
    if (f.status === 'complete') s.completeTotal += f.totalPiasters;
    else s.incompleteCount++;
  });

  const agg = function (coolerId) {
    return ix.coolerAgg[coolerId] = ix.coolerAgg[coolerId] || dmEmptyAgg_();
  };

  stTable_('purchases').rows.forEach(function (r) {
    if (enumToApi_('recordStatus', r['الحالة'], 'active') !== 'active') return;
    const coolerId = cellStr_(r['معرّف البراد']);
    if (!coolerId) return;
    const a = agg(coolerId);
    const m = purchaseMeasures_(r);
    const farmerId = cellStr_(r['معرّف المزارع']);
    if (farmerId && !a.farmerIds[farmerId]) {
      a.farmerIds[farmerId] = true;
      a.farmers++;
    }
    a.purchases++;
    a.boxes += m.boxes;
    a.weightGrams += m.totalWeightGrams;
    a.valuePiasters += m.valuePiasters;
    a.paidPiasters += ix.paid[cellStr_(r['المعرّف'])] || 0;
  });

  stTable_('packaging').rows.forEach(function (r) {
    if (enumToApi_('packagingStatus', r['الحالة'], 'draft') !== 'approved') return;
    const coolerId = cellStr_(r['معرّف البراد']);
    if (!coolerId) return;
    const a = agg(coolerId);
    const total = (ix.pk[cellStr_(r['المعرّف'])] || { completeTotal: 0 }).completeTotal;
    a.packagingApprovedPiasters += total;
    if (cellBool_(r['تكلفة متأخرة'])) a.packagingLatePiasters += total;
  });

  rq.index = ix;
  return ix;
}

function dmCoolerAgg_(coolerId) {
  return dmIndex_().coolerAgg[coolerId] || dmEmptyAgg_();
}

function dmFarmerName_(farmerId, fallback) {
  const r = dmIndex_().farmers[farmerId];
  return r ? cellStr_(r['الاسم']) : cellStr_(fallback);
}

function dmCoolerNo_(coolerId, fallback) {
  const r = dmIndex_().coolers[coolerId];
  if (r) return cellInt_(r['رقم البراد']);
  return cellInt_(fallback);
}

/** ترتيب تنازلي بالوقت ثم بالمعرّف. */
function dmByTimeDesc_(getTime, getId) {
  return function (a, b) {
    const ta = getTime(a);
    const tb = getTime(b);
    const va = ta ? ta.getTime() : 0;
    const vb = tb ? tb.getTime() : 0;
    if (va !== vb) return vb - va;
    const ia = getId(a);
    const ib = getId(b);
    return ia < ib ? 1 : (ia > ib ? -1 : 0);
  };
}

/** يحذف الحقول المساعدة (التي تبدأ بـ _) قبل الإرسال. */
function dmStripPrivate_(obj) {
  const out = {};
  Object.keys(obj).forEach(function (k) {
    if (k.charAt(0) !== '_') out[k] = obj[k];
  });
  return out;
}

/** مجموع الدفعات الفعّالة لعملية (من الصفحة المحفوظة في الذاكرة، بعد آخر كتابة). */
function dmActivePaid_(targetId) {
  const want = cellStr_(targetId);
  let sum = 0;
  stTable_('payments').rows.forEach(function (r) {
    if (cellStr_(r['معرّف العملية']) !== want) return;
    if (enumToApi_('recordStatus', r['الحالة'], 'active') !== 'active') return;
    sum += cellMoney_(r['المبلغ (ج.م)']) || 0;
  });
  return sum;
}

/** عدد الدفعات الفعّالة لعملية. */
function dmActivePaymentsCount_(targetId) {
  const want = cellStr_(targetId);
  let n = 0;
  stTable_('payments').rows.forEach(function (r) {
    if (cellStr_(r['معرّف العملية']) === want && enumToApi_('recordStatus', r['الحالة'], 'active') === 'active') n++;
  });
  return n;
}

/** اسم المستخدم من عمود «الاسم (البريد)»، والبريد منه. */
function dmWho_(label) {
  return { name: labelName_(label), email: labelEmail_(label) };
}

// ============================================================================================
// المصدر: backend/src/Settings.gs
// ============================================================================================

/**
 * Settings.gs — إعدادات العمل من صفحة «الإعدادات» (مفتاح/قيمة)، والمنطقة الزمنية للطلب.
 */

// اسم الإعداد في الـ API → المفتاح في الصفحة.
const RMN_SETTING_KEYS = Object.freeze({
  businessName: 'اسم النشاط',
  currency: 'العملة',
  currencySymbol: 'رمز العملة',
  timezone: 'المنطقة الزمنية',
  moneyDecimals: 'منازل المبالغ',
  weightDecimals: 'منازل الأوزان',
  emptyBoxGrams: 'وزن الصندوق الفارغ (كغ)',
  seasonStart: 'بداية الموسم',
});

const RMN_SETTING_DEFAULTS = Object.freeze({
  businessName: 'حاسبة الحسناوي',
  currency: 'جنيه مصري (EGP)',
  currencySymbol: 'ج.م',
  timezone: 'Africa/Cairo',
  moneyDecimals: 2,
  weightDecimals: 1,
  emptyBoxGrams: 1900,
  seasonStart: null,
});

// مناطق إزاحتها صفر طوال السنة. Utilities.formatDate لا يرمي خطأ لاسم منطقة غير معروف بل يستخدم
// GMT بصمت، لذلك لا نقبل منطقة إزاحتها صفر في يناير ويوليو معًا إلا إن كانت في هذه القائمة.
const RMN_ZERO_OFFSET_ZONES = Object.freeze([
  'UTC', 'GMT', 'Etc/UTC', 'Etc/GMT', 'Etc/UCT', 'Etc/Universal', 'Etc/Zulu', 'Etc/Greenwich', 'Etc/GMT0',
  'Etc/GMT+0', 'Etc/GMT-0', 'Africa/Abidjan', 'Africa/Accra', 'Africa/Bamako', 'Africa/Banjul', 'Africa/Bissau',
  'Africa/Conakry', 'Africa/Dakar', 'Africa/Freetown', 'Africa/Lome', 'Africa/Monrovia', 'Africa/Nouakchott',
  'Africa/Ouagadougou', 'Africa/Sao_Tome', 'Africa/Timbuktu', 'America/Danmarkshavn', 'Atlantic/Reykjavik',
  'Atlantic/St_Helena',
]);

/** هل النص منطقة زمنية معروفة (مثل Africa/Cairo)؟ */
function settingsValidTz_(tz) {
  if (typeof tz !== 'string') return false;
  const s = tz.trim();
  if (!/^(?:UTC|GMT|[A-Za-z]+(?:\/[A-Za-z0-9_+\-]+){1,2})$/.test(s)) return false;
  let offsets;
  try {
    const y = new Date().getUTCFullYear();
    offsets = [new Date(Date.UTC(y, 0, 15, 12)), new Date(Date.UTC(y, 6, 15, 12))].map(function (d) {
      const iso = Utilities.formatDate(d, s, RMN_CFG.fmtIso);
      if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(iso)) throw new Error('bad format');
      return iso.slice(19);
    });
  } catch (e) {
    return false;
  }
  const alwaysZero = offsets.every(function (o) { return o === 'Z' || o === '+00:00' || o === '-00:00'; });
  return !alwaysZero || RMN_ZERO_OFFSET_ZONES.indexOf(s) >= 0;
}

/** صفوف الإعدادات: {المفتاح: السجل}. */
function settingsRows_() {
  const t = stTable_('settings');
  const out = Object.create(null);
  t.rows.forEach(function (r) {
    const k = cellStr_(r['المفتاح']);
    if (k && !out[k]) out[k] = r;
  });
  return out;
}

/**
 * المنطقة الزمنية للعمل لهذا الطلب. لا تعتمد على settingsRead_ حتى لا تحدث حلقة،
 * وتعود إلى Africa/Cairo عند أي مشكلة في الملف.
 */
function settingsTimeZone_() {
  const rq = rq_();
  if (rq.tz) return rq.tz;
  rq.tz = RMN_CFG.defaultTimeZone; // مؤقتًا، يمنع الاستدعاء الدائري
  try {
    const t = stTable_('settings');
    if (!t.missing.length) {
      const rec = settingsRows_()[RMN_SETTING_KEYS.timezone];
      const v = rec && typeof rec['القيمة'] === 'string' ? rec['القيمة'].trim() : '';
      if (v && settingsValidTz_(v)) rq.tz = v;
    }
  } catch (e) {
    // نبقي الافتراضي.
  }
  return rq.tz;
}

function settingsDayText_(v) {
  if (v === '' || v === null || v === undefined) return null;
  const d = cellDate_(v);
  return d ? fmtDay_(d) : null;
}

function settingsClampInt_(v, min, max, def) {
  const n = cellInt_(v);
  return n === null || n < min || n > max ? def : n;
}

/** الإعدادات بشكل الـ API. */
function settingsRead_() {
  const rq = rq_();
  if (rq.settings) return rq.settings;
  stRequire_(['settings']);
  const tz = settingsTimeZone_();
  const rows = settingsRows_();
  const val = function (apiKey) {
    const r = rows[RMN_SETTING_KEYS[apiKey]];
    return r ? r['القيمة'] : '';
  };
  const d = RMN_SETTING_DEFAULTS;
  const box = cellGrams_(val('emptyBoxGrams'));
  const s = {
    businessName: cellStr_(val('businessName')) || d.businessName,
    currency: cellStr_(val('currency')) || d.currency,
    currencySymbol: cellStr_(val('currencySymbol')) || d.currencySymbol,
    timezone: tz,
    moneyDecimals: settingsClampInt_(val('moneyDecimals'), 0, 3, d.moneyDecimals),
    weightDecimals: settingsClampInt_(val('weightDecimals'), 0, 3, d.weightDecimals),
    emptyBoxGrams: box !== null && box >= 0 && box <= 60000 ? box : d.emptyBoxGrams,
    seasonStart: settingsDayText_(val('seasonStart')),
  };
  rq.settings = s;
  return s;
}

function settingsGetAction_() {
  return Object.assign({}, settingsRead_());
}

/** settings.update — يكتب القيم المرسلة فقط. */
function settingsUpdateAction_(p) {
  stRequire_(['settings', 'audit']);
  const cur = settingsRead_();
  const next = {};

  if (p.businessName !== undefined) {
    next.businessName = inStr_(p.businessName, 'businessName', 'اسم النشاط', { required: true, max: 80 });
  }
  if (p.currencySymbol !== undefined) {
    next.currencySymbol = inStr_(p.currencySymbol, 'currencySymbol', 'رمز العملة', { required: true, max: 10 });
  }
  if (p.timezone !== undefined) {
    const tz = inStr_(p.timezone, 'timezone', 'المنطقة الزمنية', { required: true, max: 64, hint: 'اكتبها مثل Africa/Cairo.' });
    if (!settingsValidTz_(tz)) {
      failValidation_('timezone', 'المنطقة الزمنية «' + tz + '» غير معروفة. اكتبها بالإنجليزية مثل Africa/Cairo.');
    }
    next.timezone = tz;
  }
  if (p.moneyDecimals !== undefined) {
    next.moneyDecimals = inInt_(p.moneyDecimals, 'moneyDecimals', 'منازل المبالغ', { required: true, min: 0, max: 3 });
  }
  if (p.weightDecimals !== undefined) {
    next.weightDecimals = inInt_(p.weightDecimals, 'weightDecimals', 'منازل الأوزان', { required: true, min: 0, max: 3 });
  }
  if (p.emptyBoxGrams !== undefined) {
    next.emptyBoxGrams = inInt_(p.emptyBoxGrams, 'emptyBoxGrams', 'وزن الصندوق الفارغ', {
      required: true, min: 0, max: 60000, fmt: fmtKgMsg_,
    });
  }
  if (p.seasonStart !== undefined) {
    const raw = inStr_(p.seasonStart, 'seasonStart', 'بداية الموسم', { required: true, max: 10, hint: 'اكتب التاريخ مثل 2026-08-01.' });
    const s = digitsToLatin_(raw);
    if (!isDateOnlyText_(s) || !parseDateText_(s, settingsTimeZone_())) {
      failValidation_('seasonStart', 'تاريخ «بداية الموسم» غير صحيح. اكتبه بالشكل 2026-08-01.');
    }
    const parts = s.split('-');
    next.seasonStart = parts[0] + '-' + ('0' + Number(parts[1])).slice(-2) + '-' + ('0' + Number(parts[2])).slice(-2);
  }

  const keys = Object.keys(next).filter(function (k) { return next[k] !== cur[k]; });
  if (!keys.length) return Object.assign({}, cur);

  const t = stTable_('settings');
  const rows = settingsRows_();
  const prev = {};
  const after = {};
  keys.forEach(function (k) {
    const sheetKey = RMN_SETTING_KEYS[k];
    const v = k === 'emptyBoxGrams' ? toKg_(next[k]) : next[k];
    prev[k] = cur[k];
    after[k] = next[k];
    const rec = rows[sheetKey];
    if (rec) {
      stUpdate_(t, rec, { 'القيمة': v }, { bump: false });
    } else {
      stAppend_(t, [{ 'المفتاح': sheetKey, 'القيمة': v, 'الوصف': '' }], { track: false });
    }
  });
  auditAdd_('تعديل', 'إعدادات', 'settings',
    'تعديل الإعدادات: ' + keys.map(function (k) { return RMN_SETTING_KEYS[k]; }).join('، '), prev, after, '');
  const rq = rq_();
  rq.settings = null;
  rq.tz = null;
  return Object.assign({}, settingsRead_());
}

// ============================================================================================
// المصدر: backend/src/SheetAdmin.gs
// ============================================================================================

/**
 * SheetAdmin.gs — حالة ملف Google Sheets وإصلاحه وربط ملف آخر (للمدير).
 *
 * - sheet.status: قراءة فقط.
 * - sheet.repair: يُنشئ الصفحات والأعمدة الناقصة ويعيد التنسيق باستخدام buildDataSheet_ وbuildSummary_
 *   من sheets/setup.gs، ولا يحذف أي بيانات أو صفحات.
 * - sheet.connect: يتحقق أن openById يعمل قبل حفظ SPREADSHEET_ID. لا ينقل البيانات القديمة.
 */

const RMN_CONNECT_WARNING =
  'البيانات القديمة لا تُنقل تلقائيًا إلى الملف الجديد. المستخدمون والبرادات والعمليات المسجلة في الملف السابق تبقى فيه. ' +
  'إن كان الملف الجديد فارغًا فاضغط «إصلاح الملف» لإنشاء الصفحات، ثم أضف المستخدمين من جديد.';

function sheetConnectedAs_() {
  try {
    const u = Session.getEffectiveUser();
    const e = u ? u.getEmail() : '';
    return e ? String(e) : null;
  } catch (e) {
    return null;
  }
}

/** SheetStatus كما في العقد §6. لا يرمي أخطاء الملف بل يصفها في problem. */
function sheetStatus_() {
  const propId = cfgGet_(RMN_PROP.spreadsheetId).trim();
  let ss = null;
  let problem = null;
  try {
    ss = stSpreadsheet_();
  } catch (e) {
    if (!isSheetError_(e)) throw e;
    problem = { code: e.code, message: e.message };
  }
  const out = {
    configured: !!(propId || ss),
    spreadsheetId: ss ? ss.getId() : (propId || null),
    source: propId ? 'connected' : 'bound',
    title: ss ? ss.getName() : null,
    url: ss ? ss.getUrl() : null,
    connectedAs: sheetConnectedAs_(),
    timezone: null,
    ok: false,
    sheets: [],
    summarySheet: null,
    lastWriteAt: cfgGet_(RMN_PROP.lastWriteAt) || null,
    lastError: cfgLastError_(),
    checkedAt: fmtIso_(new Date()),
    problem: problem,
  };
  if (!ss) return out;
  try {
    out.timezone = ss.getSpreadsheetTimeZone() || null;
  } catch (e) {
    out.timezone = null;
  }
  SCHEMA.sheets.forEach(function (def) {
    const t = stTable_(def.key);
    out.sheets.push({
      key: def.key,
      title: def.title,
      exists: t.exists,
      rows: t.rows.length,
      missingColumns: t.missing.slice(),
      extraColumns: t.extra.slice(),
    });
  });
  out.summarySheet = { title: SUMMARY_TITLE, exists: !!ss.getSheetByName(SUMMARY_TITLE) };
  out.ok = out.sheets.every(function (s) { return s.exists && s.missingColumns.length === 0; });
  if (!out.ok) {
    const missing = out.sheets.filter(function (s) { return !s.exists || s.missingColumns.length; });
    out.problem = {
      code: 'SHEET_SCHEMA',
      message: 'ينقص الملف ' + missing.length + ' صفحة/أعمدة. اضغط «إصلاح الملف» لإنشائها دون مسح أي بيانات.',
    };
  }
  return out;
}

/** يستخرج معرّف الملف من رابط Google Sheets أو يقبله كما هو. '' إن لم يكن صالحًا. */
function sheetParseId_(raw) {
  const s = String(raw || '').trim();
  const m = /\/spreadsheets\/(?:u\/\d+\/)?d\/([A-Za-z0-9_-]{20,})/.exec(s);
  if (m) return m[1];
  const q = /[?&]id=([A-Za-z0-9_-]{20,})/.exec(s);
  if (q) return q[1];
  if (/^[A-Za-z0-9_-]{20,}$/.test(s)) return s;
  return '';
}

/** هل الملف بلا سجلات تحمل أوقاتًا؟ (الإعدادات وأصناف التعبئة لا تُحسب). */
function sheetHasNoRecords_(status) {
  return status.sheets.every(function (s) {
    return s.key === 'settings' || s.key === 'item_types' || !s.exists || s.rows === 0;
  });
}

// =====================================================================================
// الإجراءات
// =====================================================================================

function sheetStatusAction_() {
  return sheetStatus_();
}

/** sheet.repair → SheetStatus. لا يحذف أي صفحة أو صف أو عمود. */
function sheetRepairAction_() {
  const ss = stSpreadsheet_();
  const before = sheetStatus_();
  const tz = rqTzSafe_();
  // تغيير المنطقة الزمنية للملف يُبقي «ساعة الحائط» المخزنة في خلايا التاريخ ويغيّر اللحظة التي تمثلها،
  // فيُزيح كل الأوقات المسجلة. لذلك تُضبط فقط ما دام الملف بلا سجلات (ملف جديد).
  const fresh = sheetHasNoRecords_(before);
  let tzChanged = false;
  if (fresh && ss.getSpreadsheetTimeZone() !== tz) {
    try {
      ss.setSpreadsheetTimeZone(tz);
      tzChanged = true;
    } catch (e) {
      // ليس شرطًا للإصلاح.
    }
  }
  SCHEMA.sheets.forEach(function (def, i) {
    // الموضع لا يتجاوز عدد الصفحات الحالي حتى لا يفشل insertSheet.
    const position = Math.min(i + 2, ss.getSheets().length + 1);
    buildDataSheet_(ss, def, position);
  });
  buildSummary_(ss);
  rqResetTables_();
  rq_().wrote = true;

  const fixed = before.sheets.filter(function (s) { return !s.exists || s.missingColumns.length; });
  const desc = fixed.length
    ? 'إصلاح ملف البيانات: ' + fixed.map(function (s) {
      return s.exists ? 'أعمدة «' + s.missingColumns.join('، ') + '» في «' + s.title + '»' : 'صفحة «' + s.title + '»';
    }).join('؛ ')
    : 'إعادة تنسيق ملف البيانات (لم يكن ينقصه شيء)';
  auditAdd_('تعديل', 'ملف', ss.getId(), desc,
    { missing: fixed.map(function (s) { return { sheet: s.title, exists: s.exists, columns: s.missingColumns }; }),
      timezone: before.timezone },
    { repaired: true, timezone: tzChanged ? tz : before.timezone }, '');
  auditFlush_();
  return sheetStatus_();
}

/** sheet.connect {spreadsheet} → SheetStatus + warning. */
function sheetConnectAction_(p) {
  const raw = inStr_(p.spreadsheet, 'spreadsheet', 'رابط ملف Google Sheets أو معرّفه', {
    required: true, max: 500, hint: 'انسخ رابط الملف من شريط العنوان في المتصفح والصقه هنا.',
  });
  const id = sheetParseId_(raw);
  if (!id) {
    failValidation_('spreadsheet', 'الرابط «' + raw.slice(0, 80) + '» ليس رابط ملف Google Sheets. انسخ الرابط كاملًا من شريط العنوان ' +
      '(يبدأ بـ https://docs.google.com/spreadsheets/d/) والصقه هنا.');
  }
  let next = null;
  try {
    next = SpreadsheetApp.openById(id);
  } catch (e) {
    next = null;
  }
  const who = sheetConnectedAs_();
  if (!next) {
    throw apiError_('SHEET_UNREACHABLE',
      'تعذّر فتح الملف. تأكد أن الرابط صحيح وأن حساب الربط' + (who ? ' (' + who + ')' : '') +
      ' لديه صلاحية «محرر» على الملف، ثم أعد المحاولة.', 'spreadsheet', { spreadsheetId: id, connectedAs: who });
  }

  // سطر في سجل الملف السابق (إن أمكن) — لا يمنع الربط إن تعذّر.
  let previousId = null;
  try {
    const old = stSpreadsheet_();
    previousId = old.getId();
    if (previousId !== id) {
      stRequire_(['audit']);
      auditAdd_('تعديل', 'ملف', previousId, 'ربط التطبيق بملف آخر (' + next.getName() + ')',
        { spreadsheetId: previousId }, { spreadsheetId: id }, '');
      auditFlush_();
    }
  } catch (e) {
    rq_().audit = [];
  }

  cfgSet_(RMN_PROP.spreadsheetId, id);
  stUseSpreadsheet_(next);
  rq_().wrote = true;

  // سطر في سجل الملف الجديد إن كانت صفحة السجل موجودة.
  try {
    stRequire_(['audit']);
    auditAdd_('تعديل', 'ملف', id, 'ربط التطبيق بهذا الملف' + (previousId && previousId !== id ? ' بدل الملف ' + previousId : ''),
      { spreadsheetId: previousId }, { spreadsheetId: id }, '');
    auditFlush_();
  } catch (e) {
    rq_().audit = [];
  }

  const status = sheetStatus_();
  status.warning = RMN_CONNECT_WARNING;
  status.previousSpreadsheetId = previousId;
  return status;
}

// ============================================================================================
// المصدر: backend/src/Store.gs
// ============================================================================================

/**
 * Store.gs — طبقة الجداول فوق Google Sheets.
 *
 * - الملف: SPREADSHEET_ID إن وُجد، وإلا الملف المرتبط بالسكربت.
 * - الصفحات تُعرف بعناوينها في SCHEMA (من sheets/setup.gs)، والأعمدة بأسمائها في صف العناوين
 *   SCHEMA.headerRow — لا بمواقعها أبدًا.
 * - كل صفحة تُقرأ مرة واحدة لكل طلب (getValues واحدة) وتُحفظ في الذاكرة، والكتابة تحدّث النسخة
 *   المحفوظة أيضًا.
 * - كل كتابة تُسجَّل في «دفتر الطلب» حتى يمكن التعويض عند فشل كتابة لاحقة (العقد §7).
 * - لا يُحذف أي صف.
 */

// حالة الطلب الحالي. تُصفَّر في بداية كل doGet/doPost.
var RMN_REQ = null;

function rqBegin_() {
  RMN_REQ = {
    now: new Date(),
    ss: null,
    ssError: null,
    tables: {},
    settings: null,
    tz: null,
    index: null,
    user: null,
    wrote: false,
    journal: [],
    audit: [],
    lockHeld: false,
    action: '',
    requestId: '',
  };
  return RMN_REQ;
}

function rq_() {
  return RMN_REQ || rqBegin_();
}

/** وقت الطلب (ثابت طوال الطلب). */
function rqNow_() {
  return new Date(rq_().now.getTime());
}

/** يُسقط كل ما قُرئ من الصفحات لإعادة القراءة (بعد الإصلاح أو بعد تبديل الملف). */
function rqResetTables_() {
  const rq = rq_();
  rq.tables = {};
  rq.settings = null;
  rq.tz = null;
  rq.index = null;
}

/** المنطقة الزمنية للعمل دون أن يرمي أبدًا. */
function rqTzSafe_() {
  try {
    return settingsTimeZone_();
  } catch (e) {
    return RMN_CFG.defaultTimeZone;
  }
}

// =====================================================================================
// الملف
// =====================================================================================

function stSheetErrorCodes_() {
  return ['SHEET_NOT_CONFIGURED', 'SHEET_UNREACHABLE', 'SHEET_SCHEMA'];
}

function isSheetError_(err) {
  return isApiError_(err) && stSheetErrorCodes_().indexOf(err.code) >= 0;
}

/** الملف الحالي أو خطأ SHEET_NOT_CONFIGURED / SHEET_UNREACHABLE. */
function stSpreadsheet_() {
  const rq = rq_();
  if (rq.ss) return rq.ss;
  if (rq.ssError) throw rq.ssError;
  const id = cfgGet_(RMN_PROP.spreadsheetId).trim();
  let ss = null;
  if (id) {
    try {
      ss = SpreadsheetApp.openById(id);
    } catch (e) {
      ss = null;
    }
    if (!ss) {
      rq.ssError = apiError_('SHEET_UNREACHABLE',
        'تعذّر فتح ملف Google Sheets المربوط (ربما حُذف أو سُحبت صلاحية حساب الربط عليه). ' +
        'افتح «إعدادات الملف» واربط ملفًا متاحًا، أو اطلب ذلك من المدير.',
        null, { spreadsheetId: id });
      throw rq.ssError;
    }
  } else {
    try {
      ss = SpreadsheetApp.getActiveSpreadsheet();
    } catch (e) {
      ss = null;
    }
    if (!ss) {
      rq.ssError = apiError_('SHEET_NOT_CONFIGURED',
        'لم يُربط ملف Google Sheets بالخادم بعد. افتح «إعدادات الملف» واربط الملف، أو اطلب ذلك من المدير.',
        null, {});
      throw rq.ssError;
    }
  }
  rq.ss = ss;
  return ss;
}

/** يبدّل الملف للطلب الحالي (بعد sheet.connect). */
function stUseSpreadsheet_(ss) {
  const rq = rq_();
  rq.ss = ss;
  rq.ssError = null;
  rqResetTables_();
}

// =====================================================================================
// الجداول
// =====================================================================================

/** تعريف الصفحة من SCHEMA بالمفتاح (coolers, farmers, ...). */
function stDef_(key) {
  const sheets = SCHEMA.sheets;
  for (let i = 0; i < sheets.length; i++) {
    if (sheets[i].key === key) return sheets[i];
  }
  throw new Error('Unknown table key: ' + key);
}

function stHeaderName_(v) {
  return v === null || v === undefined ? '' : String(v).trim();
}

/**
 * يقرأ الصفحة مرة واحدة لكل طلب (getValues واحدة). السجل كائن مفاتيحه أسماء الأعمدة، مع $row
 * (رقم الصف) و$vals (القيم الخام). سجل التعديلات يُحفظ «خفيفًا» (المعرّف فقط) لأنه يكبر ولا نحتاج
 * منه إلا أكبر معرّف.
 */
function stTable_(key) {
  const rq = rq_();
  if (rq.tables[key]) return rq.tables[key];
  const def = stDef_(key);
  const ss = stSpreadsheet_();
  const sh = ss.getSheetByName(def.title);
  const hr = SCHEMA.headerRow;
  const t = {
    key: key, def: def, title: def.title, sheet: sh || null, exists: !!sh,
    headers: [], col: Object.create(null), rows: [], missing: [], extra: [],
    lastRow: hr, light: key === 'audit',
  };
  const keyName = def.columns[0].name;
  if (sh) {
    const lastRow = sh.getLastRow();
    const lastCol = sh.getLastColumn();
    t.lastRow = Math.max(lastRow, hr);
    if (lastCol > 0 && lastRow >= hr) {
      const values = sh.getRange(hr, 1, lastRow - hr + 1, lastCol).getValues();
      t.headers = values[0].map(stHeaderName_);
      t.headers.forEach(function (h, j) {
        if (h && t.col[h] === undefined) t.col[h] = j;
      });
      const keyIdx = t.col[keyName];
      if (keyIdx !== undefined) {
        for (let i = 1; i < values.length; i++) {
          const vals = values[i];
          if (cellStr_(vals[keyIdx]) === '') continue;
          if (t.light) {
            const rec = { $row: hr + i, $vals: null };
            rec[keyName] = cellStr_(vals[keyIdx]);
            t.rows.push(rec);
          } else {
            t.rows.push(stMakeRec_(t, hr + i, vals));
          }
        }
      }
    }
    const names = def.columns.map(function (c) { return c.name; });
    t.missing = names.filter(function (n) { return t.col[n] === undefined; });
    t.extra = t.headers.filter(function (h) { return h && names.indexOf(h) < 0; });
  } else {
    t.missing = def.columns.map(function (c) { return c.name; });
  }
  rq.tables[key] = t;
  return t;
}

function stMakeRec_(t, rowNo, vals) {
  const rec = { $row: rowNo, $vals: vals };
  t.headers.forEach(function (h, j) {
    if (h && !Object.prototype.hasOwnProperty.call(rec, h)) rec[h] = vals[j];
  });
  return rec;
}

/** يتأكد من وجود الصفحات والأعمدة المطلوبة، وإلا SHEET_SCHEMA مع details.missing = [{sheet, columns}]. */
function stRequire_(keys) {
  const missing = [];
  keys.forEach(function (k) {
    const t = stTable_(k);
    if (t.missing.length) missing.push({ sheet: t.title, columns: t.missing.slice() });
  });
  if (missing.length) {
    const parts = missing.map(function (m) {
      const def = SCHEMA.sheets.filter(function (d) { return d.title === m.sheet; })[0];
      const whole = def && m.columns.length === def.columns.length;
      return whole ? 'صفحة «' + m.sheet + '»' : 'أعمدة في صفحة «' + m.sheet + '»: ' + m.columns.join('، ');
    });
    throw apiError_('SHEET_SCHEMA',
      'ملف Google Sheets ينقصه: ' + parts.join('؛ ') + '. افتح «إعدادات الملف» واضغط «إصلاح الملف»، أو اطلب ذلك من المدير.',
      null, { missing: missing });
  }
}

/** كل صفحات البيانات التي تحتاجها العمليات المالية. */
function stDataKeys_() {
  return ['coolers', 'farmers', 'purchases', 'payments', 'packaging', 'packaging_items'];
}

function stKeyName_(t) {
  return t.def.columns[0].name;
}

function stFindById_(t, id) {
  const want = cellStr_(id);
  if (!want) return null;
  const k = stKeyName_(t);
  for (let i = 0; i < t.rows.length; i++) {
    if (cellStr_(t.rows[i][k]) === want) return t.rows[i];
  }
  return null;
}

/** السجل الذي يحمل مفتاح عدم التكرار = key (أو null). */
function stFindByKey_(t, key) {
  const want = cellStr_(key);
  if (!want || t.col['مفتاح عدم التكرار'] === undefined) return null;
  for (let i = 0; i < t.rows.length; i++) {
    if (cellStr_(t.rows[i]['مفتاح عدم التكرار']) === want) return t.rows[i];
  }
  return null;
}

/** أكبر رقم تسلسلي لبادئة في عمود + 1. */
function stNextSeq_(t, colName, prefix) {
  let max = 0;
  t.rows.forEach(function (r) {
    const n = seqNumber_(r[colName], prefix);
    if (n > max) max = n;
  });
  return max + 1;
}

/** المعرّف التالي: البادئة + (أكبر رقم + 1). */
function stNextId_(t, prefix) {
  return seqFormat_(prefix, stNextSeq_(t, stKeyName_(t), prefix));
}

/** الرقم البشري التالي في عمود عددي (أكبر قيمة + 1). */
function stNextNumber_(t, colName) {
  let max = 0;
  t.rows.forEach(function (r) {
    const n = cellInt_(r[colName]);
    if (n !== null && n > max) max = n;
  });
  return max + 1;
}

/** يضع «آخر تعديل» و«عدّله/عدّلها» إن كانت في الصفحة ولم تُحدَّد صراحة. */
function stStamp_(t, c) {
  if (t.col['آخر تعديل'] !== undefined && !Object.prototype.hasOwnProperty.call(c, 'آخر تعديل')) {
    c['آخر تعديل'] = rqNow_();
  }
  ['عدّله', 'عدّلها'].forEach(function (name) {
    if (t.col[name] !== undefined && !Object.prototype.hasOwnProperty.call(c, name)) {
      c[name] = userLabel_(rq_().user);
    }
  });
}

function stMarkWrite_() {
  const rq = rq_();
  rq.wrote = true;
  rq.index = null;
}

function stCellValue_(v) {
  return v === null || v === undefined ? '' : v;
}

/**
 * يضيف صفوفًا في نهاية الصفحة (setValues واحدة). objs: [{اسم العمود: قيمة}].
 * يضبط الإصدار 1 وختم التعديل. opts: {track (افتراضيًا true للتعويض عند الفشل), stamp}.
 */
function stAppend_(t, objs, opts) {
  opts = opts || {};
  if (!objs.length) return [];
  const width = t.headers.length;
  const start = t.lastRow + 1;
  const recs = objs.map(function (o, k) {
    const c = Object.assign({}, o);
    if (t.col['الإصدار'] !== undefined && !inPresent_(c['الإصدار'])) c['الإصدار'] = 1;
    if (opts.stamp !== false) stStamp_(t, c);
    const vals = [];
    for (let j = 0; j < width; j++) vals.push('');
    Object.keys(c).forEach(function (h) {
      const j = t.col[h];
      if (j !== undefined) vals[j] = stCellValue_(c[h]);
    });
    return stMakeRec_(t, start + k, vals);
  });
  const last = start + recs.length - 1;
  const maxRows = t.sheet.getMaxRows();
  if (last > maxRows) t.sheet.insertRowsAfter(maxRows, last - maxRows);
  t.sheet.getRange(start, 1, recs.length, width).setValues(recs.map(function (r) {
    return r.$vals.map(cellOut_);
  }));
  t.lastRow = last;
  recs.forEach(function (r) {
    if (t.light) {
      const keyName = stKeyName_(t);
      const lightRec = { $row: r.$row, $vals: null };
      lightRec[keyName] = cellStr_(r[keyName]);
      t.rows.push(lightRec);
    } else {
      t.rows.push(r);
    }
  });
  if (opts.track !== false) {
    recs.forEach(function (r) { rq_().journal.push({ op: 'append', t: t, rec: r }); });
  }
  stMarkWrite_();
  return recs;
}

/**
 * يحدّث خلايا صف في مكانه. يزيد الإصدار (إلا إن bump=false) ويضع ختم التعديل (إلا إن stamp=false).
 * يكتب الأعمدة المتغيرة فقط، كل مجموعة أعمدة متجاورة بـ setValues واحدة، فلا يمس الخلايا الأخرى.
 * opts.track=false: لا يُسجَّل في دفتر التعويض.
 */
function stUpdate_(t, rec, changes, opts) {
  opts = opts || {};
  const c = Object.assign({}, changes);
  if (opts.bump !== false && t.col['الإصدار'] !== undefined && !Object.prototype.hasOwnProperty.call(c, 'الإصدار')) {
    c['الإصدار'] = stVersion_(rec) + 1;
  }
  if (opts.stamp !== false) stStamp_(t, c);
  const names = Object.keys(c).filter(function (n) { return t.col[n] !== undefined; });
  if (!names.length) return rec;
  const prev = {};
  names.forEach(function (n) { prev[n] = stCellValue_(rec[n]); });
  const idx = names.map(function (n) { return t.col[n]; }).sort(function (a, b) { return a - b; });
  const byIdx = {};
  names.forEach(function (n) { byIdx[t.col[n]] = stCellValue_(c[n]); });
  let i = 0;
  while (i < idx.length) {
    let j = i;
    while (j + 1 < idx.length && idx[j + 1] === idx[j] + 1) j++;
    const run = [];
    for (let k = i; k <= j; k++) run.push(cellOut_(byIdx[idx[k]]));
    t.sheet.getRange(rec.$row, idx[i] + 1, 1, j - i + 1).setValues([run]);
    i = j + 1;
  }
  if (!rec.$vals) rec.$vals = [];
  names.forEach(function (n) {
    rec.$vals[t.col[n]] = stCellValue_(c[n]);
    rec[n] = stCellValue_(c[n]);
  });
  if (opts.track !== false) rq_().journal.push({ op: 'update', t: t, rec: rec, prev: prev });
  stMarkWrite_();
  return rec;
}

/** رقم إصدار السجل (≥ 1). */
function stVersion_(rec) {
  const v = cellInt_(rec['الإصدار']);
  return v && v > 0 ? v : 1;
}

// =====================================================================================
// نسخة البيانات وآخر كتابة
// =====================================================================================

function stDataVersion_() {
  try {
    return cfgGet_(RMN_PROP.dataVersion) || '0';
  } catch (e) {
    return '';
  }
}

/** يزيد DATA_VERSION ويحدّث LAST_WRITE_AT بعد كل كتابة. */
function stBumpDataVersion_() {
  try {
    const v = (parseInt(cfgGet_(RMN_PROP.dataVersion), 10) || 0) + 1;
    cfgSet_(RMN_PROP.dataVersion, String(v));
    cfgSet_(RMN_PROP.lastWriteAt, fmtIso_(new Date()));
  } catch (e) {
    // لا يجوز أن يُفشل هذا ردًا ناجحًا.
  }
}

// =====================================================================================
// سجل التعديلات
// =====================================================================================

/**
 * يضيف سطرًا إلى سجل التعديلات (يُكتب في نهاية الطلب دفعة واحدة).
 * action: إنشاء/تعديل/إلغاء/تقفيل/إعادة فتح/دفعة. recordType: براد/مزارع/شراء رمان/شراء تعبئة/دفعة/مستخدم/إعدادات/ملف.
 */
function auditAdd_(action, recordType, recordId, description, prev, next, reason) {
  rq_().audit.push({
    action: action, recordType: recordType, recordId: recordId || '', description: description || '',
    prev: prev === undefined ? null : prev, next: next === undefined ? null : next, reason: reason || '',
  });
}

function auditJson_(v) {
  if (v === null || v === undefined) return '';
  let s;
  try {
    s = JSON.stringify(v, function (k, val) {
      return isDate_(this[k]) ? fmtIso_(this[k]) : val;
    });
  } catch (e) {
    s = String(v);
  }
  if (s.length > RMN_CFG.auditMaxCellChars) s = s.slice(0, RMN_CFG.auditMaxCellChars) + '…';
  return s;
}

/** يكتب أسطر السجل المعلقة في صفحة سجل التعديلات (setValues واحدة). */
function auditFlush_() {
  const rq = rq_();
  if (!rq.audit.length) return;
  stRequire_(['audit']);
  const t = stTable_('audit');
  let seq = stNextSeq_(t, stKeyName_(t), 'AU');
  const who = userLabel_(rq.user);
  const rows = rq.audit.map(function (a) {
    return {
      'المعرّف': seqFormat_('AU', seq++),
      'التاريخ والوقت': rqNow_(),
      'المستخدم': who,
      'الإجراء': a.action,
      'نوع السجل': a.recordType,
      'معرّف السجل': a.recordId,
      'الوصف': a.description,
      'القيم السابقة': auditJson_(a.prev),
      'القيم الجديدة': auditJson_(a.next),
      'السبب': a.reason,
    };
  });
  rq.audit = [];
  stAppend_(t, rows, { track: false, stamp: false });
}

/** يقارن قيم أعمدة قبل/بعد ويعيد ما تغيّر فقط {prev, next, changed}. */
function auditDiff_(before, after) {
  const prev = {};
  const next = {};
  Object.keys(after).forEach(function (k) {
    const a = before[k];
    const b = after[k];
    if (!stSameCell_(a, b)) {
      prev[k] = a === undefined ? '' : a;
      next[k] = b;
    }
  });
  return { prev: prev, next: next, changed: Object.keys(next).length > 0 };
}

/** هل قيمتا الخلية متساويتان (تواريخ بالمللي ثانية، والأرقام كنص)؟ */
function stSameCell_(a, b) {
  const sa = isDate_(a) ? a.getTime() : a;
  const sb = isDate_(b) ? b.getTime() : b;
  return String(sa === null || sa === undefined ? '' : sa) === String(sb === null || sb === undefined ? '' : sb);
}

// =====================================================================================
// التعويض عند الفشل الجزئي (العقد §7)
// =====================================================================================

/** التغييرات التي «تُلغي» صفًا أُضيف في طلب فشل لاحقًا (لا حذف). null = لا شيء. */
function stCompensationChanges_(t, rec) {
  const reason = RMN_CFG.compensationReason;
  switch (t.key) {
    case 'purchases':
    case 'payments':
      return { 'الحالة': 'ملغاة', 'سبب الإلغاء': reason };
    case 'packaging':
      return { 'الحالة': 'ملغى', 'ملاحظات': appendNote_(rec['ملاحظات'], reason) };
    case 'packaging_items':
      return { 'الحالة': 'محذوف', 'ملاحظات': appendNote_(rec['ملاحظات'], reason) };
    case 'farmers':
      return { 'الحالة': 'موقوف', 'ملاحظات': appendNote_(rec['ملاحظات'], reason) };
    case 'coolers':
      // لا توجد حالة «ملغى» للبراد: يُقفَل حتى لا يصبح «البراد الحالي» ولا تُضاف إليه مشتريات
      // بينما تُنشئ إعادة المحاولة البراد الصحيح.
      return { 'الحالة': 'مقفّل', 'ملاحظات': appendNote_(rec['ملاحظات'], reason) };
    case 'users':
      // البريد يُفرَّغ حتى تنجح إعادة المحاولة دون «بريد مكرر»، والصف يبقى معطّلًا للأثر.
      return {
        'الحالة': 'معطّل',
        'البريد (Gmail)': '',
        'الاسم': cellStr_(rec['الاسم']) + ' — ' + reason + ' (' + cellStr_(rec['البريد (Gmail)']) + ')',
      };
    case 'item_types':
      return { 'نشط': 'لا', 'الصنف': cellStr_(rec['الصنف']) + ' — ' + reason };
    default:
      return null;
  }
}

/**
 * عند فشل كتابة لاحقة: يُرجع الصفوف المعدَّلة في هذا الطلب إلى قيمها السابقة، ويُلغي الصفوف المضافة
 * (لا يحذفها)، ويغيّر مفتاح عدم التكرار حتى تنجح إعادة المحاولة بنفس requestId، ثم يعيد حساب
 * المدفوع/المتبقي المخزن. لا يرمي أبدًا.
 */
function stCompensate_() {
  const rq = rq_();
  const list = rq.journal.splice(0, rq.journal.length).reverse();
  rq.audit = [];
  const appended = [];
  list.forEach(function (e) { if (e.op === 'append') appended.push(e.rec); });
  const refresh = { purchase: {}, packaging: {} };
  const noteTarget = function (t, rec) {
    if (t.key === 'purchases') refresh.purchase[cellStr_(rec['المعرّف'])] = true;
    if (t.key === 'packaging') refresh.packaging[cellStr_(rec['المعرّف'])] = true;
    if (t.key === 'packaging_items') refresh.packaging[cellStr_(rec['معرّف الشراء'])] = true;
    if (t.key === 'payments') {
      const type = enumToApi_('payTarget', rec['نوع العملية'], 'purchase');
      refresh[type === 'packaging' ? 'packaging' : 'purchase'][cellStr_(rec['معرّف العملية'])] = true;
    }
  };
  list.forEach(function (entry) {
    const t = entry.t;
    const rec = entry.rec;
    try {
      noteTarget(t, rec);
      if (entry.op === 'update') {
        if (appended.indexOf(rec) >= 0) return; // سيُلغى كاملًا
        stUpdate_(t, rec, entry.prev, { bump: false, stamp: false, track: false });
        return;
      }
      const c = stCompensationChanges_(t, rec);
      if (!c) return;
      const key = cellStr_(rec['مفتاح عدم التكرار']);
      if (t.col['مفتاح عدم التكرار'] !== undefined && key) c['مفتاح عدم التكرار'] = key + RMN_CFG.failedKeySuffix;
      stUpdate_(t, rec, c, { track: false });
    } catch (err) {
      // نكمل بقية التعويض.
    }
  });
  Object.keys(refresh.purchase).forEach(function (id) {
    try { paymentsRefreshTarget_('purchase', id, { track: false }); } catch (err) { /* نتجاهل */ }
  });
  Object.keys(refresh.packaging).forEach(function (id) {
    try { paymentsRefreshTarget_('packaging', id, { track: false }); } catch (err) { /* نتجاهل */ }
  });
}

// ============================================================================================
// المصدر: backend/src/Users.gs
// ============================================================================================

/**
 * Users.gs — صفحة «المستخدمون»: تحويل الصف إلى كائن المستخدم، والصلاحيات، وإدارة المستخدمين.
 */

// الصلاحيات المخزنة في أعمدة الصفحة (لموظف الإدخال).
const RMN_PERM_COLUMNS = Object.freeze({
  addFarmers: 'إضافة المزارعين',
  recordPurchases: 'تسجيل المشتريات',
  editOthers: 'تعديل عمليات الآخرين',
  recordPayments: 'تسجيل المدفوعات',
  packaging: 'مشتريات التعبئة',
  closeCoolers: 'تقفيل البرادات',
});

const RMN_PERM_KEYS = Object.freeze([
  'addFarmers', 'recordPurchases', 'editOthers', 'recordPayments', 'packaging', 'closeCoolers',
  'reopenCoolers', 'manageUsers', 'manageSettings', 'viewData',
]);

const RMN_PERM_LABELS = Object.freeze({
  addFarmers: 'إضافة المزارعين',
  recordPurchases: 'تسجيل المشتريات',
  editOthers: 'تعديل عمليات الآخرين',
  recordPayments: 'تسجيل المدفوعات',
  packaging: 'مشتريات التعبئة',
  closeCoolers: 'تقفيل البرادات',
  reopenCoolers: 'إعادة فتح البرادات',
  manageUsers: 'إدارة المستخدمين',
  manageSettings: 'إدارة الإعدادات وملف البيانات',
  viewData: 'عرض البيانات',
});

// الصلاحيات الافتراضية لموظف إدخال جديد إن لم تُرسل: لا شيء غير العرض (أقل صلاحية).
const RMN_ENTRY_DEFAULT_PERMS = Object.freeze({
  addFarmers: false, recordPurchases: false, editOthers: false,
  recordPayments: false, packaging: false, closeCoolers: false,
});

const RMN_ROLE_CHOICES = Object.freeze({ admin: 'مدير', entry: 'موظف إدخال', viewer: 'مشاهدة فقط' });

/** الصلاحيات حسب الدور (العقد §3): المدير كل شيء، المشاهد العرض فقط، موظف الإدخال العرض + الأعمدة الستة. */
function usersPermissions_(role, rec) {
  const out = {};
  RMN_PERM_KEYS.forEach(function (k) {
    if (role === 'admin') out[k] = true;
    else if (k === 'viewData') out[k] = true;
    else if (role === 'entry' && RMN_PERM_COLUMNS[k]) out[k] = rec ? cellBool_(rec[RMN_PERM_COLUMNS[k]]) : false;
    else out[k] = false;
  });
  return out;
}

function usersEmailOf_(rec) {
  return cellStr_(rec['البريد (Gmail)']).replace(/\s+/g, '').toLowerCase();
}

function usersIsBootstrapEmail_(email) {
  const boot = cfgBootstrapEmail_();
  return !!boot && !!email && email.toLowerCase() === boot;
}

/** صف المستخدم → كائن المستخدم. المدير الأساسي دائمًا مدير نشط (break-glass). */
function usersToApi_(rec) {
  const email = usersEmailOf_(rec);
  const isBootstrap = usersIsBootstrapEmail_(email);
  let role = enumToApi_('role', rec['الدور'], 'viewer');
  let status = enumToApi_('userStatus', rec['الحالة'], 'active');
  if (isBootstrap) {
    role = 'admin';
    status = 'active';
  }
  return {
    id: cellStr_(rec['المعرّف']),
    email: email,
    name: cellStr_(rec['الاسم']) || email,
    role: role,
    status: status,
    isBootstrap: isBootstrap,
    version: stVersion_(rec),
    permissions: usersPermissions_(role, rec),
  };
}

/** مستخدم «المدير الأساسي» عند تعذّر قراءة صفحة المستخدمين (لإصلاح الملف أو ربطه فقط). */
function usersSyntheticBootstrap_(email, name, uid, version) {
  return {
    id: uid || '',
    email: email,
    name: name || email,
    role: 'admin',
    status: 'active',
    isBootstrap: true,
    version: version || 0,
    permissions: usersPermissions_('admin', null),
    synthetic: true,
  };
}

function usersFindByEmail_(email) {
  const want = String(email || '').trim().toLowerCase();
  if (!want) return null;
  const t = stTable_('users');
  for (let i = 0; i < t.rows.length; i++) {
    if (usersEmailOf_(t.rows[i]) === want) return t.rows[i];
  }
  return null;
}

/** قيم أعمدة الصلاحيات للكتابة حسب الدور والمدخلات (والقيم الحالية عند التعديل). */
function usersPermColumns_(input, role, rec) {
  if (input !== undefined && input !== null && !isPlainObject_(input)) {
    failValidation_('permissions', '«الصلاحيات» يجب أن تكون قائمة اختيارات نعم/لا. حدّث التطبيق ثم أعد المحاولة.');
  }
  const out = {};
  Object.keys(RMN_PERM_COLUMNS).forEach(function (k) {
    const col = RMN_PERM_COLUMNS[k];
    let v;
    if (role === 'admin') v = true;
    else if (role === 'viewer') v = false;
    else if (input && input[k] !== undefined && input[k] !== null) {
      v = inBool_(input[k], 'permissions.' + k, 'صلاحية ' + RMN_PERM_LABELS[k], false);
    } else if (rec) v = cellBool_(rec[col]);
    else v = RMN_ENTRY_DEFAULT_PERMS[k];
    out[col] = yesNo_(v);
  });
  return out;
}

/** صف المدير الأساسي عند أول دخول. */
function usersProvisionBootstrap_(email, name) {
  const t = stTable_('users');
  const id = stNextId_(t, 'US');
  const row = {
    'المعرّف': id,
    'البريد (Gmail)': email,
    'الاسم': name || email,
    'الدور': 'مدير',
    'الحالة': 'نشط',
    'تاريخ الإضافة': rqNow_(),
    'أضافه': 'النظام (المدير الأساسي)',
  };
  Object.assign(row, usersPermColumns_(null, 'admin', null));
  const rec = stAppend_(t, [row], { track: false })[0];
  return rec;
}

/** هل يحتاج صف المدير الأساسي إصلاحًا (معطّل أو ليس مديرًا)؟ */
function usersBootstrapNeedsRepair_(rec) {
  return enumToApi_('role', rec['الدور'], 'viewer') !== 'admin' ||
    enumToApi_('userStatus', rec['الحالة'], 'active') !== 'active';
}

function usersRepairBootstrap_(rec) {
  const t = stTable_('users');
  const c = { 'الدور': 'مدير', 'الحالة': 'نشط' };
  Object.assign(c, usersPermColumns_(null, 'admin', null));
  const before = {};
  Object.keys(c).forEach(function (k) { before[k] = rec[k]; });
  stUpdate_(t, rec, c);
  return { prev: before, next: c };
}

/** عدد المديرين النشطين بعد تطبيق تغيير افتراضي على صف واحد. */
function usersActiveAdminsAfter_(changedRec, newRole, newStatus) {
  const t = stTable_('users');
  let n = 0;
  t.rows.forEach(function (r) {
    const boot = usersIsBootstrapEmail_(usersEmailOf_(r));
    let role = enumToApi_('role', r['الدور'], 'viewer');
    let status = enumToApi_('userStatus', r['الحالة'], 'active');
    if (r === changedRec) {
      role = newRole;
      status = newStatus;
    }
    if (boot || (role === 'admin' && status === 'active')) n++;
  });
  return n;
}

// =====================================================================================
// الإجراءات
// =====================================================================================

function usersListAction_() {
  stRequire_(['users']);
  return { users: stTable_('users').rows.map(usersToApi_) };
}

/** users.add */
function usersAddAction_(p) {
  stRequire_(['users', 'audit']);
  const t = stTable_('users');
  const email = inStr_(p.email, 'email', 'البريد الإلكتروني', { required: true, max: 120, hint: 'اكتب بريد Gmail مثل name@gmail.com.' })
    .replace(/\s+/g, '').toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    failValidation_('email', 'البريد «' + email + '» غير صحيح. اكتب بريد Gmail كاملًا مثل name@gmail.com.');
  }
  const existing = usersFindByEmail_(email);
  if (existing) {
    failValidation_('email', 'البريد «' + email + '» مسجّل بالفعل لمستخدم آخر. ابحث عنه في القائمة وعدّله بدل إضافته مرة أخرى.',
      { id: cellStr_(existing['المعرّف']) });
  }
  const name = inStr_(p.name, 'name', 'الاسم', { required: true, max: 80 });
  const role = inEnum_(p.role, 'role', 'الدور', RMN_ROLE_CHOICES, { required: true });
  const row = {
    'المعرّف': stNextId_(t, 'US'),
    'البريد (Gmail)': email,
    'الاسم': name,
    'الدور': enumToSheet_('role', role),
    'الحالة': 'نشط',
    'تاريخ الإضافة': rqNow_(),
    'أضافه': userLabel_(rq_().user),
  };
  Object.assign(row, usersPermColumns_(p.permissions, role, null));
  const rec = stAppend_(t, [row])[0];
  const user = usersToApi_(rec);
  auditAdd_('إنشاء', 'مستخدم', user.id, 'إضافة المستخدم ' + email + ' بدور ' + RMN_ROLE_CHOICES[role], null, row, '');
  return { user: user };
}

/** users.update */
function usersUpdateAction_(p) {
  stRequire_(['users', 'audit']);
  const t = stTable_('users');
  const id = inId_(p.id, 'id', 'المستخدم');
  const expected = inExpectedVersion_(p.expectedVersion);
  const rec = stFindById_(t, id);
  if (!rec) failNotFound_('id', 'المستخدم', id);
  const current = usersToApi_(rec);
  if (current.version !== expected) failConflict_('بيانات هذا المستخدم', current.version, current);

  const c = {};
  let newRole = enumToApi_('role', rec['الدور'], 'viewer');
  let newStatus = enumToApi_('userStatus', rec['الحالة'], 'active');
  if (p.name !== undefined) c['الاسم'] = inStr_(p.name, 'name', 'الاسم', { required: true, max: 80 });
  if (p.role !== undefined) {
    newRole = inEnum_(p.role, 'role', 'الدور', RMN_ROLE_CHOICES, { required: true });
    if (current.isBootstrap && newRole !== 'admin') {
      failValidation_('role', 'لا يمكن تغيير دور المدير الأساسي (' + current.email + '). يمكن تغييره فقط من إعدادات الخادم.');
    }
    c['الدور'] = enumToSheet_('role', newRole);
  }
  if (p.status !== undefined) {
    newStatus = inEnum_(p.status, 'status', 'الحالة', { active: 'نشط', disabled: 'معطّل' }, { required: true });
    if (current.isBootstrap && newStatus !== 'active') {
      failValidation_('status', 'لا يمكن تعطيل المدير الأساسي (' + current.email + '). يمكن تغييره فقط من إعدادات الخادم.');
    }
    c['الحالة'] = enumToSheet_('userStatus', newStatus);
  }
  if (p.role !== undefined || p.permissions !== undefined) {
    Object.assign(c, usersPermColumns_(p.permissions, newRole, rec));
  }
  if (usersActiveAdminsAfter_(rec, newRole, newStatus) < 1) {
    failValidation_(p.status !== undefined && newStatus !== 'active' ? 'status' : 'role',
      'لا يمكن حفظ التغيير لأن «' + current.name + '» هو آخر مدير نشط. أضف مديرًا آخر أو فعّله أولًا.');
  }
  const diff = auditDiff_(rec, c);
  if (!diff.changed) return { user: current };
  const changes = {};
  Object.keys(diff.next).forEach(function (k) { changes[k] = c[k]; });
  stUpdate_(t, rec, changes);
  const user = usersToApi_(rec);
  auditAdd_('تعديل', 'مستخدم', user.id, 'تعديل المستخدم ' + user.email, diff.prev, diff.next, '');
  return { user: user };
}
