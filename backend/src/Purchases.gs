/**
 * Purchases.gs — صفحة «مشتريات الرمان».
 *
 * الحساب (العقد §5) بأعداد صحيحة فقط:
 *   totalWeightGrams = boxes × avgWeightGrams
 *   valuePiasters    = round_half_up(totalWeightGrams × pricePerKgPiasters / 1000)
 * الصفحة تُكتب بالوحدات البشرية (كغ، ج.م). أعمدة المدفوع/المتبقي/حالة الدفع نسخة مخزنة تُعاد
 * حسابها من الدفعات الفعّالة مع كل كتابة.
 */

const RMN_WEIGHT_METHODS = Object.freeze({ direct: 'مباشر', sample: 'عينة' });
const RMN_PAY_METHODS = Object.freeze({ cash: 'نقدًا', bank: 'تحويل بنكي', wallet: 'محفظة إلكترونية' });
const RMN_PAY_MODES = Object.freeze({ full: 'دفع كامل', partial: 'دفع جزئي', none: 'بدون دفع' });

const RMN_LIMITS = Object.freeze({
  boxesMax: 100000,
  avgWeightMax: 60000,
  priceMax: 100000,
  sampleMaxCount: 200,
  sampleWeightMax: 100000,
  tareMax: 60000,
  amountMax: 1000000000000,
});

// =====================================================================================
// القراءة
// =====================================================================================

/** القياسات المخزنة للعملية (القيم المخزنة أولًا، وإلا تُحسب من المدخلات). */
function purchaseMeasures_(rec) {
  const boxes = cellInt_(rec['عدد الصناديق']) || 0;
  const avg = cellGrams_(rec['متوسط وزن الصندوق (كغ)']) || 0;
  const price = cellMoney_(rec['سعر الكيلو (ج.م)']) || 0;
  const calc = purchaseMath_(boxes, avg, price);
  const total = cellGrams_(rec['إجمالي الوزن (كغ)']);
  const value = cellMoney_(rec['إجمالي السعر (ج.م)']);
  return {
    boxes: boxes,
    avgWeightGrams: avg,
    pricePerKgPiasters: price,
    totalWeightGrams: total === null ? calc.totalWeightGrams : total,
    valuePiasters: value === null ? calc.valuePiasters : value,
  };
}

function purchaseIsActive_(rec) {
  return enumToApi_('recordStatus', rec['الحالة'], 'active') === 'active';
}

/** صف الشراء → كائن Purchase (مع _t للترتيب). */
function purchaseToApi_(rec) {
  const ix = dmIndex_();
  const id = cellStr_(rec['المعرّف']);
  const m = purchaseMeasures_(rec);
  const status = enumToApi_('recordStatus', rec['الحالة'], 'active');
  const paid = ix.paid[id] || 0;
  const method = enumToApi_('weightMethod', rec['طريقة حساب الوزن'], 'direct');
  const occurred = cellDate_(rec['تاريخ ووقت العملية']);
  const created = cellDate_(rec['تاريخ الإنشاء الفعلي']);
  const coolerId = cellStr_(rec['معرّف البراد']);
  const farmerId = cellStr_(rec['معرّف المزارع']);
  const creator = dmWho_(rec['أنشأها']);
  const editor = dmWho_(rec['عدّلها']);
  return {
    id: id,
    coolerId: coolerId,
    coolerNo: dmCoolerNo_(coolerId, rec['رقم البراد']),
    farmerId: farmerId,
    farmerName: dmFarmerName_(farmerId, rec['اسم المزارع']),
    occurredAt: fmtIso_(occurred),
    boxes: m.boxes,
    avgWeightGrams: m.avgWeightGrams,
    weightMethod: method,
    sampleWeightsGrams: method === 'sample' ? samplesParse_(rec['أوزان العينة (كغ)']) : [],
    tareGrams: method === 'sample' ? cellGrams_(rec['وزن الصندوق الفارغ (كغ)']) : null,
    totalWeightGrams: m.totalWeightGrams,
    pricePerKgPiasters: m.pricePerKgPiasters,
    valuePiasters: m.valuePiasters,
    paidPiasters: paid,
    remainingPiasters: status === 'active' ? m.valuePiasters - paid : 0,
    payStatus: payStatusOf_(m.valuePiasters, paid),
    status: status,
    cancelReason: cellStr_(rec['سبب الإلغاء']),
    notes: cellStr_(rec['ملاحظات']),
    createdAt: fmtIso_(created),
    createdBy: creator.name,
    createdByEmail: creator.email,
    updatedAt: cellIso_(rec['آخر تعديل']),
    updatedBy: editor.name,
    version: stVersion_(rec),
    _t: occurred || created,
  };
}

