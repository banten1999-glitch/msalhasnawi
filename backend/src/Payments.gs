/**
 * Payments.gs — صفحة «المدفوعات». كل دفعة سجل مستقل مرتبط بعملية شراء رمان أو شراء تعبئة.
 * إجمالي المدفوع في كل التقارير = مجموع الدفعات الفعّالة. الدفع مسموح حتى لو كان البراد مقفّلًا.
 */

const RMN_TARGET_TYPES = Object.freeze({ purchase: 'شراء رمان', packaging: 'شراء تعبئة' });

/** صف الدفعة → كائن Payment (مع _t للترتيب). */
function paymentToApi_(rec) {
  const paidAt = cellDate_(rec['تاريخ الدفعة']);
  const created = cellDate_(rec['تاريخ الإنشاء']);
  const coolerId = cellStr_(rec['معرّف البراد']);
  const creator = dmWho_(rec['أنشأها']);
  return {
    id: cellStr_(rec['المعرّف']),
    no: cellStr_(rec['رقم الدفعة']),
    payeeType: enumToApi_('payeeType', rec['نوع المستفيد'], 'farmer'),
    payeeName: cellStr_(rec['اسم المستفيد']),
    payeeId: cellStr_(rec['معرّف المستفيد']),
    targetType: enumToApi_('payTarget', rec['نوع العملية'], 'purchase'),
    targetId: cellStr_(rec['معرّف العملية']),
    coolerId: coolerId,
    coolerNo: coolerId ? dmCoolerNo_(coolerId, rec['رقم البراد']) : cellInt_(rec['رقم البراد']),
    amountPiasters: cellMoney_(rec['المبلغ (ج.م)']) || 0,
    method: enumToApi_('payMethod', rec['طريقة الدفع'], 'cash'),
    paidAt: fmtIso_(paidAt),
    status: enumToApi_('recordStatus', rec['الحالة'], 'active'),
    cancelReason: cellStr_(rec['سبب الإلغاء']),
    notes: cellStr_(rec['ملاحظات']),
    createdAt: fmtIso_(created),
    createdBy: creator.name,
    createdByEmail: creator.email,
    version: stVersion_(rec),
    _t: paidAt || created,
  };
}

function paymentPublic_(rec) {
  return dmStripPrivate_(paymentToApi_(rec));
}

/**
 * يضيف صف دفعة. f: {payeeType, payeeName, payeeId, targetType, targetId, coolerId, coolerNo,
 * amount, method, paidAt, notes, key}. يسجل سطر «دفعة» في سجل التعديلات.
 */
function paymentsAppend_(f) {
  const t = stTable_('payments');
  const id = stNextId_(t, 'PY');
  const no = seqFormat_('D', stNextSeq_(t, 'رقم الدفعة', 'D'));
  const row = {
    'المعرّف': id,
    'رقم الدفعة': no,
    'نوع المستفيد': enumToSheet_('payeeType', f.payeeType),
    'اسم المستفيد': f.payeeName || '',
    'معرّف المستفيد': f.payeeId || '',
    'نوع العملية': RMN_TARGET_TYPES[f.targetType],
    'معرّف العملية': f.targetId,
    'معرّف البراد': f.coolerId || '',
    'رقم البراد': f.coolerNo === null || f.coolerNo === undefined ? '' : f.coolerNo,
    'المبلغ (ج.م)': toEgp_(f.amount),
    'طريقة الدفع': RMN_PAY_METHODS[f.method],
    'تاريخ الدفعة': f.paidAt,
    'الحالة': 'فعّالة',
    'سبب الإلغاء': '',
    'ملاحظات': f.notes || '',
    'تاريخ الإنشاء': rqNow_(),
    'أنشأها': userLabel_(rq_().user),
    'مفتاح عدم التكرار': f.key || '',
  };
  const rec = stAppend_(t, [row])[0];
  const who = f.payeeType === 'farmer' ? 'للمزارع' : 'للمورد';
  auditAdd_('دفعة', 'دفعة', id, 'دفعة ' + no + ' بمبلغ ' + fmtMoneyMsg_(f.amount) + ' ' + who + ' «' + (f.payeeName || '') +
    '» عن ' + RMN_TARGET_TYPES[f.targetType] + ' ' + f.targetId + ' (' + RMN_PAY_METHODS[f.method] + ')', null, row, '');
  return rec;
}

