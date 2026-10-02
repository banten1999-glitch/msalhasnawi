/**
 * Packaging.gs — صفحتا «مشتريات التعبئة» و«تفاصيل التعبئة».
 *
 * - المسودة تُنشأ وتُعدَّل كاملة (العميل يرسل قائمة الأصناف كلها في كل حفظ).
 * - الكمية أو السعر الفارغ يبقى فارغًا (ليس صفرًا) ويجعل الصنف «غير مكتمل».
 * - الأصناف التي لم تعد في القائمة تُعلَّم «محذوف» ولا تُحذف.
 * - الاعتماد يتطلب صنفًا واحدًا على الأقل وكل الأصناف مكتملة. «تكلفة متأخرة» = نعم إن كان البراد مقفّلًا.
 */

const RMN_PACKAGING_STATUS_CHOICES = Object.freeze({ draft: 'مسودة', approved: 'معتمد', cancelled: 'ملغى', all: 'الكل' });
const RMN_PACKAGING_MAX_ITEMS = 200;
const RMN_ITEM_QTY_MAX = 10000000;
const RMN_ITEM_PRICE_MAX = 100000000;

/** إجماليات أصناف شراء تعبئة (غير المحذوفة) من فهرس الطلب (يُعاد بناؤه بعد كل كتابة). */
function packagingTotals_(packagingId) {
  const ix = dmIndex_();
  const want = cellStr_(packagingId);
  const s = ix.pk[want] || { itemsCount: 0, incompleteCount: 0, completeTotal: 0 };
  return {
    itemsCount: s.itemsCount,
    incompleteCount: s.incompleteCount,
    completeTotal: s.completeTotal,
    items: (ix.items[want] || []).slice(),
  };
}

function packagingItemToApi_(rec) {
  const f = dmItemFields_(rec);
  return {
    id: cellStr_(rec['المعرّف']),
    name: cellStr_(rec['الصنف']),
    quantity: f.quantity,
    unit: cellStr_(rec['الوحدة']),
    unitPricePiasters: f.unitPricePiasters,
    totalPiasters: f.totalPiasters,
    status: f.status,
    notes: cellStr_(rec['ملاحظات']),
    version: stVersion_(rec),
  };
}

/** صف شراء التعبئة → PackagingSummary (مع _t للترتيب). */
function packagingSummary_(rec) {
  const id = cellStr_(rec['المعرّف']);
  const tot = packagingTotals_(id);
  const status = enumToApi_('packagingStatus', rec['الحالة'], 'draft');
  const paid = dmIndex_().paid[id] || 0;
  const occurred = cellDate_(rec['تاريخ ووقت الشراء']);
  const created = cellDate_(rec['تاريخ الإنشاء']);
  const coolerId = cellStr_(rec['معرّف البراد']);
  const creator = dmWho_(rec['أنشأه']);
  return {
    id: id,
    no: cellStr_(rec['رقم الشراء']),
    supplier: cellStr_(rec['المورد']),
    invoiceNo: cellStr_(rec['رقم الفاتورة']),
    occurredAt: fmtIso_(occurred),
    coolerId: coolerId,
    coolerNo: coolerId ? dmCoolerNo_(coolerId, rec['رقم البراد']) : null,
    status: status,
    itemsCount: tot.itemsCount,
    incompleteCount: tot.incompleteCount,
    completeTotalPiasters: tot.completeTotal,
    paidPiasters: paid,
    remainingPiasters: status === 'approved' ? tot.completeTotal - paid : 0,
    late: cellBool_(rec['تكلفة متأخرة']),
    notes: cellStr_(rec['ملاحظات']),
    createdAt: fmtIso_(created),
    createdBy: creator.name,
    createdByEmail: creator.email,
    version: stVersion_(rec),
    _t: occurred || created,
  };
}

function packagingPublic_(rec) {
  return dmStripPrivate_(packagingSummary_(rec));
}

function packagingItemsPublic_(rec) {
  return packagingTotals_(rec['المعرّف']).items.map(packagingItemToApi_);
}

/** {packaging, items} كما ترجعها إجراءات الحفظ والاعتماد. */
function packagingBundle_(rec) {
  return { packaging: packagingPublic_(rec), items: packagingItemsPublic_(rec) };
}

