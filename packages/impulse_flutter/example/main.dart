import 'package:flutter/material.dart';
import 'package:impulse_flutter/impulse_flutter.dart';

final counterRef = Ref((store) => Counter());

class Counter extends ChangeNotifier {
  var count = 0;

  void increment() {
    count += 1;
    notifyListeners();
  }
}

void main() {
  runApp(StoreScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Impulse Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(title: 'Flutter Counter'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final counter = counterRef.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          spacing: 8,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '${counter.count}',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            FilledButton(
              onPressed: () => counter.increment(),
              child: Text('Increment count'),
            ),
          ],
        ),
      ),
    );
  }
}
