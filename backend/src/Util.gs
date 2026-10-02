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

/** سبب مطلوب للإلغاء أو إعادة الفتح. */
function inReason_(v, label) {
  return inStr_(v, 'reason', label || 'السبب', { required: true, max: 500, multiline: true, hint: 'اكتب سببًا واضحًا ثم أعد المحاولة.' });
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
