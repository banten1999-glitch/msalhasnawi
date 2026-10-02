/**
 * Farmers.gs — صفحة «المزارعون». كل شراء مرتبط بمعرّف المزارع لا باسمه.
 */

function farmerToApi_(rec) {
  return {
    id: cellStr_(rec['المعرّف']),
    no: cellInt_(rec['رقم المزارع']),
    name: cellStr_(rec['الاسم']),
    phone: cellStr_(rec['الهاتف']),
    village: cellStr_(rec['القرية / المنطقة']),
    notes: cellStr_(rec['ملاحظات']),
    status: enumToApi_('farmerStatus', rec['الحالة'], 'active'),
    version: stVersion_(rec),
  };
}

/** رقم هاتف اختياري: أرقام مع + ومسافات وشرطات وأقواس، حتى 20 رقمًا. يُحفظ نصًا كما كُتب. */
function farmersPhoneInput_(v, field) {
  const raw = inStr_(v, field, 'رقم الهاتف', { max: 30 });
  if (!raw) return '';
  const s = digitsToLatin_(raw).replace(/\s+/g, ' ').trim();
  const digits = s.replace(/\D/g, '');
  if (!/^\+?[\d\s\-()]+$/.test(s) || digits.length < 1 || digits.length > 20) {
    failValidation_(field, 'رقم الهاتف «' + raw + '» غير صحيح. اكتب الأرقام فقط مثل 01001234567.');
  }
  return s;
}

/** مزارع بنفس الاسم بعد التطبيع (أو null). activeOnly: تجاهل الموقوفين. */
function farmersFindDuplicate_(name, excludeId, activeOnly) {
  const want = normText_(name);
  if (!want) return null;
  const rows = stTable_('farmers').rows;
  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
    if (excludeId && cellStr_(r['المعرّف']) === excludeId) continue;
    const inactive = enumToApi_('farmerStatus', r['الحالة'], 'active') !== 'active';
    if (activeOnly && inactive) continue;
    // صف أُلغي تعويضًا عن حفظ فاشل لا يمنع إعادة المحاولة.
    if (inactive && cellStr_(r['ملاحظات']).indexOf(RMN_CFG.compensationReason) >= 0) continue;
    if (normText_(r['الاسم']) === want) return r;
  }
  return null;
}

function farmersDuplicateError_(field, dup) {
  const f = farmerToApi_(dup);
  failValidation_(field,
    'يوجد مزارع مسجل بالاسم «' + f.name + '» (رقم ' + f.no + '). اختره من القائمة، أو أكّد أنه شخص مختلف لإضافته باسم مكرر.',
    { existing: f });
}

/** يضيف صف مزارع جديد ويعيد السجل (يُستخدم أيضًا من purchases.create). */
function farmersAppend_(fields) {
  const t = stTable_('farmers');
  const row = {
    'المعرّف': stNextId_(t, 'FR'),
    'رقم المزارع': stNextNumber_(t, 'رقم المزارع'),
    'الاسم': fields.name,
    'الهاتف': fields.phone || '',
    'القرية / المنطقة': fields.village || '',
    'ملاحظات': fields.notes || '',
    'الحالة': 'نشط',
    'تاريخ الإضافة': rqNow_(),
    'أضافه': userLabel_(rq_().user),
  };
  const rec = stAppend_(t, [row])[0];
  auditAdd_('إنشاء', 'مزارع', row['المعرّف'], 'إضافة المزارع «' + fields.name + '» برقم ' + row['رقم المزارع'], null, row, '');
  return rec;
}

// =====================================================================================
// الإجراءات
// =====================================================================================

