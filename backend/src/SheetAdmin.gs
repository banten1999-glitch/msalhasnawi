/**
 * SheetAdmin.gs — حالة ملف Google Sheets وإصلاحه وربط ملف آخر (للمدير).
 *
 * - sheet.status: قراءة فقط.
 * - sheet.repair: يُنشئ الصفحات والأعمدة الناقصة ويعيد التنسيق باستخدام buildDataSheet_ وbuildSummary_
 *   من sheets/setup.gs، ولا يحذف أي بيانات أو صفحات.
 * - sheet.connect: للمدير الأساسي فقط. يتحقق أن openById يعمل قبل حفظ SPREADSHEET_ID. لا ينقل البيانات القديمة.
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

/**
 * sheet.connect {spreadsheet} → SheetStatus + warning.
 * للمدير الأساسي فقط (قرار في العقد §6): ربط ملف آخر ينقل البيانات إلى ملف قد يملكه شخص آخر، فيخرجها
 * من سيطرة صاحب الحساب (العقد §1: الموظفون لا يصلون إلى الملف مباشرة). يُفحص قبل أي شيء آخر حتى لا
 * يكشف الرد حساب الربط لغير المدير الأساسي.
 */
function sheetConnectAction_(p, user) {
  if (!user || user.isBootstrap !== true) {
    throw apiError_('FORBIDDEN',
      'ربط ملف بيانات آخر متاح للمدير الأساسي (صاحب الحساب) فقط، لأنه ينقل كل العمليات الجديدة إلى ذلك الملف. ' +
      'اطلب من المدير الأساسي ربط الملف إن لزم.', null, { permission: 'manageSettings', reason: 'bootstrap_only' });
  }
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