function purchasePublic_(rec) {
  return dmStripPrivate_(purchaseToApi_(rec));
}

/** أعمدة المدفوع/المتبقي/حالة الدفع المخزنة، محسوبة من الدفعات الفعّالة. */
function purchasesCacheColumns_(rec) {
  const m = purchaseMeasures_(rec);
  const paid = dmActivePaid_(rec['المعرّف']);
  const active = purchaseIsActive_(rec);
  return {
    'المدفوع (ج.م)': toEgp_(paid),
    'المتبقي (ج.م)': toEgp_(active ? m.valuePiasters - paid : 0),
    'حالة الدفع': enumToSheet_('payStatus', payStatusOf_(m.valuePiasters, paid)),
  };
}

/**
 * يعيد كتابة الأعمدة المخزنة (المدفوع/المتبقي/حالة الدفع) إن اختلفت.
 * العقد §7: كل كتابة على الصف تزيد «الإصدار» وتضع «آخر تعديل/عدّلها»، فتسجيل دفعة أو إلغاؤها
 * يغيّر إصدار العملية أيضًا (والرد يعيد العملية المحدّثة في target).
 */
function purchasesSyncCache_(rec, opts) {
  const c = purchasesCacheColumns_(rec);
  const diff = auditDiff_(rec, c);
  if (!diff.changed) return false;
  stUpdate_(stTable_('purchases'), rec, c, opts || {});
  return true;
}

function purchasesMustFind_(id, field) {
  const rec = stFindById_(stTable_('purchases'), id);
  if (!rec) failNotFound_(field || 'id', 'عملية الشراء', id);
  return rec;
}

/** يتحقق أن المستخدم أنشأ العملية، وإلا يطلب صلاحية «تعديل عمليات الآخرين». */
function purchasesRequireOwnerOrEditOthers_(user, rec) {
  const creator = labelEmail_(rec['أنشأها']);
  if (creator && user && creator === String(user.email || '').toLowerCase()) return;
  requirePermission(user, 'editOthers');
}

// =====================================================================================
// التحقق من المدخلات
// =====================================================================================

function purchasesBoxesIn_(v, field) {
  return inInt_(v, field, 'عدد الصناديق', { required: true, min: 1, max: RMN_LIMITS.boxesMax });
}

function purchasesAvgIn_(v, field) {
  return inInt_(v, field, 'متوسط الوزن الصافي للصندوق', { required: true, min: 1, max: RMN_LIMITS.avgWeightMax, fmt: fmtKgMsg_ });
}

function purchasesPriceIn_(v, field) {
  return inInt_(v, field, 'سعر الكيلو', { required: true, min: 1, max: RMN_LIMITS.priceMax, fmt: fmtMoneyMsg_ });
}

