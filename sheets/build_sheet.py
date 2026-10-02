#!/usr/bin/env python3
"""يبني ملف «حاسبة الرمان» المركزي من مصدر واحد.

المخرجات (في مجلد sheets/):
  rumman-calculator.xlsx           الملف مع بيانات أمثلة مطابقة للتصميم
  rumman-calculator-template.xlsx  الملف نفسه فارغًا وجاهزًا للعمل
  setup.gs                         سكربت Apps Script يبني الصفحات داخل Google Sheets مباشرة
  schema.json                      وصف الصفحات والأعمدة (يستخدمه الخادم لاحقًا)

التشغيل:  pip install openpyxl && python3 sheets/build_sheet.py
"""
import datetime as dt
import json
import os

from openpyxl import Workbook
from openpyxl.formatting.rule import CellIsRule, FormulaRule
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

HERE = os.path.dirname(os.path.abspath(__file__))

FONT = "Cairo"
RED, RED_L = "A00B1E", "FBE9EC"
GREEN, GREEN_L = "1F6B2C", "E5F1E9"
IVORY, WHITE = "FAF6EE", "FFFFFF"
INK, INK2, MUTED = "1C1714", "5E554E", "6F655D"
AMBER, AMBER_L = "8A4B00", "FDF0D5"
BLUE, BLUE_L = "1D4F91", "E6EEF8"
GRAY, GRAY_L = "4A423C", "EEE9E2"
LINE = "E3DACC"

TITLE_ROW, DESC_ROW, HEADER_ROW, FIRST_ROW = 1, 2, 3, 4
STYLED_ROWS = 300      # صفوف منسقة مسبقًا في ملف xlsx
FORMULA_ROWS = 3000    # مدى المعادلات في صفحة الملخص

# أنواع الأعمدة: (العرض، تنسيق الأرقام، المحاذاة)
KINDS = {
    "id": (15, "@", "center"),
    "text": (20, "@", "right"),
    "long": (34, "@", "right"),
    "email": (32, "@", "left"),
    "int": (12, "#,##0", "center"),
    "kg": (15, "#,##0.0", "center"),
    "kg3": (15, "0.0##", "center"),
    "money": (17, "#,##0.00", "center"),
    "dt": (20, "yyyy-mm-dd  hh:mm", "center"),
    "date": (15, "yyyy-mm-dd", "center"),
    "enum": (16, "@", "center"),
    "bool": (13, "@", "center"),
}

# ألوان القيم في أعمدة الحالة: القيمة -> (الخلفية، لون النص، شطب)
VALUE_STYLES = {
    "مفتوح": (GREEN_L, GREEN, False), "مقفّل": (GRAY_L, GRAY, False),
    "مسودة": (AMBER_L, AMBER, False), "معتمد": (GREEN_L, GREEN, False),
    "ملغى": (GRAY_L, MUTED, True), "ملغاة": (GRAY_L, MUTED, True), "فعّالة": (GREEN_L, GREEN, False),
    "مدفوع": (GREEN_L, GREEN, False), "جزئي": (AMBER_L, AMBER, False), "غير مدفوع": (RED_L, RED, False),
    "مكتمل": (GREEN_L, GREEN, False), "غير مكتمل": (AMBER_L, AMBER, False), "محذوف": (GRAY_L, MUTED, True),
    "نشط": (GREEN_L, GREEN, False), "معطّل": (GRAY_L, GRAY, False), "موقوف": (GRAY_L, GRAY, False),
    "نعم": (GREEN_L, GREEN, False), "لا": (GRAY_L, MUTED, False),
    "مدير": (RED_L, RED, False), "موظف إدخال": (BLUE_L, BLUE, False), "مشاهدة فقط": (GRAY_L, GRAY, False),
    "مباشر": (GRAY_L, GRAY, False), "عينة": (BLUE_L, BLUE, False),
    "مزارع": (RED_L, RED, False), "مورد": (GREEN_L, GREEN, False),
    "شراء رمان": (RED_L, RED, False), "شراء تعبئة": (GREEN_L, GREEN, False),
    "إنشاء": (GREEN_L, GREEN, False), "تعديل": (BLUE_L, BLUE, False), "إلغاء": (GRAY_L, GRAY, False),
    "تقفيل": (RED_L, RED, False), "إعادة فتح": (AMBER_L, AMBER, False), "دفعة": (GREEN_L, GREEN, False),
}


def C(name, kind="text", options=None, width=None, hidden=False, emphasis=None):
    return {"name": name, "kind": kind, "options": options, "width": width,
            "hidden": hidden, "emphasis": emphasis}


YES_NO = ["نعم", "لا"]

