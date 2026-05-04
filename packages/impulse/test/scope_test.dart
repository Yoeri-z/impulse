import 'package:test/test.dart';

import 'package:impulse/impulse.dart';

final dummyRef = Ref<Object>((store) => Object());

void main() {
  test('Ref is removed after scope', () async {
    var store = Store();

    await withScope(
      (store) async {
        await Future.microtask(() {});
        store.init(dummyRef());
      },
      store: store,
      ref: dummyRef(),
    );

    expect(store.exists(dummyRef()), isFalse);
  });
}
