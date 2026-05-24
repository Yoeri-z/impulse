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
  $store.watch(counterRef(), (count) => print('Count is $count'));

  $store.get(counterRef()).increment();

  $store.reset();
}