SHEETS = [
    {
        "key": "coolers", "title": "البرادات", "tab": RED,
        "desc": "بيانات كل براد وحالته. أعمدة «عند التقفيل» تُحفظ مرة واحدة لحظة التقفيل ولا تتغير بعدها.",
        "freeze_cols": 2,
        "columns": [
            C("المعرّف", "id"), C("رقم البراد", "int"), C("الاسم / الوصف"), C("رقم السيارة", width=15),
            C("السائق", width=16), C("تاريخ ووقت الفتح", "dt"), C("الحالة", "enum", ["مفتوح", "مقفّل"]),
            C("فتحه"), C("تاريخ ووقت التقفيل", "dt"), C("قفّله"),
            C("عدد المزارعين عند التقفيل", "int", width=15), C("عدد العمليات عند التقفيل", "int", width=15),
            C("الصناديق عند التقفيل", "int", width=14), C("الوزن عند التقفيل (كغ)", "kg"),
            C("قيمة الرمان عند التقفيل (ج.م)", "money", emphasis="bold"),
            C("المدفوع عند التقفيل (ج.م)", "money", emphasis="paid"),
            C("المتبقي عند التقفيل (ج.م)", "money", emphasis="due"),
            C("التعبئة عند التقفيل (ج.م)", "money"),
            C("إجمالي التكلفة عند التقفيل (ج.م)", "money", emphasis="bold"),
            C("ملاحظات", "long"), C("آخر تعديل", "dt"), C("عدّله"), C("الإصدار", "int", hidden=True),
        ],
    },
    {
        "key": "farmers", "title": "المزارعون", "tab": GREEN,
        "desc": "قائمة المزارعين. يُربط كل شراء بالمعرّف وليس بالاسم، فتغيير الاسم لا يفصل العمليات السابقة.",
        "freeze_cols": 3,
        "columns": [
            C("المعرّف", "id"), C("رقم المزارع", "int"), C("الاسم", width=24), C("الهاتف", width=16),
            C("القرية / المنطقة", width=18), C("ملاحظات", "long"), C("الحالة", "enum", ["نشط", "موقوف"]),
            C("تاريخ الإضافة", "dt"), C("أضافه"), C("الإصدار", "int", hidden=True),
        ],
    },
    {
        "key": "purchases", "title": "مشتريات الرمان", "tab": RED,
        "desc": "كل عملية شراء من مزارع. الوزن = الصناديق × متوسط الوزن الصافي، والقيمة = الوزن × سعر الكيلو. "
                "المدفوع والمتبقي يحسبهما التطبيق من صفحة المدفوعات.",
        "freeze_cols": 5,
        "columns": [
            C("المعرّف", "id"), C("معرّف البراد", "id"), C("رقم البراد", "int", width=11),
            C("معرّف المزارع", "id"), C("اسم المزارع", width=24), C("تاريخ ووقت العملية", "dt"),
            C("عدد الصناديق", "int"), C("متوسط وزن الصندوق (كغ)", "kg3"),
            C("طريقة حساب الوزن", "enum", ["مباشر", "عينة"]), C("أوزان العينة (كغ)", width=22),
            C("وزن الصندوق الفارغ (كغ)", "kg3"), C("إجمالي الوزن (كغ)", "kg", emphasis="bold"),
            C("سعر الكيلو (ج.م)", "money", width=14), C("إجمالي السعر (ج.م)", "money", emphasis="bold"),
            C("المدفوع (ج.م)", "money", emphasis="paid"), C("المتبقي (ج.م)", "money", emphasis="due"),
            C("حالة الدفع", "enum", ["مدفوع", "جزئي", "غير مدفوع"]),
            C("الحالة", "enum", ["فعّالة", "ملغاة"]), C("سبب الإلغاء", "long"), C("ملاحظات", "long"),
            C("تاريخ الإنشاء الفعلي", "dt"), C("أنشأها"), C("آخر تعديل", "dt"), C("عدّلها"),
            C("الإصدار", "int", hidden=True), C("مفتاح عدم التكرار", "id", hidden=True),
        ],
    },
    {
        "key": "packaging", "title": "مشتريات التعبئة", "tab": GREEN,
        "desc": "عمليات شراء مواد التعبئة. المسودة لا تدخل الإجماليات المعتمدة. "
                "«تكلفة متأخرة» تعني أنها أُضيفت بعد تقفيل البراد.",
        "freeze_cols": 3,
        "columns": [
            C("المعرّف", "id"), C("رقم الشراء", width=13), C("المورد", width=22), C("رقم الفاتورة", width=14),
            C("تاريخ ووقت الشراء", "dt"), C("معرّف البراد", "id"), C("رقم البراد", "int", width=11),
            C("الحالة", "enum", ["مسودة", "معتمد", "ملغى"]), C("عدد العناصر", "int"),
            C("عناصر غير مكتملة", "int", width=14),
            C("إجمالي العناصر المكتملة (ج.م)", "money", emphasis="bold"),
            C("المدفوع (ج.م)", "money", emphasis="paid"), C("المتبقي (ج.م)", "money", emphasis="due"),
            C("تكلفة متأخرة", "bool", YES_NO), C("ملاحظات", "long"),
            C("تاريخ الإنشاء", "dt"), C("أنشأه"), C("آخر تعديل", "dt"),
            C("الإصدار", "int", hidden=True), C("مفتاح عدم التكرار", "id", hidden=True),
        ],
    },
    {
        "key": "packaging_items", "title": "تفاصيل التعبئة", "tab": GREEN,
        "desc": "العناصر داخل كل شراء تعبئة. الإجمالي = الكمية × السعر المفرد. "
                "الخانة الفارغة تعني «غير مكتمل» وليست صفرًا.",
        "freeze_cols": 4,
        "columns": [
            C("المعرّف", "id"), C("معرّف الشراء", "id"), C("رقم الشراء", width=13), C("الصنف", width=22),
            C("الكمية", "int"), C("الوحدة", "enum", ["قطعة", "رزمة", "لفة", "رول", "كرتونة", "كغ"]),
            C("السعر المفرد (ج.م)", "money", width=15), C("الإجمالي (ج.م)", "money", emphasis="bold"),
            C("الحالة", "enum", ["مكتمل", "غير مكتمل", "محذوف"]), C("ملاحظات", "long"), C("آخر تعديل", "dt"),
            C("الإصدار", "int", hidden=True),
        ],
    },
    {
        "key": "payments", "title": "المدفوعات", "tab": GREEN,
        "desc": "كل دفعة سجل مستقل مرتبط بعملية شراء. إجمالي المدفوع في كل التقارير = مجموع الدفعات الفعّالة هنا.",
        "freeze_cols": 4,
        "columns": [
            C("المعرّف", "id"), C("رقم الدفعة", width=13), C("نوع المستفيد", "enum", ["مزارع", "مورد"]),
            C("اسم المستفيد", width=24), C("معرّف المستفيد", "id"),
            C("نوع العملية", "enum", ["شراء رمان", "شراء تعبئة"]), C("معرّف العملية", "id"),
            C("معرّف البراد", "id"), C("رقم البراد", "int", width=11),
            C("المبلغ (ج.م)", "money", emphasis="paid"),
            C("طريقة الدفع", "enum", ["نقدًا", "تحويل بنكي", "محفظة إلكترونية"]),
            C("تاريخ الدفعة", "dt"), C("الحالة", "enum", ["فعّالة", "ملغاة"]), C("سبب الإلغاء", "long"),
            C("ملاحظات", "long"), C("تاريخ الإنشاء", "dt"), C("أنشأها"),
            C("الإصدار", "int", hidden=True), C("مفتاح عدم التكرار", "id", hidden=True),
        ],
    },
    {
        "key": "users", "title": "المستخدمون", "tab": INK,
        "desc": "الحسابات المسموح لها فقط. يعدّلها المدير من داخل التطبيق، والخادم يتحقق منها مع كل طلب.",
        "freeze_cols": 3,
        "columns": [
            C("المعرّف", "id"), C("البريد (Gmail)", "email"), C("الاسم", width=20),
            C("الدور", "enum", ["مدير", "موظف إدخال", "مشاهدة فقط"]), C("الحالة", "enum", ["نشط", "معطّل"]),
            C("إضافة المزارعين", "bool", YES_NO), C("تسجيل المشتريات", "bool", YES_NO),
            C("تعديل عمليات الآخرين", "bool", YES_NO, width=15), C("تسجيل المدفوعات", "bool", YES_NO),
            C("مشتريات التعبئة", "bool", YES_NO), C("تقفيل البرادات", "bool", YES_NO),
            C("تاريخ الإضافة", "dt"), C("أضافه"), C("آخر تعديل", "dt"), C("الإصدار", "int", hidden=True),
        ],
    },
    {
        "key": "settings", "title": "الإعدادات", "tab": INK,
        "desc": "إعدادات العمل غير السرية فقط. لا تُكتب هنا أي كلمات مرور أو مفاتيح.",
        "freeze_cols": 1,
        "columns": [C("المفتاح", width=28), C("القيمة", width=34), C("الوصف", "long", width=60)],
    },
    {
        "key": "item_types", "title": "أصناف التعبئة", "tab": GREEN,
        "desc": "قائمة أصناف مواد التعبئة ووحداتها الافتراضية. يضيف المدير أصنافًا جديدة من التطبيق.",
        "freeze_cols": 2,
        "columns": [
            C("المعرّف", "id"), C("الصنف", width=26), C("الوحدة الافتراضية", "enum",
                                                          ["قطعة", "رزمة", "لفة", "رول", "كرتونة", "كغ"]),
            C("الترتيب", "int"), C("نشط", "bool", YES_NO),
        ],
    },
    {
        "key": "audit", "title": "سجل التعديلات", "tab": INK,
        "desc": "كل إنشاء وتعديل وإلغاء وتقفيل وإعادة فتح يُسجَّل هنا تلقائيًا ولا يُحذف.",
        "freeze_cols": 2,
        "columns": [
            C("المعرّف", "id"), C("التاريخ والوقت", "dt"), C("المستخدم", width=18),
            C("الإجراء", "enum", ["إنشاء", "تعديل", "إلغاء", "تقفيل", "إعادة فتح", "دفعة"]),
            C("نوع السجل", width=16), C("معرّف السجل", "id"), C("الوصف", "long", width=46),
            C("القيم السابقة", "long"), C("القيم الجديدة", "long"), C("السبب", "long"),
        ],
    },
]
SHEET = {s["key"]: s for s in SHEETS}

