/**
 * Store.gs — طبقة الجداول فوق Google Sheets.
 *
 * - الملف: SPREADSHEET_ID إن وُجد، وإلا الملف المرتبط بالسكربت.
 * - الصفحات تُعرف بعناوينها في SCHEMA (من sheets/setup.gs)، والأعمدة بأسمائها في صف العناوين
 *   SCHEMA.headerRow — لا بمواقعها أبدًا.
 * - كل صفحة تُقرأ مرة واحدة لكل طلب (getValues واحدة) وتُحفظ في الذاكرة، والكتابة تحدّث النسخة
 *   المحفوظة أيضًا.
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
    created: [],
    audit: [],
    lockHeld: false,
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

/** يُسقط كل ما قُرئ من الصفحات لإعادة القراءة (بعد أخذ القفل أو بعد الإصلاح). */
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
 * يقرأ الصفحة مرة واحدة لكل طلب. السجل كائن مفاتيحه أسماء الأعمدة، مع $row (رقم الصف) و$vals (القيم الخام).
 * سجل التعديلات يُقرأ «خفيفًا»: العناوين وعمود المعرّف فقط، لأنه يكبر ولا نحتاج إلا أكبر معرّف.
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
      let values;
      if (t.light) {
        values = [sh.getRange(hr, 1, 1, lastCol).getValues()[0]];
      } else {
        values = sh.getRange(hr, 1, lastRow - hr + 1, lastCol).getValues();
      }
      t.headers = values[0].map(stHeaderName_);
      t.headers.forEach(function (h, j) {
        if (h && t.col[h] === undefined) t.col[h] = j;
      });
      const keyIdx = t.col[keyName];
      if (t.light) {
        if (keyIdx !== undefined && lastRow > hr) {
          const ids = sh.getRange(hr + 1, keyIdx + 1, lastRow - hr, 1).getValues();
          ids.forEach(function (r, i) {
            const id = cellStr_(r[0]);
            if (!id) return;
            const rec = { $row: hr + 1 + i, $vals: null };
            rec[keyName] = id;
            t.rows.push(rec);
          });
        }
      } else if (keyIdx !== undefined) {
        for (let i = 1; i < values.length; i++) {
          const vals = values[i];
          if (cellStr_(vals[keyIdx]) === '') continue;
          t.rows.push(stMakeRec_(t, hr + i, vals));
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
      const t = SCHEMA.sheets.filter(function (d) { return d.title === m.sheet; })[0];
      const whole = t && m.columns.length === t.columns.length;
      return whole ? 'صفحة «' + m.sheet + '»' : 'أعمدة في صفحة «' + m.sheet + '»: ' + m.columns.join('، ');
    });
    throw apiError_('SHEET_SCHEMA',
      'ملف Google Sheets ينقصه: ' + parts.join('؛ ') + '. افتح «إعدادات الملف» واضغط «إصلاح الملف»، أو اطلب ذلك من المدير.',
      null, { missing: missing });
  }
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
      if (j !== undefined) vals[j] = c[h] === null || c[h] === undefined ? '' : c[h];
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
  recs.forEach(function (r) { t.rows.push(r); });
  if (opts.track !== false) {
    recs.forEach(function (r) { rq_().created.push({ t: t, rec: r }); });
  }
  stMarkWrite_();
  return recs;
}

/**
 * يحدّث خلايا صف في مكانه. يزيد الإصدار (إلا إن bump=false) ويضع ختم التعديل.
 * يكتب نطاقًا متصلًا واحدًا من أول عمود متغير إلى آخره.
 */