/** أوزان العينة: 1 إلى 200 وزن صحيح بالغرام، كل وزن > 0. */
function purchasesSamplesIn_(v, field) {
  if (!Array.isArray(v) || v.length === 0) {
    failValidation_(field, '«أوزان العينة» مطلوبة عند اختيار طريقة العينة. أدخل وزن صندوق واحد على الأقل.');
  }
  if (v.length > RMN_LIMITS.sampleMaxCount) {
    failValidation_(field, '«أوزان العينة» أكثر من ' + RMN_LIMITS.sampleMaxCount + ' وزنًا. قلّل عدد الصناديق في العينة.',
      { max: RMN_LIMITS.sampleMaxCount });
  }
  return v.map(function (x, i) {
    return inInt_(x, field, 'وزن الصندوق رقم ' + (i + 1) + ' في العينة', {
      required: true, min: 1, max: RMN_LIMITS.sampleWeightMax, fmt: fmtKgMsg_,
    });
  });
}

function purchasesTareIn_(v, field, fallback) {
  const n = inInt_(v, field, 'وزن الصندوق الفارغ', { min: 0, max: RMN_LIMITS.tareMax, fmt: fmtKgMsg_ });
  return n === null ? fallback : n;
}

/** يتحقق من أن متوسط الوزن = round(متوسط العينة − الفارغ) بفرق غرام واحد على الأكثر. */
function purchasesCheckSample_(avg, samples, tare, avgField, samplesField) {
  const expected = sampleNetAverage_(samples, tare);
  if (expected <= 0) {
    failValidation_(samplesField, 'متوسط أوزان العينة (' + fmtKgMsg_(sampleNetAverage_(samples, 0)) +
      ') لا يزيد على وزن الصندوق الفارغ (' + fmtKgMsg_(tare) + '). راجع أوزان العينة أو وزن الصندوق الفارغ.');
  }
  if (Math.abs(avg - expected) > 1) {
    failValidation_(avgField, '«متوسط الوزن الصافي للصندوق» (' + fmtKgMsg_(avg) + ') لا يطابق العينة. المتوسط الصافي المحسوب من العينة هو ' +
      fmtKgMsg_(expected) + '. أعد حساب المتوسط ثم احفظ.', { expectedGrams: expected });
  }
}

/** المزارع المختار (موجود ونشط). */
function purchasesFarmerFor_(farmerId, field) {
  const rec = stFindById_(stTable_('farmers'), farmerId);
  if (!rec) failNotFound_(field, 'المزارع', farmerId);
  if (enumToApi_('farmerStatus', rec['الحالة'], 'active') !== 'active') {
    failValidation_(field, 'المزارع «' + cellStr_(rec['الاسم']) + '» موقوف. اختر مزارعًا آخر، أو اطلب تفعيله من صفحة المزارعين.');
  }
  return rec;
}

function purchasesDescribe_(farmerName, coolerNo, boxes, avg, total, price, value) {
  return 'شراء من «' + farmerName + '» في البراد ' + coolerNo + ': ' + boxes + ' صندوق × ' + fmtKgMsg_(avg) +
    ' = ' + fmtKgMsg_(total) + ' × ' + fmtMoneyMsg_(price) + ' = ' + fmtMoneyMsg_(value);
}

// =====================================================================================
// الإجراءات
// =====================================================================================

/** purchases.list {coolerId?, farmerId?, from?, to?, includeCancelled?} — الأحدث أولًا. */
function purchasesListAction_(p) {
  dmIndex_();
  const coolerId = inStr_(p.coolerId, 'coolerId', 'البراد', { max: 64 });
  const farmerId = inStr_(p.farmerId, 'farmerId', 'المزارع', { max: 64 });
  const range = purchasesRangeIn_(p.from, p.to);
  const includeCancelled = inBool_(p.includeCancelled, 'includeCancelled', 'إظهار العمليات الملغاة', false);
  const list = stTable_('purchases').rows.filter(function (r) {
    if (coolerId && cellStr_(r['معرّف البراد']) !== coolerId) return false;
    if (farmerId && cellStr_(r['معرّف المزارع']) !== farmerId) return false;
    if (!includeCancelled && !purchaseIsActive_(r)) return false;
    return true;
  }).map(purchaseToApi_).filter(function (x) {
    return dmInRange_(x._t, range);
  });
  list.sort(dmByTimeDesc_(function (x) { return x._t; }, function (x) { return x.id; }));
  return { purchases: list.map(dmStripPrivate_) };
}

