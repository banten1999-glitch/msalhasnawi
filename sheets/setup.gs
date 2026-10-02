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
            "غير مكتمل"
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

const VALUE_STYLES = {"مفتوح": ["E5F1E9", "1F6B2C", false], "مقفّل": ["EEE9E2", "4A423C", false], "مسودة": ["FDF0D5", "8A4B00", false], "معتمد": ["E5F1E9", "1F6B2C", false], "ملغى": ["EEE9E2", "6F655D", true], "ملغاة": ["EEE9E2", "6F655D", true], "فعّالة": ["E5F1E9", "1F6B2C", false], "مدفوع": ["E5F1E9", "1F6B2C", false], "جزئي": ["FDF0D5", "8A4B00", false], "غير مدفوع": ["FBE9EC", "A00B1E", false], "مكتمل": ["E5F1E9", "1F6B2C", false], "غير مكتمل": ["FDF0D5", "8A4B00", false], "نشط": ["E5F1E9", "1F6B2C", false], "معطّل": ["EEE9E2", "4A423C", false], "موقوف": ["EEE9E2", "4A423C", false], "نعم": ["E5F1E9", "1F6B2C", false], "لا": ["EEE9E2", "6F655D", false], "مدير": ["FBE9EC", "A00B1E", false], "موظف إدخال": ["E6EEF8", "1D4F91", false], "مشاهدة فقط": ["EEE9E2", "4A423C", false], "مباشر": ["EEE9E2", "4A423C", false], "عينة": ["E6EEF8", "1D4F91", false], "مزارع": ["FBE9EC", "A00B1E", false], "مورد": ["E5F1E9", "1F6B2C", false], "شراء رمان": ["FBE9EC", "A00B1E", false], "شراء تعبئة": ["E5F1E9", "1F6B2C", false], "إنشاء": ["E5F1E9", "1F6B2C", false], "تعديل": ["E6EEF8", "1D4F91", false], "إلغاء": ["EEE9E2", "4A423C", false], "تقفيل": ["FBE9EC", "A00B1E", false], "إعادة فتح": ["FDF0D5", "8A4B00", false], "دفعة": ["E5F1E9", "1F6B2C", false]};

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
