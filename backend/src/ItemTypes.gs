/**
 * ItemTypes.gs — صفحة «أصناف التعبئة»: قائمة الأصناف ووحداتها الافتراضية وترتيبها.
 * الصفحة بلا عمود إصدار، فالحفظ لا يتطلب expectedVersion.
 */

function itemTypeToApi_(rec) {
  return {
    id: cellStr_(rec['المعرّف']),
    name: cellStr_(rec['الصنف']),
    unit: cellStr_(rec['الوحدة الافتراضية']),
    order: cellInt_(rec['الترتيب']),
    active: rec['نشط'] === '' || rec['نشط'] === null || rec['نشط'] === undefined ? true : cellBool_(rec['نشط']),
  };
}

/** itemTypes.list → {itemTypes} مرتبة حسب «الترتيب» ثم الاسم. */
function itemTypesListAction_() {
  stRequire_(['item_types']);
  const list = stTable_('item_types').rows.map(itemTypeToApi_);
  list.sort(function (a, b) {
    const oa = a.order === null ? 1e9 : a.order;
    const ob = b.order === null ? 1e9 : b.order;
    if (oa !== ob) return oa - ob;
    return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0);
  });
  return { itemTypes: list };
}

/** itemTypes.save {id?, name, unit, order?, active?} → {itemType} */
function itemTypesSaveAction_(p) {
  stRequire_(['item_types', 'audit']);
  const t = stTable_('item_types');
  const id = inStr_(p.id, 'id', 'الصنف', { max: 64 });
  const rec = id ? stFindById_(t, id) : null;
  if (id && !rec) failNotFound_('id', 'صنف التعبئة', id);

  const name = inStr_(p.name, 'name', 'اسم الصنف', { required: true, max: 60 });
  const unit = inStr_(p.unit, 'unit', 'الوحدة الافتراضية', { required: true, max: 20, hint: 'اختر الوحدة من القائمة.' });
  if (RMN_UNITS.indexOf(unit) < 0) {
    failValidation_('unit', 'الوحدة «' + unit + '» غير معروفة. اختر واحدة من: ' + RMN_UNITS.join('، ') + '.',
      { allowed: RMN_UNITS.slice() });
  }
  const want = normText_(name);
  const dup = t.rows.filter(function (r) {
    return r !== rec && normText_(r['الصنف']) === want;
  })[0];
  if (dup) {
    failValidation_('name', 'يوجد صنف بالاسم «' + cellStr_(dup['الصنف']) + '» بالفعل' +
      (cellBool_(dup['نشط']) ? '' : ' (غير نشط، يمكنك تفعيله بدل إضافته)') + '. اختر اسمًا مختلفًا.',
      { existing: itemTypeToApi_(dup) });
  }
  let order = inInt_(p.order, 'order', 'الترتيب', { min: 1, max: 100000 });
  if (order === null) order = rec ? cellInt_(rec['الترتيب']) : stNextNumber_(t, 'الترتيب');
  const active = inBool_(p.active, 'active', 'نشط', rec ? itemTypeToApi_(rec).active : true);

  const c = {
    'الصنف': name,
    'الوحدة الافتراضية': unit,
    'الترتيب': order === null ? '' : order,
    'نشط': yesNo_(active),
  };
  if (!rec) {
    const row = Object.assign({ 'المعرّف': stNextId_(t, 'IT') }, c);
    const created = stAppend_(t, [row])[0];
    auditAdd_('إنشاء', 'إعدادات', row['المعرّف'], 'إضافة صنف التعبئة «' + name + '» بوحدة ' + unit, null, row, '');
    return { itemType: itemTypeToApi_(created) };
  }
  const diff = auditDiff_(rec, c);
  if (!diff.changed) return { itemType: itemTypeToApi_(rec) };
  const changes = {};
  Object.keys(diff.next).forEach(function (k) { changes[k] = c[k]; });
  stUpdate_(t, rec, changes);
  auditAdd_('تعديل', 'إعدادات', id, 'تعديل صنف التعبئة «' + name + '»', diff.prev, diff.next, '');
  return { itemType: itemTypeToApi_(rec) };
}