/** from/to: تاريخ ووقت ISO أو تاريخ فقط (yyyy-MM-dd ⇒ بداية اليوم / نهايته). */
function purchasesRangeIn_(from, to) {
  const tz = rqTzSafe_();
  const parse = function (v, field, label, end) {
    if (!inPresent_(v)) return null;
    const s = typeof v === 'string' ? v : '';
    const d = parseDateText_(s, tz);
    if (!d) failValidation_(field, '«' + label + '» بتنسيق غير صحيح. أرسل التاريخ مثل 2026-10-02 أو 2026-10-02T06:40:00+03:00.');
    if (isDateOnlyText_(s)) return end ? endOfLocalDay_(d, tz) : startOfLocalDay_(d, tz);
    return d;
  };
  const range = { from: parse(from, 'from', 'من تاريخ', false), to: parse(to, 'to', 'إلى تاريخ', true) };
  if (range.from && range.to && range.from.getTime() > range.to.getTime()) {
    failValidation_('to', '«إلى تاريخ» قبل «من تاريخ». صحّح الفترة ثم أعد المحاولة.');
  }
  return range;
}

/**
 * purchases.create — العقد §6. idempotent على requestId (مفتاح عدم التكرار).
 * يتحقق من كل شيء أولًا، ثم يكتب: المزارع الجديد (إن وُجد) ← الشراء ← الدفعة.
 */
