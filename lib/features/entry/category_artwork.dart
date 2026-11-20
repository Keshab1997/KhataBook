// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'category_store.dart';

/// AI-generated artwork for the app's canonical expense category IDs.
///
/// Keep these IDs unchanged: they are also stored in ledger transactions.
const Map<String, String> categoryIconAssets = <String, String>{
  'Shopping': 'assets/category_icons/shopping.png',
  'Food': 'assets/category_icons/food.png',
  'Travel': 'assets/category_icons/travel.png',
  'Bills': 'assets/category_icons/bills.png',
  'Gifts': 'assets/category_icons/gifts.png',
};

/// Renders the shared AI artwork, with a Material fallback for non-expense
/// categories such as Income or for older/unknown transaction categories.
class CategoryArtwork extends StatelessWidget {
  const CategoryArtwork({
    super.key,
    required this.category,
    required this.size,
    this.fallbackColor = AppColors.navigationGrey,
    this.customCategory,
  });

  final String category;
  final double size;
  final Color fallbackColor;
  final CustomCategory? customCategory;

  @override
  Widget build(BuildContext context) {
    final String? asset = categoryIconAssets[category];
    final Key imageKey = key ?? Key('category-artwork-$category');
    if (asset == null && customCategory != null) {
      return ColoredBox(
        color: customCategory!.color.withValues(alpha: 0.14),
        child: Icon(
          customCategory!.icon,
          key: imageKey,
          size: size * 0.65,
          color: customCategory!.color,
        ),
      );
    }
    if (asset == null) {
      return Icon(
        category == 'Income'
            ? Icons.south_west_rounded
            : Icons.more_horiz_rounded,
        key: imageKey,
        size: size,
        color: fallbackColor,
      );
    }
    return Image.asset(
      asset,
      key: imageKey,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}