# ---------------------------------------------------------------- بيانات الأمثلة


def T(day, hh, mm):
    month = 9 if day > 2 else 10
    return dt.datetime(2026, month, day, hh, mm)


USERS = {"admin": "محمد الحسناوي", "karim": "كريم عبد الله", "youssef": "يوسف ناصر"}

FARMERS = [
    ("FR-0001", 1, "الحاج محمود عبد العال", "0100 123 4567", "البداري"),
    ("FR-0002", 2, "سعيد أبو زيد", "0111 234 5678", "البداري"),
    ("FR-0003", 3, "رمضان حسانين", "0122 345 6789", "ساحل سليم"),
    ("FR-0004", 4, "عبد الرحمن الشافعي", "0106 456 7890", "أبنوب"),
    ("FR-0005", 5, "حسن البدري", "0115 567 8901", "البداري"),
    ("FR-0006", 6, "محمد السيد فرج", "0127 678 9012", "ساحل سليم"),
    ("FR-0007", 7, "إبراهيم عوض", "0109 789 0123", "أبنوب"),
    ("FR-0008", 8, "ياسر عبد الحميد", "0114 890 1234", "البداري"),
    ("FR-0009", 9, "كمال الدسوقي", "0128 901 2345", "منفلوط"),
    ("FR-0010", 10, "ناصر عبد الغني", "0101 012 3456", "منفلوط"),
    ("FR-0011", 11, "فتحي الشرقاوي", "0112 123 4500", "ساحل سليم"),
    ("FR-0012", 12, "عادل حماد", "0120 234 5611", "أبنوب"),
]
FARMER = {f[2]: f for f in FARMERS}

COOLERS = [
    # id, no, name, car, driver, opened, status, closed
    ("CL-0012", 12, "شحنة بورسعيد", "ط ر س 4821", "سامح جاد", T(28, 7, 10), "مقفّل", T(30, 17, 10)),
    ("CL-0013", 13, "شحنة الإسكندرية", "س ع د 2190", "محمود رجب", T(1, 15, 20), "مفتوح", None),
    ("CL-0014", 14, "شحنة دمياط", "ن ق ر 7316", "عادل منصور", T(2, 6, 40), "مفتوح", None),
]
COOLER = {c[1]: c for c in COOLERS}

# cooler, farmer, time, boxes, avg, price, method, paid_at_save, by
PURCHASES = [
    (12, "الحاج محمود عبد العال", T(28, 8, 5), 50, 11.0, 15.0, "مباشر", "full", "karim"),
    (12, "سعيد أبو زيد", T(28, 8, 40), 48, 10.7, 14.5, "مباشر", "full", "karim"),
    (12, "رمضان حسانين", T(29, 11, 20), 54, 11.0, 15.0, "مباشر", 5000, "youssef"),
    (12, "عبد الرحمن الشافعي", T(28, 10, 15), 44, 11.0, 16.0, "مباشر", "full", "youssef"),
    (12, "حسن البدري", T(28, 11, 30), 40, 10.6, 14.0, "عينة", "full", "karim"),
    (12, "محمد السيد فرج", T(29, 7, 50), 40, 10.8, 15.5, "مباشر", "full", "karim"),
    (12, "إبراهيم عوض", T(29, 9, 10), 46, 10.95, 15.0, "مباشر", 4000, "youssef"),
    (12, "ياسر عبد الحميد", T(29, 10, 0), 38, 10.75, 15.0, "مباشر", "full", "karim"),
    (12, "الحاج محمود عبد العال", T(29, 12, 45), 46, 11.0, 15.0, "مباشر", "full", "karim"),
    (12, "سعيد أبو زيد", T(30, 7, 30), 40, 10.7, 14.5, "مباشر", "full", "karim"),
    (12, "عبد الرحمن الشافعي", T(30, 8, 15), 36, 11.0, 16.0, "مباشر", "full", "youssef"),
    (12, "محمد السيد فرج", T(30, 9, 40), 32, 10.8, 15.5, "مباشر", "full", "karim"),
    (12, "ياسر عبد الحميد", T(30, 11, 5), 32, 10.75, 15.0, "مباشر", "full", "karim"),
    (12, "كمال الدسوقي", T(30, 13, 20), 42, 11.0, 14.5, "مباشر", "full", "youssef"),
    (13, "ناصر عبد الغني", T(1, 15, 50), 40, 10.9, 15.0, "مباشر", "full", "karim"),
    (13, "فتحي الشرقاوي", T(1, 16, 35), 42, 11.0, 15.0, "مباشر", 3460, "karim"),
    (13, "عادل حماد", T(1, 17, 10), 30, 10.76, 15.0, "مباشر", None, "youssef"),
    (14, "الحاج محمود عبد العال", T(2, 7, 5), 50, 11.0, 15.0, "مباشر", "full", "karim"),
    (14, "سعيد أبو زيد", T(2, 7, 48), 64, 10.6, 14.5, "عينة", None, "karim"),
    (14, "رمضان حسانين", T(2, 8, 26), 38, 11.4, 15.5, "مباشر", None, "youssef"),
    (14, "الحاج محمود عبد العال", T(2, 9, 31), 22, 10.8, 15.0, "مباشر", None, "karim"),
    (14, "عبد الرحمن الشافعي", T(2, 10, 15), 45, 11.2, 16.0, "مباشر", "full", "youssef"),
    (14, "حسن البدري", T(2, 10, 42), 30, 10.5, 14.0, "مباشر", 2000, "admin"),
]
# دفعات لاحقة: (رقم البراد، اسم المزارع، وقت العملية الأصلية، المبلغ، وقت الدفع، طريقة الدفع، المستخدم)
LATER_PAYMENTS = [(14, "سعيد أبو زيد", T(2, 7, 48), 5000, T(2, 9, 5), "نقدًا", "karim")]

