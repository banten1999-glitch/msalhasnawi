import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/sync/outbox.dart';

import '../support/fake_backend_api.dart';

const _offline = ApiException(ApiErrorCode.network, 'لا يوجد اتصال');

void main() {
  late FakeBackendApi api;
  late MemoryOutboxStorage storage;
  late Outbox outbox;

  setUp(() async {
    api = FakeBackendApi();
    storage = MemoryOutboxStorage();
    outbox = Outbox(api: api, storage: storage, retryInterval: const Duration(hours: 1));
    await outbox.bindUser('Ali@Example.com');
  });
  tearDown(() => outbox.dispose());

  Future<SubmitOutcome> submit(String id, {String coolerId = 'CO-1'}) => outbox.submit(
        action: 'purchases.create',
        payload: {'coolerId': coolerId, 'boxes': 50},
        requestId: id,
        label: 'شراء · حسن',
        coolerId: coolerId,
      );

  test('متصل: يرسل مباشرة ولا يحفظ شيئًا', () async {
    api.handlers['purchases.create'] = (p) => {'purchase': {'id': 'PU-1'}};
    final r = await submit('r1');
    expect(r, isA<SubmitSent>());
    expect((r as SubmitSent).data['purchase'], {'id': 'PU-1'});
    expect(outbox.pendingCount, 0);
    expect(api.callsOf('purchases.create').single.requestId, 'r1');
  });

  test('دون اتصال: تُحفظ بالمعرّف نفسه وتُرسل لاحقًا مرة واحدة', () async {
    api.errors['purchases.create'] = _offline;
    final r = await submit('r1');
    expect(r, isA<SubmitQueued>());
    expect(outbox.pendingCount, 1);
    expect(outbox.pendingForCooler('CO-1'), 1);
    expect(outbox.pendingForCooler('CO-2'), 0);

    // ضغطة ثانية بالمعرّف نفسه لا تضيف نسخة.
    await submit('r1');
    expect(outbox.pendingCount, 1);

    // القائمة محفوظة لهذا المستخدم فقط (بأحرف صغيرة).
    final other = Outbox(api: api, storage: storage);
    addTearDown(other.dispose);
    await other.bindUser('ali@example.com');
    expect(other.pendingCount, 1);

    api.errors.remove('purchases.create');
    api.handlers['purchases.create'] = (p) => {'purchase': {'id': 'PU-1'}};
    final sent = <String>[];
    outbox.sent.listen((e) => sent.add(e.requestId));
    await outbox.flush();
    expect(outbox.pendingCount, 0);
    final ids = api.callsOf('purchases.create').map((c) => c.requestId).toSet();
    expect(ids, {'r1'});
    await Future<void>.delayed(Duration.zero);
    expect(sent, ['r1']);
    expect(storage.data.values.every((v) => v == '[]') || storage.data.isEmpty, isTrue);
  });

  test('رفض دائم (براد مقفّل): تبقى موقوفة ولا تمنع البقية', () async {
    api.errors['purchases.create'] = _offline;
    await submit('r1');
    await submit('r2', coolerId: 'CO-2');
    api.errors.remove('purchases.create');
    api.handlers['purchases.create'] = (p) {
      if (p['coolerId'] == 'CO-1') throw const ApiException(ApiErrorCode.coolerClosed, 'البراد مقفّل');
      return {'purchase': {'id': 'PU-2'}};
    };
    await outbox.flush();
    expect(outbox.pendingCount, 1);
    final blocked = outbox.entries.single;
    expect(blocked.requestId, 'r1');
    expect(blocked.blocked, isTrue);
    expect(blocked.lastError, 'البراد مقفّل');
    expect(outbox.blockedCount, 1);

    await outbox.discard('r1');
    expect(outbox.pendingCount, 0);
  });

  test('خطأ غير متعلق بالاتصال يُرمى للنموذج ولا يُحفظ', () async {
    api.errors['purchases.create'] = const ApiException(ApiErrorCode.validation, 'عدد الصناديق مطلوب', field: 'boxes');
    await expectLater(submit('r1'), throwsA(isA<ApiException>()));
    expect(outbox.pendingCount, 0);
  });

  test('دون مستخدم مربوط لا تُحفظ العمليات على الجهاز', () async {
    await outbox.bindUser(null);
    api.errors['purchases.create'] = _offline;
    await expectLater(submit('r1'), throwsA(isA<ApiException>()));
    expect(outbox.pendingCount, 0);
  });
}
