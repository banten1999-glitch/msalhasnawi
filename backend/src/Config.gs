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

/** مدة الجلسة بالأيام (افتراضيًا 7، بين 1 و90). */
function cfgSessionDays_() {
  const n = parseInt(cfgGet_(RMN_PROP.sessionDays), 10);
  if (!isFinite(n) || n < 1) return RMN_CFG.defaultSessionDays;
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
