import 'package:impulse/impulse.dart';

final counterRef = Ref((store) => Counter());

class Counter extends ImpulseNotifier {
  int count = 0;

  void increment() {
    count += 1;
    notify();
  }
}

void main() async {
  $store.select(
    counterRef,
    (counter) => counter.count,
    (count) => print('Count is $count'),
  );

  for (int i = 0; i < 10; i++) {
    $store.get(counterRef).increment();
  }

  $store.reset();
}
