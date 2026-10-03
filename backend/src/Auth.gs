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
 * فحص محلي رخيص قبل استدعاء tokeninfo: auth.login متاح دون جلسة، وكل استدعاء لـ UrlFetchApp يُحسب من
 * الحصة اليومية، فلا نصرفه على رمز لا يمكن أن يقبله tokeninfo أصلًا. يُشترط شكل JWT (ثلاثة أجزاء
 * base64url) وأن تكون حمولته (دون التحقق من التوقيع) لعميل مسموح، ومن Google، وغير منتهية.
 * tokeninfo يبقى الفحص الحاسم للتوقيع وكل الشروط.
 */
function authPrecheckIdToken_(idToken) {
  const malformed = function () {
    return authInvalidToken_('رمز الدخول من Google غير صالح. سجّل الدخول بحساب Google مرة أخرى.', 'malformed');
  };
  const parts = String(idToken).trim().split('.');
  const seg = /^[A-Za-z0-9_-]+={0,2}$/;
  if (parts.length !== 3 || !seg.test(parts[0]) || !seg.test(parts[1]) || !seg.test(parts[2])) throw malformed();
  let claims = null;
  try {
    let b64 = parts[1].replace(/=+$/, '');
    while (b64.length % 4) b64 += '=';
    claims = JSON.parse(Utilities.newBlob(Utilities.base64DecodeWebSafe(b64)).getDataAsString());
  } catch (e) {
    claims = null;
  }
  if (!isPlainObject_(claims)) throw malformed();
  const allowed = cfgAllowedClientIds_();
  const auds = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (!auds.some(function (a) { return allowed.indexOf(String(a)) >= 0; })) throw authAudienceError_();
  if (RMN_CFG.tokenIssuers.indexOf(String(claims.iss || '')) < 0) throw authIssuerError_();
  const exp = Number(claims.exp);
  if (!isFinite(exp) || exp * 1000 <= rq_().now.getTime()) throw authTokenExpiredError_();
}

function authAudienceError_() {
  return authInvalidToken_('رمز الدخول صادر لتطبيق غير معروف. استخدم تطبيق حاسبة الرمان الرسمي ثم سجّل الدخول مرة أخرى.', 'audience');
}

function authIssuerError_() {
  return authInvalidToken_('رمز الدخول ليس صادرًا من Google. سجّل الدخول بحساب Google مرة أخرى.', 'issuer');
}

function authTokenExpiredError_() {
  return authInvalidToken_('انتهت صلاحية رمز الدخول من Google. سجّل الدخول مرة أخرى.', 'expired');
}

/**
 * يتحقق من ID token عبر tokeninfo ويعيد {email, name, sub}.
 * تُفحص: الرد 200، aud ضمن المعرّفات المسموحة، iss، email_verified، exp.
 */
function authVerifyGoogleToken_(idToken) {
  authPrecheckIdToken_(idToken);
  let resp;
  try {
    resp = UrlFetchApp.fetch(RMN_CFG.tokenInfoUrl + encodeURIComponent(idToken), { muteHttpExceptions: true });
  } catch (e) {
    // العقد: أي رد غير 200 ⇒ AUTH_INVALID_TOKEN. نسجل السبب للتشخيص، لكن رسالة UrlFetchApp تتضمن الرابط
    // وفيه رمز الدخول نفسه، فيُحذف قبل الحفظ (LAST_ERROR يظهر لكل مدير).
    cfgRecordError_('tokeninfo fetch failed: ' + cfgRedact_(e && e.message ? e.message : e));
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
  if (cfgAllowedClientIds_().indexOf(String(info.aud || '')) < 0) throw authAudienceError_();
  if (RMN_CFG.tokenIssuers.indexOf(String(info.iss || '')) < 0) throw authIssuerError_();
  if (!(info.email_verified === true || info.email_verified === 'true')) {
    throw authInvalidToken_('بريد حساب Google غير مؤكَّد. أكّد البريد من إعدادات حساب Google ثم سجّل الدخول مرة أخرى.', 'email_unverified');
  }
  const exp = Number(info.exp);
  if (!isFinite(exp) || exp * 1000 <= rq_().now.getTime()) throw authTokenExpiredError_();
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
    ? 'الحساب ' + email + ' معطّل: خانة «الحالة» في صفحة «المستخدمون» ليست «نشط». ' +
      'اطلب من المدير تفعيله (اختيار «نشط») ثم سجّل الدخول مرة أخرى.'
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
