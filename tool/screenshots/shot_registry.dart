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
import 'package:khatabook/features/home/home_screen.dart';
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
final ShotEnv env = ShotEnv(
  app: (Shot shot, Widget home) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: home,
  ),
  setUpAll: _loadRoboto,
);

final List<Shot> shots = <Shot>[
  Shot(name: 'home', build: () => const HomeScreen(), dark: false),
  Shot(name: 'calculator', build: () => const CalculatorScreen(), dark: false),
  Shot(name: 'counter', build: () => const NoteCounterScreen(), dark: false),
  Shot(name: 'profile', build: () => const ProfileScreen(), dark: false),
];
