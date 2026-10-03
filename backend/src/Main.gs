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
      if (typeof console !== 'undefined' && console.error) console.error('INTERNAL', rq.action, cfgRedact_(msg), cfgRedact_(stack));
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