/** الأعمدة المخزنة (العدد، غير المكتمل، الإجمالي، المدفوع، المتبقي). */
function packagingCacheColumns_(rec) {
  const id = cellStr_(rec['المعرّف']);
  const tot = packagingTotals_(id);
  const status = enumToApi_('packagingStatus', rec['الحالة'], 'draft');
  const paid = dmActivePaid_(id);
  return {
    'عدد العناصر': tot.itemsCount,
    'عناصر غير مكتملة': tot.incompleteCount,
    'إجمالي العناصر المكتملة (ج.م)': toEgp_(tot.completeTotal),
    'المدفوع (ج.م)': toEgp_(paid),
    'المتبقي (ج.م)': toEgp_(status === 'approved' ? tot.completeTotal - paid : 0),
  };
}

/** يعيد كتابة الأعمدة المخزنة إن اختلفت. كل كتابة تزيد «الإصدار» وتضع «آخر تعديل» (العقد §7). */
function packagingSyncCache_(rec, opts) {
  const c = packagingCacheColumns_(rec);
  const diff = auditDiff_(rec, c);
  if (!diff.changed) return false;
  stUpdate_(stTable_('packaging'), rec, c, opts || {});
  return true;
}

function packagingMustFind_(id, field) {
  const rec = stFindById_(stTable_('packaging'), id);
  if (!rec) failNotFound_(field || 'id', 'شراء التعبئة', id);
  return rec;
}

function packagingLabel_(rec) {
  const no = cellStr_(rec['رقم الشراء']);
  const supplier = cellStr_(rec['المورد']);
  return 'شراء التعبئة ' + no + (supplier ? ' من «' + supplier + '»' : '');
}

/** يتحقق من قائمة الأصناف كاملة قبل أي كتابة. يعيد [{id, name, quantity, unit, price, notes}]. */
function packagingItemsIn_(items, packagingId) {
  if (!Array.isArray(items)) {
    failValidation_('items', '«الأصناف» مطلوبة كقائمة. أضف الأصناف ثم احفظ.');
  }
  if (items.length > RMN_PACKAGING_MAX_ITEMS) {
    failValidation_('items', 'عدد الأصناف أكثر من ' + RMN_PACKAGING_MAX_ITEMS + '. قسّم الشراء إلى أكثر من فاتورة.',
      { max: RMN_PACKAGING_MAX_ITEMS });
  }
  const it = stTable_('packaging_items');
  const seen = {};
  return items.map(function (x, i) {
    const f = 'items[' + i + ']';
    const n = i + 1;
    if (!isPlainObject_(x)) failValidation_(f, 'الصنف رقم ' + n + ' غير صالح. احذفه وأضفه من جديد.', { index: i });
    let id = '';
    if (inPresent_(x.id)) {
      id = inStr_(x.id, f + '.id', 'معرّف الصنف رقم ' + n, { max: 64 });
      const rec = stFindById_(it, id);
      if (!rec || !packagingId || cellStr_(rec['معرّف الشراء']) !== packagingId) {
        failValidation_(f + '.id', 'الصنف رقم ' + n + ' لا يتبع هذا الشراء. حدّث البيانات ثم أعد الحفظ.', { index: i, id: id });
      }
      if (seen[id]) failValidation_(f + '.id', 'الصنف رقم ' + n + ' مكرر في القائمة. احذف التكرار ثم احفظ.', { index: i, id: id });
      seen[id] = true;
    }
    const name = inStr_(x.name, f + '.name', 'اسم الصنف رقم ' + n, { required: true, max: 80 });
    const unit = inStr_(x.unit, f + '.unit', 'وحدة الصنف رقم ' + n, { required: true, max: 20, hint: 'اختر الوحدة من القائمة.' });
    if (RMN_UNITS.indexOf(unit) < 0) {
      failValidation_(f + '.unit', 'وحدة الصنف رقم ' + n + ' («' + unit + '») غير معروفة. اختر واحدة من: ' + RMN_UNITS.join('، ') + '.',
        { index: i, allowed: RMN_UNITS.slice() });
    }
    const quantity = inInt_(x.quantity, f + '.quantity', 'كمية الصنف رقم ' + n, { min: 1, max: RMN_ITEM_QTY_MAX });
    const price = inInt_(x.unitPricePiasters, f + '.unitPricePiasters', 'سعر الوحدة للصنف رقم ' + n, {
      min: 1, max: RMN_ITEM_PRICE_MAX, fmt: fmtMoneyMsg_,
    });
    const notes = inStr_(x.notes, f + '.notes', 'ملاحظات الصنف رقم ' + n, { max: 500, multiline: true });
    return { id: id, name: name, unit: unit, quantity: quantity, price: price, notes: notes };
  });
}

