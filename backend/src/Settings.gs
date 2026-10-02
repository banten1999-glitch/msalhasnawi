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