function purchasesCreateAction_(p, user, req) {
  stRequire_(stDataKeys_().concat(['settings', 'audit']));
  const pt = stTable_('purchases');
  const payt = stTable_('payments');

  const replay = stFindByKey_(pt, req.requestId);
  if (replay) return purchasesReplay_(replay, req.requestId);

  // شكل الطلب والصلاحيات الإضافية
  const hasFarmerId = inPresent_(p.farmerId);
  const hasNewName = inPresent_(p.newFarmerName);
  if (hasFarmerId && hasNewName) {
    failValidation_('farmerId', 'اختر مزارعًا من القائمة أو اكتب اسم مزارع جديد، وليس الاثنين معًا.');
  }
  if (!hasFarmerId && !hasNewName) {
    failValidation_('farmerId', '«المزارع» مطلوب. اختره من القائمة أو اكتب اسم مزارع جديد.');
  }
  // payment مطلوب في العقد §6 (ليس اختياريًا)، حتى لا يضيع اختيار «دفع كامل» بسبب خطأ في التطبيق.
  const pay = p.payment;
  if (!isPlainObject_(pay)) {
    failValidation_('payment', '«الدفع مع الشراء» مطلوب. اختر «دفع كامل» أو «دفع جزئي» أو «بدون دفع» ثم أعد المحاولة.');
  }
  const mode = inEnum_(pay.mode, 'payment.mode', 'طريقة الدفع مع الشراء', RMN_PAY_MODES, { required: true });
  if (hasNewName) requirePermission(user, 'addFarmers');
  if (mode !== 'none') requirePermission(user, 'recordPayments');

  // البراد
  const coolerId = inId_(p.coolerId, 'coolerId', 'البراد');
  const cooler = coolersMustFind_(coolerId, 'coolerId');
  if (coolerIsClosed_(cooler)) throw coolerClosedError_(cooler);

  // المزارع
  let farmer = null;
  let newFarmerName = '';
  if (hasFarmerId) {
    farmer = purchasesFarmerFor_(inId_(p.farmerId, 'farmerId', 'المزارع'), 'farmerId');
  } else {
    newFarmerName = inStr_(p.newFarmerName, 'newFarmerName', 'اسم المزارع الجديد', { required: true, max: 80 });
    const dup = farmersFindDuplicate_(newFarmerName, null, true);
    if (dup) {
      const f = farmerToApi_(dup);
      failValidation_('newFarmerName', 'يوجد مزارع مسجل بالاسم «' + f.name + '» (رقم ' + f.no +
        '). اختره من القائمة بدل إضافته مرة أخرى.', { existing: f });
    }
  }

  // الوزن والسعر
  const boxes = purchasesBoxesIn_(p.boxes, 'boxes');
  const avg = purchasesAvgIn_(p.avgWeightGrams, 'avgWeightGrams');
  const method = inEnum_(p.weightMethod, 'weightMethod', 'طريقة حساب الوزن', RMN_WEIGHT_METHODS, { required: true });
  let samples = [];
  let tare = null;
  if (method === 'sample') {
    samples = purchasesSamplesIn_(p.sampleWeightsGrams, 'sampleWeightsGrams');
    tare = purchasesTareIn_(p.tareGrams, 'tareGrams', settingsRead_().emptyBoxGrams);
    purchasesCheckSample_(avg, samples, tare, 'avgWeightGrams', 'sampleWeightsGrams');
  }
  const price = purchasesPriceIn_(p.pricePerKgPiasters, 'pricePerKgPiasters');
  const occurredAt = inTime_(p.occurredAt, 'occurredAt', 'تاريخ ووقت العملية') || rqNow_();
  const notes = inStr_(p.notes, 'notes', 'الملاحظات', { max: 1000, multiline: true });
  const calc = purchaseMath_(boxes, avg, price);

  // الدفع
  let amount = 0;
  let payMethod = 'cash';
  if (mode !== 'none') {
    if (calc.valuePiasters <= 0) {
      failValidation_('payment.mode', 'قيمة العملية صفر، فلا يمكن تسجيل دفعة معها. راجع الأرقام أو اختر «بدون دفع».');
    }
    payMethod = inEnum_(pay.method, 'payment.method', 'طريقة الدفع', RMN_PAY_METHODS) || 'cash';
    if (mode === 'full') {
      amount = calc.valuePiasters;
    } else {
      amount = inInt_(pay.amountPiasters, 'payment.amountPiasters', 'المبلغ المدفوع', {
        required: true, min: 1, max: RMN_LIMITS.amountMax, fmt: fmtMoneyMsg_,
      });
      if (amount >= calc.valuePiasters) {
        failValidation_('payment.amountPiasters', '«المبلغ المدفوع» (' + fmtMoneyMsg_(amount) + ') يجب أن يكون أقل من قيمة العملية (' +
          fmtMoneyMsg_(calc.valuePiasters) + ') في الدفع الجزئي. اختر «دفع كامل» إن دُفعت القيمة كلها.',
          { valuePiasters: calc.valuePiasters });
      }
    }
  }

  // الكتابة
  let createdFarmer = null;
  if (!farmer) {
    farmer = farmersAppend_({ name: newFarmerName });
    createdFarmer = farmer;
  }
  const farmerId = cellStr_(farmer['المعرّف']);
  const farmerName = cellStr_(farmer['الاسم']);
  const coolerNo = cellInt_(cooler['رقم البراد']);
  const now = rqNow_();
  const who = userLabel_(user);
  const id = stNextId_(pt, 'PU');
  const row = {
    'المعرّف': id,
    'معرّف البراد': coolerId,
    'رقم البراد': coolerNo,
    'معرّف المزارع': farmerId,
    'اسم المزارع': farmerName,
    'تاريخ ووقت العملية': occurredAt,
    'عدد الصناديق': boxes,
    'متوسط وزن الصندوق (كغ)': toKg_(avg),
    'طريقة حساب الوزن': RMN_WEIGHT_METHODS[method],
    'أوزان العينة (كغ)': method === 'sample' ? samplesText_(samples) : '',
    'وزن الصندوق الفارغ (كغ)': method === 'sample' ? toKg_(tare) : '',
    'إجمالي الوزن (كغ)': toKg_(calc.totalWeightGrams),
    'سعر الكيلو (ج.م)': toEgp_(price),
    'إجمالي السعر (ج.م)': toEgp_(calc.valuePiasters),
    'المدفوع (ج.م)': toEgp_(amount),
    'المتبقي (ج.م)': toEgp_(calc.valuePiasters - amount),
    'حالة الدفع': enumToSheet_('payStatus', payStatusOf_(calc.valuePiasters, amount)),
    'الحالة': 'فعّالة',
    'سبب الإلغاء': '',
    'ملاحظات': notes,
    'تاريخ الإنشاء الفعلي': now,
    'أنشأها': who,
    'مفتاح عدم التكرار': req.requestId,
  };
  const rec = stAppend_(pt, [row])[0];
  auditAdd_('إنشاء', 'شراء رمان', id,
    purchasesDescribe_(farmerName, coolerNo, boxes, avg, calc.totalWeightGrams, price, calc.valuePiasters),
    null, row, '');

  let payRec = null;
  if (mode !== 'none') {
    payRec = paymentsAppend_({
      payeeType: 'farmer', payeeName: farmerName, payeeId: farmerId,
      targetType: 'purchase', targetId: id, coolerId: coolerId, coolerNo: coolerNo,
      amount: amount, method: payMethod, paidAt: occurredAt, notes: '', key: req.requestId,
    });
  }

  return {
    purchase: purchasePublic_(rec),
    payment: payRec ? paymentPublic_(payRec) : null,
    farmer: createdFarmer ? farmerToApi_(createdFarmer) : null,
    replayed: false,
  };
}