ITEM_TYPES = [("الصناديق", "قطعة"), ("الباليتات", "قطعة"), ("الشمبر", "رزمة"),
              ("جزاري «ورق الفاصل»", "رزمة"), ("المناديل", "كرتونة"), ("غطاء باليت", "قطعة"),
              ("الملصقات", "رول"), ("جهاز تجسس", "قطعة"), ("السترتش", "لفة")]

# رقم الشراء، المورد، الفاتورة، الوقت، البراد، الحالة، متأخر، العناصر [(الصنف، الكمية، الوحدة، السعر)]، المدفوع، المستخدم
PACKAGING = [
    ("P-0088", "مصنع النيل للكرتون", "F-2291", T(27, 18, 0), 12, "معتمد", "لا",
     [("الصناديق", 600, "قطعة", 18.0), ("الملصقات", 600, "قطعة", 0.75)], 11250, "admin"),
    ("P-0089", "الوادي للتغليف", "V-118", T(28, 9, 0), 12, "معتمد", "لا",
     [("الباليتات", 13, "قطعة", 145.0), ("السترتش", 4, "لفة", 210.0), ("الشمبر", 2, "رزمة", 95.0),
      ("جهاز تجسس", 1, "قطعة", 350.0)], 3265, "karim"),
    ("P-0091", "الوادي للتغليف", "V-124", T(1, 10, 30), 12, "معتمد", "نعم",
     [("غطاء باليت", 13, "قطعة", 35.0)], 0, "admin"),
    ("P-0093", "مصنع النيل للكرتون", "F-2307", T(1, 19, 0), 14, "معتمد", "لا",
     [("الصناديق", 250, "قطعة", 18.0)], 2000, "admin"),
    ("P-0095", "الوادي للتغليف", "", T(2, 9, 50), 14, "مسودة", "لا",
     [("الباليتات", 12, "قطعة", 145.0), ("غطاء باليت", 12, "قطعة", None), ("السترتش", 4, "لفة", 210.0),
      ("الملصقات", None, "رول", None)], 0, "karim"),
]

SAMPLE_USERS = [
    ("US-0001", "hasnawi.owner@gmail.com", "محمد الحسناوي", "مدير", "نشط", ["نعم"] * 6),
    ("US-0002", "karim.abdallah.eg@gmail.com", "كريم عبد الله", "موظف إدخال", "نشط",
     ["نعم", "نعم", "لا", "نعم", "نعم", "نعم"]),
    ("US-0003", "youssef.nasser.farm@gmail.com", "يوسف ناصر", "موظف إدخال", "نشط",
     ["نعم", "نعم", "لا", "نعم", "نعم", "لا"]),
    ("US-0004", "salma.fouad.acc@gmail.com", "سلمى فؤاد", "مشاهدة فقط", "نشط", ["لا"] * 6),
    ("US-0005", "ahmed.samir.weigh@gmail.com", "أحمد سمير", "موظف إدخال", "معطّل",
     ["نعم", "نعم", "لا", "لا", "لا", "لا"]),
]

SETTINGS = [
    ("اسم النشاط", "حاسبة الحسناوي", "يظهر في التقارير وملفات PDF."),
    ("العملة", "جنيه مصري (EGP)", "عملة كل المبالغ."),
    ("رمز العملة", "ج.م", "يظهر بجانب المبالغ."),
    ("المنطقة الزمنية", "Africa/Cairo", "تُحسب التواريخ والأوقات على توقيت القاهرة."),
    ("منازل المبالغ", 2, "عدد المنازل العشرية عند عرض المبالغ."),
    ("منازل الأوزان", 1, "عدد المنازل العشرية عند عرض الأوزان."),
    ("وزن الصندوق الفارغ (كغ)", 1.9, "يُطرح من أوزان العينة إذا وُزنت مع الصندوق."),
    ("سياسة التقريب", "قيمة كل عملية تُقرَّب لأقرب قرش (النصف للأعلى)، والإجماليات مجموع القيم المقرّبة.",
     "تضمن تطابق إجماليات العمليات والتقارير."),
    ("بداية الموسم", dt.date(2026, 8, 1), "تبدأ منه فترة «هذا الموسم» في لوحة التحكم."),
    ("صف العناوين", HEADER_ROW, "رقم صف أسماء الأعمدة في كل صفحة. لا تغيّره."),
    ("إصدار المخطط", 1, "يزيد عند تغيير أعمدة الصفحات."),
]


def piasters(x):
    return int(round(x * 100))