/** أعمدة صف الصنف من المدخلات. */
function packagingItemColumns_(x) {
  const complete = x.quantity !== null && x.price !== null;
  return {
    'الصنف': x.name,
    'الكمية': x.quantity === null ? '' : x.quantity,
    'الوحدة': x.unit,
    'السعر المفرد (ج.م)': x.price === null ? '' : toEgp_(x.price),
    'الإجمالي (ج.م)': complete ? toEgp_(x.quantity * x.price) : '',
    'الحالة': complete ? 'مكتمل' : 'غير مكتمل',
    'ملاحظات': x.notes,
  };
}

// =====================================================================================
// الإجراءات
// =====================================================================================

/** packaging.list {status?, coolerId?} — الأحدث أولًا. */
function packagingListAction_(p) {
  dmIndex_();
  const status = inEnum_(p.status, 'status', 'حالة شراء التعبئة', RMN_PACKAGING_STATUS_CHOICES) || 'all';
  const coolerId = inStr_(p.coolerId, 'coolerId', 'البراد', { max: 64 });
  const list = stTable_('packaging').rows.filter(function (r) {
    if (coolerId && cellStr_(r['معرّف البراد']) !== coolerId) return false;
    return status === 'all' || enumToApi_('packagingStatus', r['الحالة'], 'draft') === status;
  }).map(packagingSummary_);
  list.sort(dmByTimeDesc_(function (x) { return x._t; }, function (x) { return x.id; }));
  return { packaging: list.map(dmStripPrivate_) };
}

/** packaging.get {id} → {packaging, items} */
function packagingGetAction_(p) {
  dmIndex_();
  const id = inId_(p.id, 'id', 'شراء التعبئة');
  return packagingBundle_(packagingMustFind_(id, 'id'));
}