/** يعيد حساب أعمدة المدفوع/المتبقي المخزنة على العملية المرتبطة. */
function paymentsRefreshTarget_(type, id, opts) {
  if (type === 'packaging') {
    const rec = stFindById_(stTable_('packaging'), id);
    if (rec) packagingSyncCache_(rec, opts);
    return rec;
  }
  const rec = stFindById_(stTable_('purchases'), id);
  if (rec) purchasesSyncCache_(rec, opts);
  return rec;
}

/** كائن العملية المرتبطة بالدفعة (Purchase أو PackagingSummary) أو null. */
function paymentsTargetApi_(type, id) {
  if (type === 'packaging') {
    const rec = stFindById_(stTable_('packaging'), id);
    return rec ? packagingPublic_(rec) : null;
  }
  const rec = stFindById_(stTable_('purchases'), id);
  return rec ? purchasePublic_(rec) : null;
}

// =====================================================================================
// الإجراءات
// =====================================================================================

/** payments.list {targetId?, payeeId?, coolerId?} — الأحدث أولًا، مع الملغاة. */
function paymentsListAction_(p) {
  dmIndex_();
  const targetId = inStr_(p.targetId, 'targetId', 'العملية', { max: 64 });
  const payeeId = inStr_(p.payeeId, 'payeeId', 'المستفيد', { max: 64 });
  const coolerId = inStr_(p.coolerId, 'coolerId', 'البراد', { max: 64 });
  const list = stTable_('payments').rows.filter(function (r) {
    if (targetId && cellStr_(r['معرّف العملية']) !== targetId) return false;
    if (payeeId && cellStr_(r['معرّف المستفيد']) !== payeeId) return false;
    if (coolerId && cellStr_(r['معرّف البراد']) !== coolerId) return false;
    return true;
  }).map(paymentToApi_);
  list.sort(dmByTimeDesc_(function (x) { return x._t; }, function (x) { return x.id; }));
  return { payments: list.map(dmStripPrivate_) };
}