def build_sample_rows():
    rows = {k: [] for k in SHEET}
    for fid, no, name, phone, village in FARMERS:
        rows["farmers"].append([fid, no, name, phone, village, None, "نشط", T(20 + min(no, 7), 9, 0),
                                USERS["karim"], 1])

    payments = []
    pay_no = 1
    op_index = {}
    purchase_rows = []
    for i, (cno, fname, when, boxes, avg, price, method, paid, by) in enumerate(PURCHASES, start=1):
        pid = f"PU-{i:04d}"
        cid = COOLER[cno][0]
        grams = boxes * int(round(avg * 1000))
        value_p = int(round(grams * piasters(price) / 1000))
        sample = tame = None
        if method == "عينة":
            sample, tame = "12.4، 12.9، 12.1، 12.6، 12.5", 1.9
        row = [pid, cid, cno, FARMER[fname][0], fname, when, boxes, avg, method, sample, tame,
               grams / 1000, price, value_p / 100, 0, 0, "", "فعّالة", None, None, when, USERS[by],
               None, None, 1, f"k-{i:04d}"]
        purchase_rows.append(row)
        op_index[(cno, fname, when)] = row
        if paid is not None:
            amount = value_p if paid == "full" else piasters(paid)
            payments.append([f"PY-{pay_no:04d}", f"D-{pay_no:04d}", "مزارع", fname, FARMER[fname][0],
                             "شراء رمان", pid, cid, cno, amount / 100, "نقدًا", when, "فعّالة", None,
                             "سُجّلت مع عملية الشراء", when, USERS[by], 1, f"pk-{pay_no:04d}"])
            pay_no += 1
    for cno, fname, when, amount, paid_at, method, by in LATER_PAYMENTS:
        row = op_index[(cno, fname, when)]
        payments.append([f"PY-{pay_no:04d}", f"D-{pay_no:04d}", "مزارع", fname, FARMER[fname][0], "شراء رمان",
                         row[0], row[1], cno, amount, method, paid_at, "فعّالة", None, None, paid_at,
                         USERS[by], 1, f"pk-{pay_no:04d}"])
        pay_no += 1

    paid_by_op = {}
    for p in payments:
        paid_by_op[p[6]] = paid_by_op.get(p[6], 0) + piasters(p[9])
    for row in purchase_rows:
        value_p = piasters(row[13])
        paid_p = paid_by_op.get(row[0], 0)
        row[14], row[15] = paid_p / 100, (value_p - paid_p) / 100
        row[16] = "مدفوع" if paid_p >= value_p else ("جزئي" if paid_p > 0 else "غير مدفوع")
    rows["purchases"] = purchase_rows

    item_rows = []
    det = 1
    for n, (pno, supplier, invoice, when, cno, status, late, items, paid, by) in enumerate(PACKAGING, start=1):
        kid = f"PK-{n:04d}"
        total = 0
        missing = 0
        for name, qty, unit, price in items:
            complete = qty is not None and price is not None
            line = piasters(qty * price) if complete else None
            if complete:
                total += line
            else:
                missing += 1
            item_rows.append([f"PD-{det:04d}", kid, pno, name, qty, unit, price,
                              line / 100 if line is not None else None,
                              "مكتمل" if complete else "غير مكتمل", None, when, 1])
            det += 1
        due = total - piasters(paid) if status == "معتمد" else None
        rows["packaging"].append([kid, pno, supplier, invoice or None, when, COOLER[cno][0], cno, status,
                                  len(items), missing, total / 100,
                                  paid if status == "معتمد" else None,
                                  due / 100 if due is not None else None, late,
                                  "الأغطية والملصقات تُسعّر عند استلام الفاتورة" if missing else None,
                                  when, USERS[by], when, 1, f"kk-{n:04d}"])
        if paid:
            payments.append([f"PY-{pay_no:04d}", f"D-{pay_no:04d}", "مورد", supplier, None, "شراء تعبئة", kid,
                             COOLER[cno][0], cno, paid, "تحويل بنكي", when, "فعّالة", None, None, when,
                             USERS[by], 1, f"pk-{pay_no:04d}"])
            pay_no += 1
    rows["packaging_items"] = item_rows
    rows["payments"] = payments

    # البرادات وخلاصة التقفيل
    for cid, cno, name, car, driver, opened, status, closed in COOLERS:
        ops = [r for r in purchase_rows if r[2] == cno]
        snap = [None] * 9
        if status == "مقفّل":
            value = sum(piasters(r[13]) for r in ops)
            paid = sum(piasters(r[14]) for r in ops)
            pack = sum(piasters(k[10]) for k in rows["packaging"]
                       if k[6] == cno and k[7] == "معتمد" and k[13] == "لا")
            snap = [len({r[3] for r in ops}), len(ops), sum(r[6] for r in ops),
                    sum(int(round(r[11] * 1000)) for r in ops) / 1000,
                    value / 100, paid / 100, (value - paid) / 100, pack / 100, (value + pack) / 100]
        rows["coolers"].append([cid, cno, name, car, driver, opened, status, USERS["admin"],
                                closed, USERS["admin"] if closed else None, *snap, None,
                                closed or opened, USERS["admin"], 1])

    rows["users"] = [[uid, mail, name, role, st, *perms, T(25, 9, 0), USERS["admin"], None, 1]
                     for uid, mail, name, role, st, perms in SAMPLE_USERS]

    rows["audit"] = [
        ["AU-0001", T(30, 17, 10), USERS["admin"], "تقفيل", "براد", "CL-0012",
         "تقفيل براد 12: 9 مزارعين، 14 عملية، 588 صندوقًا، 6,391.4 كغ.", None, None, None],
        ["AU-0002", T(1, 10, 30), USERS["admin"], "إنشاء", "شراء تعبئة", "PK-0003",
         "تكلفة تعبئة متأخرة لبراد 12: غطاء باليت 13 قطعة.", None, None, "وصلت الفاتورة بعد التحميل"],
        ["AU-0003", T(2, 6, 40), USERS["admin"], "إنشاء", "براد", "CL-0014", "فتح براد 14 · شحنة دمياط.",
         None, None, None],
        ["AU-0004", T(2, 7, 5), USERS["karim"], "إنشاء", "شراء رمان", "PU-0018",
         "شراء من الحاج محمود عبد العال: 50 صندوقًا × 11 كغ × 15 ج.م = 8,250.00 ج.م.", None, None, None],
        ["AU-0005", T(2, 9, 5), USERS["karim"], "دفعة", "دفعة", "PY-0023",
         "دفعة 5,000.00 ج.م لسعيد أبو زيد على عملية براد 14.", None, None, None],
        ["AU-0006", T(2, 9, 40), USERS["karim"], "تعديل", "شراء رمان", "PU-0021",
         "تعديل سعر الكيلو في عملية الحاج محمود عبد العال.", "سعر الكيلو: 14.50", "سعر الكيلو: 15.00",
         "خطأ في الإدخال"],
    ]
    return rows


def base_rows():
    """صفوف تبقى في القالب الفارغ أيضًا."""
    return {
        "settings": [list(s) for s in SETTINGS],
        "item_types": [[f"IT-{i:02d}", name, unit, i, "نعم"] for i, (name, unit) in enumerate(ITEM_TYPES, 1)],
    }


# ---------------------------------------------------------------- التنسيق

THIN = Side(style="thin", color=LINE)
WHITE_SIDE = Side(style="thin", color=WHITE)


def fill(color):
    return PatternFill("solid", start_color=color, end_color=color)


