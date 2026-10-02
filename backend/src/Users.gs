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
