// This file belongs to THIS project (the installer never replaces it).
// It lists the screens the local screenshot harness renders, dressed in the
// app's real theme. Run: python3 tool/local_screenshots.py --shot home
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:khatabook/core/theme/app_theme.dart';
import 'package:khatabook/features/calculator/calculator_screen.dart';
import 'package:khatabook/features/counter/note_counter_screen.dart';
import 'package:khatabook/features/entry/add_entry_screen.dart';
import 'package:khatabook/features/home/home_screen.dart';
import 'package:khatabook/features/home/models.dart';
import 'package:khatabook/features/profile/profile_screen.dart';

import 'shot_framework.dart';

/// Widget tests otherwise use the Ahem test font, where every glyph is a
/// square: text becomes boxes and a normal Row looks like an overflow bug.
/// These two files ship with the repo (Apache-2.0, see assets/fonts/) and are
/// loaded only by the screenshot runner - the app itself uses platform fonts.
Future<void> _loadRoboto() async {
  final FontLoader loader = FontLoader('Roboto');
  for (final String path in <String>[
    'assets/fonts/Roboto-Regular.ttf',
    'assets/fonts/Roboto-Bold.ttf',
  ]) {
    final Uint8List bytes = await File(path).readAsBytes();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// The same light theme and phone size the design preview was drawn for.
/// Tab shots include the real bottom-navigation treatment; Add Entry is a
/// pushed screen, so it correctly sits above that navigation bar.
final ShotEnv env = ShotEnv(
  app: (Shot shot, Widget home) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: shot.name == 'add_entry'
        ? home
        : _TabShotShell(index: _tabIndex(shot.name), child: home),
  ),
  setUpAll: _loadRoboto,
);

int _tabIndex(String name) {
  switch (name) {
    case 'calculator':
      return 1;
    case 'counter':
      return 2;
    case 'profile':
      return 3;
    default:
      return 0;
  }
}

class _TabShotShell extends StatelessWidget {
  const _TabShotShell({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (_) {},
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Calculator',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Counter',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

final List<Shot> shots = <Shot>[
  Shot(
    name: 'home',
    build: () => HomeScreen(
      summary: LedgerSummary(
        openingBalancePaise: kSeedOpeningBalancePaise,
        entries: kSeedEntries,
      ),
      khataName: 'Personal Khata',
      onSwitchKhata: () {},
      onAddEntry: () {},
      onViewAll: () {},
    ),
    dark: false,
  ),
  Shot(name: 'calculator', build: () => const CalculatorScreen(), dark: false),
  Shot(name: 'counter', build: () => const NoteCounterScreen(), dark: false),
  Shot(name: 'profile', build: () => const ProfileScreen(), dark: false),
  Shot(
    name: 'add_entry',
    build: () => AddEntryScreen(openingBalancePaise: 642000, onSave: (_) {}),
    dark: false,
  ),
];
