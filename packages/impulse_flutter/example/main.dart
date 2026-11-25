import 'package:flutter/widgets.dart';
import 'package:impulse_flutter/impulse_flutter.dart';

// 1. Define a reference to a state class (ChangeNotifier is supported natively)
final counterRef = Ref((store) => ValueNotifier(0));

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
    return WidgetsApp(
      color: const Color.fromARGB(255, 0, 140, 255),
      builder: (context, child) => const CounterPage(),
    );
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // 3. Make the widget depend on state
            // a widget can hold at most one dependency per reference
            // calling this multiple times has (basically) no effect on performance
            'Count: ${context.use(counterRef).value}',
          ),
          const SizedBox(height: 12),
          GestureDetector(
            // 4. Use .read(context) to read the state without creating a widget dependency
            onTap: () => context.read(counterRef).value++,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 0, 140, 255),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text('Increment'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
