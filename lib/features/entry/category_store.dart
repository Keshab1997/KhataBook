// Flutter 3.50 deprecates this import; migrate with the app's dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../ledger/data/local_ledger.dart';

/// A stable identifier and presentation for a user-created category.
class CustomCategory {
  const CustomCategory({
    required this.id,
    required this.name,
    required this.iconIndex,
    required this.colorIndex,
    this.archived = false,
  });

  final String id;
  final String name;
  final int iconIndex;
  final int colorIndex;
  final bool archived;

  IconData get icon => categoryIcons[iconIndex];
  Color get color => categoryColors[colorIndex];
}

const categoryIcons = <IconData>[
  Icons.category,
  Icons.restaurant,
  Icons.home,
  Icons.shopping_bag,
  Icons.directions_car,
  Icons.favorite,
];

const categoryColors = <Color>[
  AppColors.primaryGreen,
  AppColors.orange,
  AppColors.golden,
  AppColors.expenseRed,
  AppColors.secondaryGreen,
  AppColors.softText,
];

/// Local-only storage. The auxiliary table is created lazily without a schema
/// version change, and archived records retain their stable transaction IDs.
class CategoryStore {
  CategoryStore(this._ledger);
  final LocalLedger _ledger;

  Future<void> _ensureTable() => _ledger.customStatement('''
    CREATE TABLE IF NOT EXISTS custom_categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      icon_index INTEGER NOT NULL,
      color_index INTEGER NOT NULL,
      archived INTEGER NOT NULL DEFAULT 0
    )
  ''');

  String _name(String name) {
    final value = name.trim();
    if (value.isEmpty || value.runes.length > 30) {
      throw const FormatException('Category name must contain 1 to 30 characters.');
    }
    return value;
  }

  Future<CustomCategory> add(String name, {int iconIndex = 0, int colorIndex = 0}) async {
    final validName = _name(name);
    if (iconIndex < 0 || iconIndex >= categoryIcons.length ||
        colorIndex < 0 || colorIndex >= categoryColors.length) {
      throw const FormatException('Unknown category appearance.');
    }
    final category = CustomCategory(
      id: 'custom:${const Uuid().v4()}',
      name: validName,
      iconIndex: iconIndex,
      colorIndex: colorIndex,
    );
    await _ensureTable();
    await _ledger.customStatement(
      'INSERT INTO custom_categories (id, name, icon_index, color_index) VALUES (?, ?, ?, ?)',
      [category.id, category.name, iconIndex, colorIndex],
    );
    return category;
  }

  Future<void> rename(String id, String name) async {
    final validName = _name(name);
    await _ensureTable();
    await _ledger.customStatement(
      'UPDATE custom_categories SET name = ? WHERE id = ?', [validName, id],
    );
  }

  Future<void> archive(String id) async {
    await _ensureTable();
    await _ledger.customStatement(
      'UPDATE custom_categories SET archived = 1 WHERE id = ?', [id],
    );
  }

  Future<List<CustomCategory>> load({bool includeArchived = false}) async {
    await _ensureTable();
    final rows = await _ledger.customSelect(
      'SELECT id, name, icon_index, color_index, archived FROM custom_categories '
      '${includeArchived ? '' : 'WHERE archived = 0 '}ORDER BY name, id',
    ).get();
    return rows.map((row) {
      final icon = row.read<int>('icon_index');
      final color = row.read<int>('color_index');
      return CustomCategory(
        id: row.read<String>('id'),
        name: row.read<String>('name'),
        iconIndex: icon >= 0 && icon < categoryIcons.length ? icon : 0,
        colorIndex: color >= 0 && color < categoryColors.length ? color : 0,
        archived: row.read<int>('archived') != 0,
      );
    }).toList();
  }
}