/** payments.create {targetType, targetId, amountPiasters, method, paidAt?, notes?} — idempotent على requestId. */
function paymentsCreateAction_(p, user, req) {
  stRequire_(stDataKeys_().concat(['audit']));
  const t = stTable_('payments');
  const replay = stFindByKey_(t, req.requestId);
  if (replay) {
    const r = paymentToApi_(replay);
    return { payment: dmStripPrivate_(r), target: paymentsTargetApi_(r.targetType, r.targetId), replayed: true };
  }

  const targetType = inEnum_(p.targetType, 'targetType', 'نوع العملية', RMN_TARGET_TYPES, { required: true });
  const targetLabel = targetType === 'purchase' ? 'عملية شراء الرمان' : 'شراء التعبئة';
  const targetId = inId_(p.targetId, 'targetId', targetLabel);
  const amount = inInt_(p.amountPiasters, 'amountPiasters', 'المبلغ', {
    required: true, min: 1, max: RMN_LIMITS.amountMax, fmt: fmtMoneyMsg_,
  });
  const method = inEnum_(p.method, 'method', 'طريقة الدفع', RMN_PAY_METHODS, { required: true });
  const paidAt = inTime_(p.paidAt, 'paidAt', 'تاريخ الدفعة') || rqNow_();
  const notes = inStr_(p.notes, 'notes', 'الملاحظات', { max: 1000, multiline: true });

  let f;
  let total;
  if (targetType === 'purchase') {
    const rec = stFindById_(stTable_('purchases'), targetId);
    if (!rec) failNotFound_('targetId', 'عملية الشراء', targetId);
    if (!purchaseIsActive_(rec)) {
      failValidation_('targetId', 'عملية الشراء ' + targetId + ' ملغاة، فلا يمكن الدفع لها.');
    }
    total = purchaseMeasures_(rec).valuePiasters;
    const farmerId = cellStr_(rec['معرّف المزارع']);
    const coolerId = cellStr_(rec['معرّف البراد']);
    f = {
      payeeType: 'farmer', payeeName: dmFarmerName_(farmerId, rec['اسم المزارع']), payeeId: farmerId,
      coolerId: coolerId, coolerNo: dmCoolerNo_(coolerId, rec['رقم البراد']),
    };
  } else {
    const rec = stFindById_(stTable_('packaging'), targetId);
    if (!rec) failNotFound_('targetId', 'شراء التعبئة', targetId);
    const status = enumToApi_('packagingStatus', rec['الحالة'], 'draft');
    if (status !== 'approved') {
      failValidation_('targetId', 'شراء التعبئة ' + cellStr_(rec['رقم الشراء']) + ' ' +
        (status === 'draft' ? 'ما زال مسودة. اعتمده أولًا ثم سجّل الدفعة.' : 'ملغى، فلا يمكن الدفع له.'));
    }
    total = packagingTotals_(targetId).completeTotal;
    const coolerId = cellStr_(rec['معرّف البراد']);
    f = {
      payeeType: 'supplier', payeeName: cellStr_(rec['المورد']), payeeId: '',
      coolerId: coolerId, coolerNo: coolerId ? dmCoolerNo_(coolerId, rec['رقم البراد']) : null,
    };
  }
  const paid = dmActivePaid_(targetId);
  const remaining = total - paid;
  if (remaining <= 0) {
    failValidation_('amountPiasters', 'هذه العملية مدفوعة بالكامل (' + fmtMoneyMsg_(total) + '). لا يوجد مبلغ متبقٍ للدفع.',
      { remainingPiasters: Math.max(remaining, 0) });
  }
  if (amount > remaining) {
    failValidation_('amountPiasters', '«المبلغ» (' + fmtMoneyMsg_(amount) + ') أكبر من المتبقي (' + fmtMoneyMsg_(remaining) +
      '). اكتب مبلغًا لا يزيد على المتبقي.', { remainingPiasters: remaining });
  }

  const rec = paymentsAppend_(Object.assign(f, {
    targetType: targetType, targetId: targetId, amount: amount, method: method, paidAt: paidAt, notes: notes,
    key: req.requestId,
  }));
  paymentsRefreshTarget_(targetType, targetId);
  return { payment: paymentPublic_(rec), target: paymentsTargetApi_(targetType, targetId), replayed: false };
}

/** payments.cancel {id, reason} */
function paymentsCancelAction_(p) {
  stRequire_(stDataKeys_().concat(['audit']));
  const t = stTable_('payments');
  const id = inId_(p.id, 'id', 'الدفعة');
  const reason = inReason_(p.reason, 'لإلغاء الدفعة');
  const rec = stFindById_(t, id);
  if (!rec) failNotFound_('id', 'الدفعة', id);
  const cur = paymentToApi_(rec);
  if (cur.status !== 'active') {
    failValidation_('id', 'الدفعة ' + cur.no + ' ملغاة بالفعل. لا حاجة لإلغائها مرة أخرى.');
  }
  if (inPresent_(p.expectedVersion)) {
    const expected = inExpectedVersion_(p.expectedVersion);
    if (cur.version !== expected) failConflict_('هذه الدفعة', cur.version, dmStripPrivate_(cur));
  }
  stUpdate_(t, rec, { 'الحالة': 'ملغاة', 'سبب الإلغاء': reason });
  paymentsRefreshTarget_(cur.targetType, cur.targetId);
  auditAdd_('إلغاء', 'دفعة', id, 'إلغاء الدفعة ' + cur.no + ' بمبلغ ' + fmtMoneyMsg_(cur.amountPiasters) + ' لـ «' +
    cur.payeeName + '» عن ' + RMN_TARGET_TYPES[cur.targetType] + ' ' + cur.targetId,
    { status: 'active', amountPiasters: cur.amountPiasters }, { status: 'cancelled' }, reason);
  return { payment: paymentPublic_(rec), target: paymentsTargetApi_(cur.targetType, cur.targetId) };
}