def style_data_sheet(ws, sheet, data_rows):
    cols = sheet["columns"]
    ncol = len(cols)
    last = get_column_letter(ncol)
    ws.sheet_view.rightToLeft = True
    ws.sheet_view.zoomScale = 110
    ws.sheet_properties.tabColor = sheet["tab"]

    # العنوان والوصف دون دمج خلايا، حتى يمكن تثبيت الأعمدة الأولى في Google Sheets.
    band = RED if sheet["tab"] == RED else (GREEN if sheet["tab"] == GREEN else INK)
    for j in range(1, ncol + 1):
        ws.cell(TITLE_ROW, j).fill = fill(band)
        ws.cell(DESC_ROW, j).fill = fill(IVORY)
    t = ws.cell(TITLE_ROW, 1, sheet["title"])
    t.font = Font(name=FONT, size=20, bold=True, color=WHITE)
    t.alignment = Alignment(horizontal="right", vertical="center", indent=1, readingOrder=2)
    ws.row_dimensions[TITLE_ROW].height = 44
    d = ws.cell(DESC_ROW, 1, sheet["desc"])
    d.font = Font(name=FONT, size=12, color=INK2)
    d.alignment = Alignment(horizontal="right", vertical="center", indent=1, readingOrder=2)
    ws.row_dimensions[DESC_ROW].height = 30

    for j, col in enumerate(cols, start=1):
        width, numfmt, align = KINDS[col["kind"]]
        letter = get_column_letter(j)
        ws.column_dimensions[letter].width = col["width"] or width
        if col["hidden"]:
            ws.column_dimensions[letter].hidden = True
        h = ws.cell(HEADER_ROW, j, col["name"])
        h.font = Font(name=FONT, size=13, bold=True, color=WHITE)
        h.fill = fill(GREEN if col["kind"] != "id" else "3B4A3F")
        h.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True, readingOrder=2)
        h.border = Border(left=WHITE_SIDE, right=WHITE_SIDE)
    ws.row_dimensions[HEADER_ROW].height = 48

    for i, values in enumerate(data_rows):
        for j, v in enumerate(values, start=1):
            ws.cell(FIRST_ROW + i, j, v)

    styled = max(STYLED_ROWS, len(data_rows) + 50)
    for r in range(FIRST_ROW, FIRST_ROW + styled):
        ws.row_dimensions[r].height = 28
        for j, col in enumerate(cols, start=1):
            _, numfmt, align = KINDS[col["kind"]]
            c = ws.cell(r, j)
            emphasis = col["emphasis"]
            color = INK
            bold = emphasis in ("bold", "paid", "due")
            if col["kind"] == "id":
                color = MUTED
            elif emphasis == "paid":
                color = GREEN
            elif emphasis == "due":
                color = AMBER
            c.font = Font(name=FONT, size=10 if col["kind"] == "id" else 13, bold=bold, color=color)
            c.number_format = numfmt
            c.alignment = Alignment(horizontal=align, vertical="center",
                                    wrap_text=col["kind"] == "long", readingOrder=2)
            c.border = Border(bottom=THIN, left=THIN, right=THIN)

    end = FIRST_ROW + styled - 1
    data_ref = f"A{FIRST_ROW}:{last}{end}"
    # ألوان الحالات
    for j, col in enumerate(cols, start=1):
        if not col["options"]:
            continue
        letter = get_column_letter(j)
        rng = f"{letter}{FIRST_ROW}:{letter}{end}"
        dv = DataValidation(type="list", formula1='"' + ",".join(col["options"]) + '"', allow_blank=True,
                            showErrorMessage=True, errorTitle="قيمة غير صحيحة",
                            error="اختر قيمة من القائمة.")
        ws.add_data_validation(dv)
        dv.add(rng)
        for opt in col["options"]:
            if opt in VALUE_STYLES:
                bg, fg, strike = VALUE_STYLES[opt]
                ws.conditional_formatting.add(rng, CellIsRule(
                    operator="equal", formula=[f'"{opt}"'], fill=fill(bg),
                    font=Font(color=fg, bold=True, strike=strike)))
    # تظليل الصفوف المملوءة بالتناوب
    ws.conditional_formatting.add(data_ref, FormulaRule(
        formula=[f'AND(MOD(ROW(),2)=1,$A{FIRST_ROW}<>"")'], fill=fill(IVORY)))

    ws.freeze_panes = ws.cell(FIRST_ROW, sheet.get("freeze_cols", 1) + 1)
    ws.auto_filter.ref = f"A{HEADER_ROW}:{last}{end}"
    ws.page_setup.orientation = "landscape"
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.print_title_rows = f"{HEADER_ROW}:{HEADER_ROW}"


# ---------------------------------------------------------------- صفحة الملخص

def q(title):
    return "'" + title + "'"


def col_of(key, name):
    for j, c in enumerate(SHEET[key]["columns"], start=1):
        if c["name"] == name:
            return get_column_letter(j)
    raise KeyError(name)


def rng(key, name, last=FORMULA_ROWS):
    letter = col_of(key, name)
    return f"{q(SHEET[key]['title'])}!${letter}${FIRST_ROW}:${letter}${last}"


def summary_formulas():
    P, K, Y, B = "purchases", "packaging", "payments", "coolers"
    active = f'{rng(P, "الحالة")},"فعّالة"'
    f = {}
    f["closed"] = f'=COUNTIF({rng(B, "الحالة")},"مقفّل")'
    f["open"] = f'=COUNTIF({rng(B, "الحالة")},"مفتوح")'
    fr, st = rng(P, "معرّف المزارع", 1500), rng(P, "الحالة", 1500)
    f["farmers"] = (f'=SUMPRODUCT(({fr}<>"")*({st}="فعّالة")/COUNTIFS({fr},{fr}&"",{st},{st}&""))')
    f["ops"] = f'=COUNTIFS({rng(P, "المعرّف")},"<>",{active})'
    f["boxes"] = f'=SUMIFS({rng(P, "عدد الصناديق")},{active})'
    f["weight"] = f'=SUMIFS({rng(P, "إجمالي الوزن (كغ)")},{active})'
    f["value"] = f'=SUMIFS({rng(P, "إجمالي السعر (ج.م)")},{active})'
    f["packaging"] = f'=SUMIFS({rng(K, "إجمالي العناصر المكتملة (ج.م)")},{rng(K, "الحالة")},"معتمد")'
    pay_ok = f'{rng(Y, "الحالة")},"فعّالة"'
    f["paid"] = f'=SUMIFS({rng(Y, "المبلغ (ج.م)")},{pay_ok})'
    f["paid_farmers"] = f'=SUMIFS({rng(Y, "المبلغ (ج.م)")},{pay_ok},{rng(Y, "نوع العملية")},"شراء رمان")'
    f["paid_suppliers"] = f'=SUMIFS({rng(Y, "المبلغ (ج.م)")},{pay_ok},{rng(Y, "نوع العملية")},"شراء تعبئة")'
    return f


