import 'package:flutter/material.dart';
import 'package:impulse_signals/impulse_signals.dart';

// 1. Define a reference to a Controller
final counterRef = Ref((store) => CounterController());

class CounterController extends Controller {
  late final count = createSignal(0);
  late final countEven = createComputed(() => count.value % 2 == 0);

  void increment() => count.value++;
}

void main() {
  runApp(
    // 2. Wrap your application in a StoreScope
    const StoreScope(child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: CounterPage());
  }
}

class CounterPage extends SignalWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 3. Depend on the controller
    final controller = context.use(counterRef);

    return Scaffold(
      appBar: AppBar(title: const Text('Impulse Counter Example')),
      body: Center(
        child: Column(
          children: [
            // read signals from the controller
            Text(
              'Count: ${controller.count.value}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'Count is ${controller.countEven.value ? 'even' : 'odd'}.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
