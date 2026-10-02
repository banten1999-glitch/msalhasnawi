/**
 * Records.gs — فهرس مشترك لكل طلب يربط السجلات ببعضها ويحسب المجاميع الحية:
 * المدفوع لكل عملية (من الدفعات الفعّالة)، وأصناف كل شراء تعبئة، ومجاميع كل براد.
 * يُبنى مرة واحدة من الصفحات المحفوظة في الذاكرة، ويُعاد بناؤه تلقائيًا بعد أي كتابة.
 */

function dmEmptyAgg_() {
  return {
    farmerIds: {}, farmers: 0, purchases: 0, boxes: 0, weightGrams: 0, valuePiasters: 0, paidPiasters: 0,
    packagingApprovedPiasters: 0, packagingLatePiasters: 0,
  };
}

/** يحسب بيانات صنف التعبئة من صفه (الحالة «مكتمل» تُشتق من وجود الكمية والسعر). */
function dmItemFields_(rec) {
  const quantity = cellInt_(rec['الكمية']);
  const price = cellMoney_(rec['السعر المفرد (ج.م)']);
  const stored = enumToApi_('itemStatus', rec['الحالة'], 'incomplete');
  const complete = quantity !== null && price !== null;
  let total = null;
  if (complete) {
    total = cellMoney_(rec['الإجمالي (ج.م)']);
    if (total === null) total = quantity * price;
  }
  return {
    quantity: quantity,
    unitPricePiasters: price,
    totalPiasters: total,
    status: stored === 'removed' ? 'removed' : (complete ? 'complete' : 'incomplete'),
  };
}

function dmIndex_() {
  const rq = rq_();
  if (rq.index) return rq.index;
  stRequire_(['coolers', 'farmers', 'purchases', 'payments', 'packaging', 'packaging_items']);
  const ix = {
    coolers: Object.create(null),
    farmers: Object.create(null),
    paid: Object.create(null),
    payments: Object.create(null), // targetId → [سجلات الدفعات الفعّالة]
    items: Object.create(null), // packagingId → [سجلات الأصناف غير المحذوفة]
    pk: Object.create(null), // packagingId → {itemsCount, incompleteCount, completeTotal}
    coolerAgg: Object.create(null),
  };
  stTable_('coolers').rows.forEach(function (r) { ix.coolers[cellStr_(r['المعرّف'])] = r; });
  stTable_('farmers').rows.forEach(function (r) { ix.farmers[cellStr_(r['المعرّف'])] = r; });

  stTable_('payments').rows.forEach(function (r) {
    if (enumToApi_('recordStatus', r['الحالة'], 'active') !== 'active') return;
    const target = cellStr_(r['معرّف العملية']);
    if (!target) return;
    ix.paid[target] = (ix.paid[target] || 0) + (cellMoney_(r['المبلغ (ج.م)']) || 0);
    (ix.payments[target] = ix.payments[target] || []).push(r);
  });

  stTable_('packaging_items').rows.forEach(function (r) {
    const pkId = cellStr_(r['معرّف الشراء']);
    if (!pkId) return;
    const f = dmItemFields_(r);
    if (f.status === 'removed') return;
    (ix.items[pkId] = ix.items[pkId] || []).push(r);
    const s = ix.pk[pkId] = ix.pk[pkId] || { itemsCount: 0, incompleteCount: 0, completeTotal: 0 };
    s.itemsCount++;
    if (f.status === 'complete') s.completeTotal += f.totalPiasters;
    else s.incompleteCount++;
  });

  const agg = function (coolerId) {
    return ix.coolerAgg[coolerId] = ix.coolerAgg[coolerId] || dmEmptyAgg_();
  };

  stTable_('purchases').rows.forEach(function (r) {
    if (enumToApi_('recordStatus', r['الحالة'], 'active') !== 'active') return;
    const coolerId = cellStr_(r['معرّف البراد']);
    if (!coolerId) return;
    const a = agg(coolerId);
    const m = purchaseMeasures_(r);
    const farmerId = cellStr_(r['معرّف المزارع']);
    if (farmerId && !a.farmerIds[farmerId]) {
      a.farmerIds[farmerId] = true;
      a.farmers++;
    }
    a.purchases++;
    a.boxes += m.boxes;
    a.weightGrams += m.totalWeightGrams;
    a.valuePiasters += m.valuePiasters;
    a.paidPiasters += ix.paid[cellStr_(r['المعرّف'])] || 0;
  });

  stTable_('packaging').rows.forEach(function (r) {
    if (enumToApi_('packagingStatus', r['الحالة'], 'draft') !== 'approved') return;
    const coolerId = cellStr_(r['معرّف البراد']);
    if (!coolerId) return;
    const a = agg(coolerId);
    const total = (ix.pk[cellStr_(r['المعرّف'])] || { completeTotal: 0 }).completeTotal;
    a.packagingApprovedPiasters += total;
    if (cellBool_(r['تكلفة متأخرة'])) a.packagingLatePiasters += total;
  });

  rq.index = ix;
  return ix;
}

function dmCoolerAgg_(coolerId) {
  return dmIndex_().coolerAgg[coolerId] || dmEmptyAgg_();
}

function dmFarmerName_(farmerId, fallback) {
  const r = dmIndex_().farmers[farmerId];
  return r ? cellStr_(r['الاسم']) : cellStr_(fallback);
}

function dmCoolerNo_(coolerId, fallback) {
  const r = dmIndex_().coolers[coolerId];
  if (r) return cellInt_(r['رقم البراد']);
  return cellInt_(fallback);
}

/** ترتيب تنازلي بالوقت ثم بالمعرّف. */
function dmByTimeDesc_(getTime, getId) {
  return function (a, b) {
    const ta = getTime(a);
    const tb = getTime(b);
    const va = ta ? ta.getTime() : 0;
    const vb = tb ? tb.getTime() : 0;
    if (va !== vb) return vb - va;
    const ia = getId(a);
    const ib = getId(b);
    return ia < ib ? 1 : (ia > ib ? -1 : 0);
  };
}