CARD_ROW = 4  # صف أول سطر من البطاقات (العنوان)، والقيمة في الصف الذي يليه


def summary_cards():
    """ثلاثة أسطر من البطاقات. كل بطاقة تشغل عمودين: B:C ثم D:E ثم F:G ثم H:I ثم J:K."""
    f = summary_formulas()
    v2 = CARD_ROW + 4  # صف قيم السطر الثاني
    weight, value, pack, paid = f"B{v2}", f"D{v2}", f"F{v2}", f"H{v2}"
    return [
        [("برادات مقفّلة ومحمّلة", f["closed"], "#,##0", "plain"), ("برادات مفتوحة", f["open"], "#,##0", "plain"),
         ("مزارعون مختلفون", f["farmers"], "#,##0", "plain"), ("عمليات شراء الرمان", f["ops"], "#,##0", "plain"),
         ("إجمالي الصناديق", f["boxes"], "#,##0", "plain")],
        [("إجمالي الوزن (كغ)", f["weight"], "#,##0.0", "plain"),
         ("قيمة شراء الرمان (ج.م)", f["value"], "#,##0.00", "value"),
         ("مشتريات التعبئة المعتمدة (ج.م)", f["packaging"], "#,##0.00", "value"),
         ("المدفوع فعليًا (ج.م)", f["paid"], "#,##0.00", "paid"),
         ("المتبقي (ج.م)", f"={value}+{pack}-{paid}", "#,##0.00", "due")],
        [("متوسط سعر الكيلو (ج.م)", f"=IFERROR({value}/{weight},0)", "#,##0.00", "plain"),
         ("المتبقي للمزارعين (ج.م)", f'={value}-({f["paid_farmers"][1:]})', "#,##0.00", "due"),
         ("المتبقي للموردين (ج.م)", f'={pack}-({f["paid_suppliers"][1:]})', "#,##0.00", "due")],
    ]


TABLE_HEADS = ["رقم البراد", "الاسم", "الحالة", "عدد العمليات", "الصناديق", "الوزن (كغ)", "قيمة الرمان (ج.م)",
               "المدفوع للمزارعين (ج.م)", "المتبقي للمزارعين (ج.م)", "التعبئة المعتمدة (ج.م)",
               "إجمالي التكلفة (ج.م)"]
TABLE_FORMATS = ["0", "@", "@", "#,##0", "#,##0", "#,##0.0", "#,##0.00", "#,##0.00", "#,##0.00", "#,##0.00",
                 "#,##0.00"]
TABLE_TITLE_ROW = CARD_ROW + 10
TABLE_FIRST_ROW = TABLE_TITLE_ROW + 2
TABLE_COUNT = 60


def cooler_table_rows():
    """معادلات صف لكل براد في صفحة البرادات (من الأعمدة B إلى L)."""
    B, P, K, Y = "coolers", "purchases", "packaging", "payments"
    ct = q(SHEET[B]["title"])
    c_id, c_no, c_name, c_st = (col_of(B, n) for n in ("المعرّف", "رقم البراد", "الاسم / الوصف", "الحالة"))
    active = f'{rng(P, "الحالة")},"فعّالة"'
    rows = []
    for i in range(TABLE_COUNT):
        r = TABLE_FIRST_ROW + i
        k = FIRST_ROW + i
        cid = f"{ct}!${c_id}{k}"
        blank = f'IF({ct}!${c_no}{k}="",""'
        rows.append([
            f"={blank},{ct}!${c_no}{k})",
            f"={blank},{ct}!${c_name}{k})",
            f"={blank},{ct}!${c_st}{k})",
            f'={blank},COUNTIFS({rng(P, "معرّف البراد")},{cid},{active}))',
            f'={blank},SUMIFS({rng(P, "عدد الصناديق")},{rng(P, "معرّف البراد")},{cid},{active}))',
            f'={blank},SUMIFS({rng(P, "إجمالي الوزن (كغ)")},{rng(P, "معرّف البراد")},{cid},{active}))',
            f'={blank},SUMIFS({rng(P, "إجمالي السعر (ج.م)")},{rng(P, "معرّف البراد")},{cid},{active}))',
            f'={blank},SUMIFS({rng(Y, "المبلغ (ج.م)")},{rng(Y, "معرّف البراد")},{cid},'
            f'{rng(Y, "نوع العملية")},"شراء رمان",{rng(Y, "الحالة")},"فعّالة"))',
            f'={blank},H{r}-I{r})',
            f'={blank},SUMIFS({rng(K, "إجمالي العناصر المكتملة (ج.م)")},{rng(K, "معرّف البراد")},{cid},'
            f'{rng(K, "الحالة")},"معتمد"))',
            f'={blank},H{r}+K{r})',
        ])
    return rows