/** farmers.list {query?, includeInactive?} */
function farmersListAction_(p) {
  stRequire_(['farmers']);
  const includeInactive = inBool_(p.includeInactive, 'includeInactive', 'إظهار الموقوفين', false);
  const q = normText_(p.query === undefined || p.query === null ? '' : String(p.query));
  const qDigits = q.replace(/\D/g, '');
  const list = stTable_('farmers').rows.map(farmerToApi_).filter(function (f) {
    if (!includeInactive && f.status !== 'active') return false;
    if (!q) return true;
    if (normText_(f.name).indexOf(q) >= 0) return true;
    if (normText_(f.village).indexOf(q) >= 0) return true;
    if (qDigits && qDigits === q && f.phone.replace(/\D/g, '').indexOf(qDigits) >= 0) return true;
    return String(f.no) === q;
  });
  list.sort(function (a, b) { return (a.no || 0) - (b.no || 0); });
  return { farmers: list };
}

/** farmers.create {name, phone?, village?, notes?, allowDuplicate?} */
function farmersCreateAction_(p) {
  stRequire_(['farmers', 'audit']);
  const name = inStr_(p.name, 'name', 'الاسم', { required: true, max: 80, hint: 'اكتب اسم المزارع ثم أعد المحاولة.' });
  const phone = farmersPhoneInput_(p.phone, 'phone');
  const village = inStr_(p.village, 'village', 'القرية / المنطقة', { max: 80 });
  const notes = inStr_(p.notes, 'notes', 'الملاحظات', { max: 1000, multiline: true });
  const allowDuplicate = inBool_(p.allowDuplicate, 'allowDuplicate', 'السماح بالاسم المكرر', false);
  const dup = farmersFindDuplicate_(name, null, false);
  if (dup && !allowDuplicate) farmersDuplicateError_('name', dup);
  const rec = farmersAppend_({ name: name, phone: phone, village: village, notes: notes });
  return { farmer: farmerToApi_(rec) };
}

/** farmers.update {id, expectedVersion, name?, phone?, village?, notes?, status?} */
function farmersUpdateAction_(p) {
  stRequire_(['farmers', 'audit']);
  const t = stTable_('farmers');
  const id = inId_(p.id, 'id', 'المزارع');
  const expected = inExpectedVersion_(p.expectedVersion);
  const rec = stFindById_(t, id);
  if (!rec) failNotFound_('id', 'المزارع', id);
  const current = farmerToApi_(rec);
  if (current.version !== expected) failConflict_('بيانات هذا المزارع', current.version, current);

  const c = {};
  if (p.name !== undefined) {
    const name = inStr_(p.name, 'name', 'الاسم', { required: true, max: 80, hint: 'اكتب اسم المزارع ثم أعد المحاولة.' });
    const allowDuplicate = inBool_(p.allowDuplicate, 'allowDuplicate', 'السماح بالاسم المكرر', false);
    const dup = farmersFindDuplicate_(name, id, false);
    if (dup && !allowDuplicate) farmersDuplicateError_('name', dup);
    c['الاسم'] = name;
  }
  if (p.phone !== undefined) c['الهاتف'] = farmersPhoneInput_(p.phone, 'phone');
  if (p.village !== undefined) c['القرية / المنطقة'] = inStr_(p.village, 'village', 'القرية / المنطقة', { max: 80 });
  if (p.notes !== undefined) c['ملاحظات'] = inStr_(p.notes, 'notes', 'الملاحظات', { max: 1000, multiline: true });
  if (p.status !== undefined) {
    const st = inEnum_(p.status, 'status', 'حالة المزارع', { active: 'نشط', inactive: 'موقوف' }, { required: true });
    c['الحالة'] = enumToSheet_('farmerStatus', st);
  }
  const diff = auditDiff_(rec, c);
  if (!diff.changed) return { farmer: current };
  const changes = {};
  Object.keys(diff.next).forEach(function (k) { changes[k] = c[k]; });
  stUpdate_(t, rec, changes);
  auditAdd_('تعديل', 'مزارع', id, 'تعديل بيانات المزارع «' + cellStr_(rec['الاسم']) + '»', diff.prev, diff.next, '');
  return { farmer: farmerToApi_(rec) };
}