/** يعيد نتيجة purchases.create المحفوظة (نفس requestId). */
function purchasesReplay_(rec, requestId) {
  const id = cellStr_(rec['المعرّف']);
  let payment = null;
  stTable_('payments').rows.forEach(function (r) {
    if (!payment && cellStr_(r['مفتاح عدم التكرار']) === requestId && cellStr_(r['معرّف العملية']) === id) payment = r;
  });
  let farmer = null;
  const f = stFindById_(stTable_('farmers'), rec['معرّف المزارع']);
  const fAt = f ? cellDate_(f['تاريخ الإضافة']) : null;
  const pAt = cellDate_(rec['تاريخ الإنشاء الفعلي']);
  if (fAt && pAt && Math.floor(fAt.getTime() / 1000) === Math.floor(pAt.getTime() / 1000) &&
    labelEmail_(f['أضافه']) === labelEmail_(rec['أنشأها'])) {
    farmer = f; // أُنشئ المزارع في الطلب نفسه
  }
  return {
    purchase: purchasePublic_(rec),
    payment: payment ? paymentPublic_(payment) : null,
    farmer: farmer ? farmerToApi_(farmer) : null,
    replayed: true,
  };
}

/** purchases.update {id, expectedVersion, changes} */
function purchasesUpdateAction_(p, user) {
  stRequire_(stDataKeys_().concat(['settings', 'audit']));
  const pt = stTable_('purchases');
  const id = inId_(p.id, 'id', 'عملية الشراء');
  const rec = purchasesMustFind_(id, 'id');
  purchasesRequireOwnerOrEditOthers_(user, rec);
  const cooler = stFindById_(stTable_('coolers'), rec['معرّف البراد']);
  if (cooler && coolerIsClosed_(cooler)) throw coolerClosedError_(cooler);
  if (!purchaseIsActive_(rec)) {
    failValidation_('id', 'عملية الشراء ' + id + ' ملغاة، فلا يمكن تعديلها. سجّل عملية جديدة إن لزم.');
  }
  const expected = inExpectedVersion_(p.expectedVersion);
  if (stVersion_(rec) !== expected) failConflict_('عملية الشراء هذه', stVersion_(rec), purchasePublic_(rec));

  const ch = p.changes;
  if (!isPlainObject_(ch)) {
    failValidation_('changes', '«التغييرات» مطلوبة. أرسل الحقول التي تريد تعديلها.');
  }
  const has = function (k) { return Object.prototype.hasOwnProperty.call(ch, k) && ch[k] !== undefined; };
  const m = purchaseMeasures_(rec);
  const curMethod = enumToApi_('weightMethod', rec['طريقة حساب الوزن'], 'direct');
  const settings = settingsRead_();

  const boxes = has('boxes') ? purchasesBoxesIn_(ch.boxes, 'boxes') : m.boxes;
  const avg = has('avgWeightGrams') ? purchasesAvgIn_(ch.avgWeightGrams, 'avgWeightGrams') : m.avgWeightGrams;
  const price = has('pricePerKgPiasters') ? purchasesPriceIn_(ch.pricePerKgPiasters, 'pricePerKgPiasters') : m.pricePerKgPiasters;
  const method = has('weightMethod')
    ? inEnum_(ch.weightMethod, 'weightMethod', 'طريقة حساب الوزن', RMN_WEIGHT_METHODS, { required: true })
    : curMethod;
  let samples = [];
  let tare = null;
  if (method === 'sample') {
    samples = has('sampleWeightsGrams')
      ? purchasesSamplesIn_(ch.sampleWeightsGrams, 'sampleWeightsGrams')
      : (curMethod === 'sample' ? samplesParse_(rec['أوزان العينة (كغ)']) : []);
    if (!samples.length) purchasesSamplesIn_(samples, 'sampleWeightsGrams');
    const curTare = curMethod === 'sample' ? cellGrams_(rec['وزن الصندوق الفارغ (كغ)']) : null;
    tare = has('tareGrams')
      ? purchasesTareIn_(ch.tareGrams, 'tareGrams', settings.emptyBoxGrams)
      : (curTare === null ? settings.emptyBoxGrams : curTare);
    if (has('avgWeightGrams') || has('sampleWeightsGrams') || has('tareGrams') || has('weightMethod')) {
      purchasesCheckSample_(avg, samples, tare, 'avgWeightGrams', 'sampleWeightsGrams');
    }
  }

  let farmer = null;
  if (has('farmerId')) {
    const fid = inId_(ch.farmerId, 'farmerId', 'المزارع');
    if (fid !== cellStr_(rec['معرّف المزارع'])) {
      farmer = purchasesFarmerFor_(fid, 'farmerId');
      if (dmActivePaymentsCount_(id) > 0) {
        failValidation_('farmerId', 'لا يمكن تغيير المزارع لعملية عليها دفعات مسجلة باسم المزارع الحالي. ' +
          'ألغِ الدفعات أولًا، ثم غيّر المزارع وسجّل الدفعات من جديد.');
      }
    }
  }
  const occurredAt = has('occurredAt') ? inTime_(ch.occurredAt, 'occurredAt', 'تاريخ ووقت العملية') : null;
  const notes = has('notes') ? inStr_(ch.notes, 'notes', 'الملاحظات', { max: 1000, multiline: true }) : null;

  const calc = purchaseMath_(boxes, avg, price);
  const paid = dmActivePaid_(id);
  if (calc.valuePiasters < paid) {
    const field = ['pricePerKgPiasters', 'avgWeightGrams', 'boxes'].filter(has)[0] || 'boxes';
    failValidation_(field, 'القيمة الجديدة للعملية (' + fmtMoneyMsg_(calc.valuePiasters) + ') أقل من المدفوع فعلًا (' +
      fmtMoneyMsg_(paid) + '). ألغِ دفعة أولًا أو صحّح الأرقام.', { valuePiasters: calc.valuePiasters, paidPiasters: paid });
  }

  const c = {
    'عدد الصناديق': boxes,
    'متوسط وزن الصندوق (كغ)': toKg_(avg),
    'طريقة حساب الوزن': RMN_WEIGHT_METHODS[method],
    'أوزان العينة (كغ)': method === 'sample' ? samplesText_(samples) : '',
    'وزن الصندوق الفارغ (كغ)': method === 'sample' ? toKg_(tare) : '',
    'إجمالي الوزن (كغ)': toKg_(calc.totalWeightGrams),
    'سعر الكيلو (ج.م)': toEgp_(price),
    'إجمالي السعر (ج.م)': toEgp_(calc.valuePiasters),
    'المدفوع (ج.م)': toEgp_(paid),
    'المتبقي (ج.م)': toEgp_(calc.valuePiasters - paid),
    'حالة الدفع': enumToSheet_('payStatus', payStatusOf_(calc.valuePiasters, paid)),
  };
  if (farmer) {
    c['معرّف المزارع'] = cellStr_(farmer['المعرّف']);
    c['اسم المزارع'] = cellStr_(farmer['الاسم']);
  }
  if (occurredAt) c['تاريخ ووقت العملية'] = occurredAt;
  if (notes !== null) c['ملاحظات'] = notes;

  const diff = auditDiff_(rec, c);
  if (!diff.changed) return { purchase: purchasePublic_(rec) };
  const changes = {};
  Object.keys(diff.next).forEach(function (k) { changes[k] = c[k]; });
  stUpdate_(pt, rec, changes);
  auditAdd_('تعديل', 'شراء رمان', id, 'تعديل عملية الشراء ' + id + ' من «' + cellStr_(rec['اسم المزارع']) +
    '» (القيمة الآن ' + fmtMoneyMsg_(calc.valuePiasters) + ')', diff.prev, diff.next, '');
  return { purchase: purchasePublic_(rec) };
}

