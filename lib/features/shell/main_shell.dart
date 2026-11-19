// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../calculator/calculator_screen.dart';
import '../counter/note_counter_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';

/// The four destinations in the design preview: Home, Calculator, Counter,
/// Profile. Secondary screens are pushed above this shell in B2+.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const <Widget>[
          HomeScreen(),
          CalculatorScreen(),
          NoteCounterScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            label: 'Calculator',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            label: 'Counter',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