function stUpdate_(t, rec, changes, opts) {
  opts = opts || {};
  const c = Object.assign({}, changes);
  if (opts.bump !== false && t.col['الإصدار'] !== undefined) {
    c['الإصدار'] = (cellInt_(rec['الإصدار']) || 1) + 1;
  }
  if (opts.stamp !== false) stStamp_(t, c);
  const names = Object.keys(c).filter(function (n) { return t.col[n] !== undefined; });
  if (!names.length) return rec;
  const idx = names.map(function (n) { return t.col[n]; });
  const lo = Math.min.apply(null, idx);
  const hi = Math.max.apply(null, idx);
  const slice = [];
  for (let j = lo; j <= hi; j++) {
    const h = t.headers[j];
    let v = rec.$vals && j < rec.$vals.length ? rec.$vals[j] : '';
    if (h && t.col[h] === j && Object.prototype.hasOwnProperty.call(c, h)) {
      v = c[h] === null || c[h] === undefined ? '' : c[h];
    }
    slice.push(v);
  }
  t.sheet.getRange(rec.$row, lo + 1, 1, hi - lo + 1).setValues([slice.map(cellOut_)]);
  if (!rec.$vals) rec.$vals = [];
  slice.forEach(function (v, k) { rec.$vals[lo + k] = v; });
  names.forEach(function (n) { rec[n] = c[n] === null || c[n] === undefined ? '' : c[n]; });
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

/** يكتب أسطر السجل المعلقة في صفحة سجل التعديلات. */
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

/** يقارن قيم أعمدة قبل/بعد ويعيد ما تغيّر فقط {prev, next}. */
function auditDiff_(before, after) {
  const prev = {};
  const next = {};
  Object.keys(after).forEach(function (k) {
    const a = before[k];
    const b = after[k];
    const sa = isDate_(a) ? a.getTime() : a;
    const sb = isDate_(b) ? b.getTime() : b;
    if (String(sa === null || sa === undefined ? '' : sa) !== String(sb === null || sb === undefined ? '' : sb)) {
      prev[k] = a === undefined ? '' : a;
      next[k] = b;
    }
  });
  return { prev: prev, next: next, changed: Object.keys(next).length > 0 };
}

// =====================================================================================
// التعويض عند الفشل الجزئي
// =====================================================================================

/**
 * عند فشل كتابة لاحقة: الصفوف التي أُنشئت في هذا الطلب تُلغى (لا تُحذف)، ويُغيَّر مفتاح عدم التكرار
 * حتى تنجح إعادة المحاولة بنفس requestId. لا يرمي أبدًا.
 */
function stCompensate_() {
  const rq = rq_();
  const list = rq.created.splice(0, rq.created.length).reverse();
  rq.audit = [];
  const reason = RMN_CFG.compensationReason;
  const targets = [];
  list.forEach(function (entry) {
    const t = entry.t;
    const rec = entry.rec;
    try {
      const c = {};
      if (t.key === 'purchases' || t.key === 'payments') {
        c['الحالة'] = 'ملغاة';
        c['سبب الإلغاء'] = reason;
      } else if (t.key === 'packaging') {
        c['الحالة'] = 'ملغى';
        c['ملاحظات'] = appendNote_(rec['ملاحظات'], reason);
      } else if (t.key === 'packaging_items') {
        c['الحالة'] = 'محذوف';
      } else if (t.key === 'farmers') {
        c['الحالة'] = 'موقوف';
        c['ملاحظات'] = appendNote_(rec['ملاحظات'], reason);
      } else {
        return;
      }
      const key = cellStr_(rec['مفتاح عدم التكرار']);
      if (t.col['مفتاح عدم التكرار'] !== undefined && key) c['مفتاح عدم التكرار'] = key + RMN_CFG.failedKeySuffix;
      stUpdate_(t, rec, c);
      if (t.key === 'payments') {
        targets.push({
          type: enumToApi_('payTarget', rec['نوع العملية'], 'purchase'),
          id: cellStr_(rec['معرّف العملية']),
        });
      }
    } catch (e) {
      // نكمل بقية التعويض.
    }
  });
  targets.forEach(function (x) {
    try {
      paymentsRefreshTarget_(x.type, x.id);
    } catch (e) {
      // نتجاهل.
    }
  });
}