/** packaging.save — ينشئ مسودة أو يعدّلها. الإنشاء idempotent على requestId. */
function packagingSaveAction_(p, user, req) {
  stRequire_(stDataKeys_().concat(['audit']));
  const pt = stTable_('packaging');
  const it = stTable_('packaging_items');
  const id = inStr_(p.id, 'id', 'شراء التعبئة', { max: 64 });

  let rec = null;
  if (!id) {
    const replay = stFindByKey_(pt, req.requestId);
    if (replay) return Object.assign(packagingBundle_(replay), { replayed: true });
  } else {
    rec = packagingMustFind_(id, 'id');
    const status = enumToApi_('packagingStatus', rec['الحالة'], 'draft');
    if (status !== 'draft') {
      failValidation_('id', packagingLabel_(rec) + (status === 'approved'
        ? ' معتمد، فلا يمكن تعديله. ألغِه وسجّل شراءً جديدًا إن لزم التصحيح.'
        : ' ملغى، فلا يمكن تعديله. سجّل شراءً جديدًا.'));
    }
    const expected = inExpectedVersion_(p.expectedVersion);
    if (stVersion_(rec) !== expected) {
      throw apiError_('CONFLICT', 'عدّل مستخدم آخر ' + packagingLabel_(rec) + ' بعد أن فتحته. راجع البيانات الحالية ثم أعد الحفظ.',
        'expectedVersion', { currentVersion: stVersion_(rec), current: packagingPublic_(rec), items: packagingItemsPublic_(rec) });
    }
  }

  const keep = function (v, col) { return v === undefined ? (rec ? cellStr_(rec[col]) : '') : null; };
  let supplier = keep(p.supplier, 'المورد');
  if (supplier === null) supplier = inStr_(p.supplier, 'supplier', 'اسم المورد', { max: 80 });
  let invoiceNo = keep(p.invoiceNo, 'رقم الفاتورة');
  if (invoiceNo === null) invoiceNo = inStr_(p.invoiceNo, 'invoiceNo', 'رقم الفاتورة', { max: 40 });
  let notes = keep(p.notes, 'ملاحظات');
  if (notes === null) notes = inStr_(p.notes, 'notes', 'الملاحظات', { max: 1000, multiline: true });
  let coolerId = keep(p.coolerId, 'معرّف البراد');
  let coolerNo = rec ? cellInt_(rec['رقم البراد']) : null;
  if (coolerId === null) {
    coolerId = inStr_(p.coolerId, 'coolerId', 'البراد', { max: 64 });
    coolerNo = null;
    if (coolerId) coolerNo = cellInt_(coolersMustFind_(coolerId, 'coolerId')['رقم البراد']);
  }
  let occurredAt = inTime_(p.occurredAt, 'occurredAt', 'تاريخ ووقت الشراء');
  if (!occurredAt) occurredAt = rec ? (cellDate_(rec['تاريخ ووقت الشراء']) || rqNow_()) : rqNow_();
  const items = packagingItemsIn_(p.items, id);

  // الكتابة
  const now = rqNow_();
  if (!rec) {
    const newId = stNextId_(pt, 'PK');
    const no = seqFormat_('P', stNextSeq_(pt, 'رقم الشراء', 'P'));
    let complete = 0;
    let incomplete = 0;
    items.forEach(function (x) {
      if (x.quantity !== null && x.price !== null) complete += x.quantity * x.price;
      else incomplete++;
    });
    const row = {
      'المعرّف': newId,
      'رقم الشراء': no,
      'المورد': supplier,
      'رقم الفاتورة': invoiceNo,
      'تاريخ ووقت الشراء': occurredAt,
      'معرّف البراد': coolerId,
      'رقم البراد': coolerNo === null ? '' : coolerNo,
      'الحالة': 'مسودة',
      'عدد العناصر': items.length,
      'عناصر غير مكتملة': incomplete,
      'إجمالي العناصر المكتملة (ج.م)': toEgp_(complete),
      'المدفوع (ج.م)': 0,
      'المتبقي (ج.م)': 0,
      'تكلفة متأخرة': 'لا',
      'ملاحظات': notes,
      'تاريخ الإنشاء': now,
      'أنشأه': userLabel_(user),
      'مفتاح عدم التكرار': req.requestId,
    };
    rec = stAppend_(pt, [row])[0];
    if (items.length) {
      let seq = stNextSeq_(it, 'المعرّف', 'PD');
      stAppend_(it, items.map(function (x) {
        return Object.assign({
          'المعرّف': seqFormat_('PD', seq++),
          'معرّف الشراء': newId,
          'رقم الشراء': no,
        }, packagingItemColumns_(x));
      }));
    }
    auditAdd_('إنشاء', 'شراء تعبئة', newId, 'إنشاء مسودة ' + packagingLabel_(rec) + ' بعدد ' + items.length + ' صنف', null,
      Object.assign({}, row, { items: items }), '');
    return Object.assign(packagingBundle_(rec), { replayed: false });
  }

  // تعديل مسودة قائمة
  const pid = cellStr_(rec['المعرّف']);
  const no = cellStr_(rec['رقم الشراء']);
  const before = packagingPublic_(rec);
  const beforeItems = packagingItemsPublic_(rec);
  const listed = {};
  items.forEach(function (x) { if (x.id) listed[x.id] = true; });
  const existing = packagingTotals_(pid).items;
  let touched = false;
  existing.forEach(function (r) {
    const rid = cellStr_(r['المعرّف']);
    if (!listed[rid]) {
      stUpdate_(it, r, { 'الحالة': 'محذوف' });
      touched = true;
    }
  });
  const fresh = [];
  items.forEach(function (x) {
    if (!x.id) { fresh.push(x); return; }
    const r = stFindById_(it, x.id);
    const c = packagingItemColumns_(x);
    const d = auditDiff_(r, c);
    if (d.changed) {
      const changes = {};
      Object.keys(d.next).forEach(function (k) { changes[k] = c[k]; });
      stUpdate_(it, r, changes);
      touched = true;
    }
  });
  if (fresh.length) {
    let seq = stNextSeq_(it, 'المعرّف', 'PD');
    stAppend_(it, fresh.map(function (x) {
      return Object.assign({ 'المعرّف': seqFormat_('PD', seq++), 'معرّف الشراء': pid, 'رقم الشراء': no }, packagingItemColumns_(x));
    }));
    touched = true;
  }
  const c = Object.assign({
    'المورد': supplier,
    'رقم الفاتورة': invoiceNo,
    'تاريخ ووقت الشراء': occurredAt,
    'معرّف البراد': coolerId,
    'رقم البراد': coolerNo === null ? '' : coolerNo,
    'ملاحظات': notes,
  }, packagingCacheColumns_(rec));
  const diff = auditDiff_(rec, c);
  if (!diff.changed && !touched) return Object.assign(packagingBundle_(rec), { replayed: false });
  const changes = {};
  Object.keys(c).forEach(function (k) { changes[k] = c[k]; });
  stUpdate_(pt, rec, changes);
  auditAdd_('تعديل', 'شراء تعبئة', pid, 'تعديل مسودة ' + packagingLabel_(rec),
    { packaging: before, items: beforeItems }, { packaging: packagingPublic_(rec), items: packagingItemsPublic_(rec) }, '');
  return Object.assign(packagingBundle_(rec), { replayed: false });
}