def build_summary(ws):
    ws.sheet_view.rightToLeft = True
    ws.sheet_view.showGridLines = False
    ws.sheet_view.zoomScale = 110
    ws.sheet_properties.tabColor = RED
    ws.column_dimensions["A"].width = 3
    for j in range(2, 14):
        ws.column_dimensions[get_column_letter(j)].width = 16

    ws.merge_cells("B1:L1")
    t = ws["B1"]
    t.value = "حاسبة الرمان — ملخص الموسم"
    t.font = Font(name=FONT, size=24, bold=True, color=WHITE)
    t.fill = fill(RED)
    t.alignment = Alignment(horizontal="right", vertical="center", indent=1, readingOrder=2)
    ws.row_dimensions[1].height = 56
    ws.merge_cells("B2:L2")
    s = ws["B2"]
    s.value = "تتحدث هذه الأرقام تلقائيًا من الصفحات الأخرى. لا تكتب في هذه الصفحة."
    s.font = Font(name=FONT, size=12, color=INK2)
    s.fill = fill(IVORY)
    s.alignment = Alignment(horizontal="right", vertical="center", indent=1, readingOrder=2)
    ws.row_dimensions[2].height = 30

    cards = summary_cards()
    palette = {
        "plain": (GRAY_L, WHITE, INK), "value": (RED_L, WHITE, RED),
        "paid": (GREEN_L, GREEN_L, GREEN), "due": (AMBER_L, AMBER_L, AMBER),
    }
    row = CARD_ROW
    for line in cards:
        for k, card in enumerate(line):
            if card is None:
                continue
            label, formula, numfmt, kind = card
            c1 = get_column_letter(2 + 2 * k)
            c2 = get_column_letter(3 + 2 * k)
            lab_bg, val_bg, val_fg = palette[kind]
            ws.merge_cells(f"{c1}{row}:{c2}{row}")
            ws.merge_cells(f"{c1}{row + 1}:{c2}{row + 1}")
            a = ws[f"{c1}{row}"]
            a.value = label
            a.font = Font(name=FONT, size=12, bold=True, color=INK2 if kind == "plain" else val_fg)
            a.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True, readingOrder=2)
            b = ws[f"{c1}{row + 1}"]
            b.value = formula
            b.number_format = numfmt
            b.font = Font(name=FONT, size=22, bold=True, color=val_fg)
            b.alignment = Alignment(horizontal="center", vertical="center")
            edge = Side(style="medium", color=WHITE)
            for cc in (c1, c2):
                ws[f"{cc}{row}"].fill = fill(lab_bg)
                ws[f"{cc}{row + 1}"].fill = fill(val_bg)
                ws[f"{cc}{row}"].border = Border(left=edge, right=edge, top=edge)
                ws[f"{cc}{row + 1}"].border = Border(left=edge, right=edge, bottom=edge,
                                                      top=Side(style="thin", color=LINE))
        ws.row_dimensions[row].height = 32
        ws.row_dimensions[row + 1].height = 48
        ws.row_dimensions[row + 2].height = 12
        row += 3

    # جدول البرادات
    top = TABLE_TITLE_ROW
    ws.merge_cells(f"B{top}:L{top}")
    h = ws[f"B{top}"]
    h.value = "ملخص البرادات"
    h.font = Font(name=FONT, size=18, bold=True, color=WHITE)
    h.fill = fill(GREEN)
    h.alignment = Alignment(horizontal="right", vertical="center", indent=1, readingOrder=2)
    ws.row_dimensions[top].height = 40
    hr = top + 1
    for k, name in enumerate(TABLE_HEADS):
        c = ws.cell(hr, 2 + k, name)
        c.font = Font(name=FONT, size=12, bold=True, color=INK)
        c.fill = fill(GREEN_L)
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True, readingOrder=2)
        c.border = Border(bottom=Side(style="medium", color=GREEN))
    ws.row_dimensions[hr].height = 44

    first, count = TABLE_FIRST_ROW, TABLE_COUNT
    for i, cells in enumerate(cooler_table_rows()):
        r = first + i
        for j, (formula, fmt) in enumerate(zip(cells, TABLE_FORMATS)):
            c = ws.cell(r, 2 + j, formula)
            c.number_format = fmt
            color = GREEN if j == 7 else (AMBER if j == 8 else INK)
            c.font = Font(name=FONT, size=13, bold=j in (0, 6, 7, 8, 10), color=color)
            c.alignment = Alignment(horizontal="right" if j == 1 else "center", vertical="center",
                                    readingOrder=2)
            c.border = Border(bottom=THIN)
        ws.row_dimensions[r].height = 28
    table = f"B{first}:L{first + count - 1}"
    ws.conditional_formatting.add(f"D{first}:D{first + count - 1}", CellIsRule(
        operator="equal", formula=['"مفتوح"'], fill=fill(GREEN_L), font=Font(color=GREEN, bold=True)))
    ws.conditional_formatting.add(f"D{first}:D{first + count - 1}", CellIsRule(
        operator="equal", formula=['"مقفّل"'], fill=fill(GRAY_L), font=Font(color=GRAY, bold=True)))
    ws.conditional_formatting.add(table, FormulaRule(
        formula=[f'AND(MOD(ROW(),2)=1,$B{first}<>"")'], fill=fill(IVORY)))
    ws.freeze_panes = "A3"
    ws.page_setup.orientation = "landscape"
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0
    ws.sheet_properties.pageSetUpPr.fitToPage = True


# ---------------------------------------------------------------- الكتابة

def build_workbook(with_samples):
    wb = Workbook()
    summary = wb.active
    summary.title = "لوحة الملخص"
    rows = build_sample_rows() if with_samples else {k: [] for k in SHEET}
    rows.update(base_rows())
    for sheet in SHEETS:
        ws = wb.create_sheet(sheet["title"])
        style_data_sheet(ws, sheet, rows[sheet["key"]])
    build_summary(summary)
    wb.calculation.fullCalcOnLoad = True
    return wb, rows


def schema_json():
    return {
        "version": 1,
        "headerRow": HEADER_ROW,
        "firstDataRow": FIRST_ROW,
        "sheets": [
            {
                "key": s["key"], "title": s["title"], "description": s["desc"], "tabColor": "#" + s["tab"],
                "freezeColumns": s.get("freeze_cols", 1),
                "columns": [
                    {"name": c["name"], "kind": c["kind"], "width": c["width"] or KINDS[c["kind"]][0],
                     "numberFormat": KINDS[c["kind"]][1], "align": KINDS[c["kind"]][2],
                     "options": c["options"], "hidden": c["hidden"], "emphasis": c["emphasis"]}
                    for c in s["columns"]
                ],
            }
            for s in SHEETS
        ],
    }


def json_default(v):
    if isinstance(v, (dt.datetime, dt.date)):
        return v.isoformat()
    raise TypeError(v)


def write_setup_gs(schema, base, summary):
    template = open(os.path.join(HERE, "setup.template.gs"), encoding="utf-8").read()
    gs = (template
          .replace("__SCHEMA__", json.dumps(schema, ensure_ascii=False, indent=2))
          .replace("__BASE_ROWS__", json.dumps(base, ensure_ascii=False, indent=2, default=json_default))
          .replace("__VALUE_STYLES__", json.dumps({k: list(v) for k, v in VALUE_STYLES.items()},
                                                  ensure_ascii=False))
          .replace("__SUMMARY__", json.dumps(summary, ensure_ascii=False, indent=2)))
    with open(os.path.join(HERE, "setup.gs"), "w", encoding="utf-8") as fh:
        fh.write(gs)


def main():
    wb, _ = build_workbook(with_samples=True)
    wb.save(os.path.join(HERE, "rumman-calculator.xlsx"))
    wb, _ = build_workbook(with_samples=False)
    wb.save(os.path.join(HERE, "rumman-calculator-template.xlsx"))

    schema = schema_json()
    with open(os.path.join(HERE, "schema.json"), "w", encoding="utf-8") as fh:
        json.dump(schema, fh, ensure_ascii=False, indent=2)

    summary = {
        "cards": [[list(c) for c in line] for line in summary_cards()],
        "cardRow": CARD_ROW,
        "tableTitleRow": TABLE_TITLE_ROW,
        "tableFirstRow": TABLE_FIRST_ROW,
        "tableHeads": TABLE_HEADS,
        "tableFormats": TABLE_FORMATS,
        "tableRows": cooler_table_rows(),
    }
    write_setup_gs(schema, base_rows(), summary)
    print("sheet files written")


if __name__ == "__main__":
    main()