/** purchases.cancel {id, reason} */
function purchasesCancelAction_(p, user) {
  stRequire_(stDataKeys_().concat(['audit']));
  const pt = stTable_('purchases');
  const id = inId_(p.id, 'id', 'عملية الشراء');
  const reason = inReason_(p.reason, 'لإلغاء عملية الشراء');
  const rec = purchasesMustFind_(id, 'id');
  purchasesRequireOwnerOrEditOthers_(user, rec);
  const cooler = stFindById_(stTable_('coolers'), rec['معرّف البراد']);
  if (cooler && coolerIsClosed_(cooler)) throw coolerClosedError_(cooler);
  if (!purchaseIsActive_(rec)) {
    failValidation_('id', 'عملية الشراء ' + id + ' ملغاة بالفعل. لا حاجة لإلغائها مرة أخرى.');
  }
  if (inPresent_(p.expectedVersion)) {
    const expected = inExpectedVersion_(p.expectedVersion);
    if (stVersion_(rec) !== expected) failConflict_('عملية الشراء هذه', stVersion_(rec), purchasePublic_(rec));
  }
  const count = dmActivePaymentsCount_(id);
  if (count > 0) {
    failValidation_('id', 'على عملية الشراء ' + id + ' ' + count + ' دفعة فعّالة بمبلغ ' + fmtMoneyMsg_(dmActivePaid_(id)) +
      '. ألغِ الدفعات أولًا ثم ألغِ العملية.', { activePayments: count });
  }
  const m = purchaseMeasures_(rec);
  const before = { status: 'active', valuePiasters: m.valuePiasters };
  stUpdate_(pt, rec, {
    'الحالة': 'ملغاة',
    'سبب الإلغاء': reason,
    'المدفوع (ج.م)': 0,
    'المتبقي (ج.م)': 0,
    'حالة الدفع': enumToSheet_('payStatus', 'unpaid'),
  });
  auditAdd_('إلغاء', 'شراء رمان', id, 'إلغاء عملية الشراء ' + id + ' من «' + cellStr_(rec['اسم المزارع']) + '» بقيمة ' +
    fmtMoneyMsg_(m.valuePiasters), before, { status: 'cancelled' }, reason);
  return { purchase: purchasePublic_(rec) };
}
