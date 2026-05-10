import 'package:flutter/material.dart';
import 'pages/classify_page.dart';
import 'pages/realtime_page.dart';
import 'pages/benchmark_page.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter ML Classifier',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final _pages = <Widget>[
    ClassifyPage(),
    RealtimePage(),
    BenchmarkPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.image),
            selectedIcon: Icon(Icons.image, color: Theme.of(context).colorScheme.primary),
            label: 'Klasifikasi',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera),
            selectedIcon: Icon(Icons.camera, color: Theme.of(context).colorScheme.primary),
            label: 'Realtime',
          ),
          NavigationDestination(
            icon: Icon(Icons.speed),
            selectedIcon: Icon(Icons.speed, color: Theme.of(context).colorScheme.primary),
            label: 'Benchmark',
          ),
        ],
      ),
    );
  }
}