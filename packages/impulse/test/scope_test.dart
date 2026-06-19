import 'package:test/test.dart';

import 'package:impulse/impulse.dart';

final dummyRef = Ref<Object>((store) => Object());

void main() {
  test('Ref is removed after async scope', () async {
    var store = Store();

    await store.withScope(dummyRef, (store, value) async {
      await Future.microtask(() {});
      store.init(dummyRef);
    });

    expect(store.exists(dummyRef), isFalse);
  });

  test('Ref is removed after sync scope', () async {
    var store = Store();

    await store.withScope(dummyRef, (store, value) {
      store.init(dummyRef);
    });

    expect(store.exists(dummyRef), isFalse);
  });
}