/** packaging.approve {id, expectedVersion} */
function packagingApproveAction_(p) {
  stRequire_(stDataKeys_().concat(['audit']));
  const pt = stTable_('packaging');
  const id = inId_(p.id, 'id', 'شراء التعبئة');
  const rec = packagingMustFind_(id, 'id');
  const status = enumToApi_('packagingStatus', rec['الحالة'], 'draft');
  if (status === 'approved') failValidation_('id', packagingLabel_(rec) + ' معتمد بالفعل. لا حاجة لاعتماده مرة أخرى.');
  if (status === 'cancelled') failValidation_('id', packagingLabel_(rec) + ' ملغى، فلا يمكن اعتماده. سجّل شراءً جديدًا.');
  const expected = inExpectedVersion_(p.expectedVersion);
  if (stVersion_(rec) !== expected) {
    throw apiError_('CONFLICT', 'عدّل مستخدم آخر ' + packagingLabel_(rec) + ' بعد أن فتحته. راجع البيانات الحالية ثم أعد الاعتماد.',
      'expectedVersion', { currentVersion: stVersion_(rec), current: packagingPublic_(rec), items: packagingItemsPublic_(rec) });
  }
  const tot = packagingTotals_(id);
  if (tot.itemsCount === 0) {
    failValidation_('items', 'لا يمكن اعتماد ' + packagingLabel_(rec) + ' بدون أصناف. أضف صنفًا واحدًا على الأقل ثم اعتمد.');
  }
  if (tot.incompleteCount > 0) {
    const names = tot.items.filter(function (r) { return dmItemFields_(r).status !== 'complete'; })
      .map(function (r) { return cellStr_(r['الصنف']); });
    failValidation_('items', 'لا يمكن الاعتماد: ' + tot.incompleteCount + ' صنف غير مكتمل (' + names.join('، ') +
      '). أكمل الكمية والسعر لكل صنف ثم اعتمد.', {
      incomplete: tot.items.filter(function (r) { return dmItemFields_(r).status !== 'complete'; })
        .map(function (r) { return cellStr_(r['المعرّف']); }),
    });
  }
  const coolerId = cellStr_(rec['معرّف البراد']);
  const cooler = coolerId ? stFindById_(stTable_('coolers'), coolerId) : null;
  const late = !!(cooler && coolerIsClosed_(cooler));
  const c = { 'الحالة': 'معتمد', 'تكلفة متأخرة': yesNo_(late) };
  stUpdate_(pt, rec, Object.assign(c, packagingCacheColumns_(Object.assign({}, rec, { 'الحالة': 'معتمد' }))));
  auditAdd_('تعديل', 'شراء تعبئة', id, 'اعتماد ' + packagingLabel_(rec) + ' بإجمالي ' + fmtMoneyMsg_(tot.completeTotal) +
    (late ? ' (تكلفة متأخرة: البراد ' + cellInt_(cooler['رقم البراد']) + ' مقفّل)' : ''),
    { status: 'draft' }, { status: 'approved', completeTotalPiasters: tot.completeTotal, late: late }, '');
  return packagingBundle_(rec);
}

/** packaging.cancel {id, reason} */
function packagingCancelAction_(p) {
  stRequire_(stDataKeys_().concat(['audit']));
  const pt = stTable_('packaging');
  const id = inId_(p.id, 'id', 'شراء التعبئة');
  const reason = inReason_(p.reason, 'لإلغاء شراء التعبئة');
  const rec = packagingMustFind_(id, 'id');
  const status = enumToApi_('packagingStatus', rec['الحالة'], 'draft');
  if (status === 'cancelled') failValidation_('id', packagingLabel_(rec) + ' ملغى بالفعل. لا حاجة لإلغائه مرة أخرى.');
  if (inPresent_(p.expectedVersion)) {
    const expected = inExpectedVersion_(p.expectedVersion);
    if (stVersion_(rec) !== expected) failConflict_(packagingLabel_(rec), stVersion_(rec), packagingPublic_(rec));
  }
  const count = dmActivePaymentsCount_(id);
  if (count > 0) {
    failValidation_('id', 'على ' + packagingLabel_(rec) + ' ' + count + ' دفعة فعّالة بمبلغ ' + fmtMoneyMsg_(dmActivePaid_(id)) +
      '. ألغِ الدفعات أولًا ثم ألغِ الشراء.', { activePayments: count });
  }
  stUpdate_(pt, rec, {
    'الحالة': 'ملغى',
    'المتبقي (ج.م)': 0,
    'ملاحظات': appendNote_(rec['ملاحظات'], 'سبب الإلغاء: ' + reason),
  });
  auditAdd_('إلغاء', 'شراء تعبئة', id, 'إلغاء ' + packagingLabel_(rec), { status: status }, { status: 'cancelled' }, reason);
  return { packaging: packagingPublic_(rec) };
}
