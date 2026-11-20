// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'category_artwork.dart';
import 'category_store.dart';

const starterCategories = <String>[
  'Shopping',
  'Food',
  'Travel',
  'Bills',
  'Gifts',
];

String categoryDisplayName(
  AppLanguage language,
  String id,
  List<CustomCategory> categories,
) {
  for (final category in categories) {
    if (category.id == id) return category.name;
  }
  final key = switch (id) {
    'Shopping' => AppString.shopping,
    'Food' => AppString.food,
    'Travel' => AppString.travel,
    'Bills' => AppString.bills,
    'Gifts' => AppString.gifts,
    'Income' => AppString.income,
    'Expense' => AppString.expense,
    _ => null,
  };
  if (key != null) return AppStrings(language).text(key);
  return language == AppLanguage.bn ? 'অন্যান্য' : 'Other';
}

CustomCategory? findCustomCategory(String id, List<CustomCategory> categories) {
  for (final category in categories) {
    if (category.id == id) return category;
  }
  return null;
}

/// Reacts to store changes while retaining archived categories for old rows.
class CategoryCatalog extends StatefulWidget {
  const CategoryCatalog({
    super.key,
    required this.store,
    required this.builder,
  });
  final CategoryStore store;
  final Widget Function(BuildContext, List<CustomCategory>) builder;

  @override
  State<CategoryCatalog> createState() => _CategoryCatalogState();
}

class _CategoryCatalogState extends State<CategoryCatalog> {
  late Future<List<CustomCategory>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.store.load(includeArchived: true);
    widget.store.addListener(_refresh);
  }

  @override
  void didUpdateWidget(CategoryCatalog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_refresh);
      widget.store.addListener(_refresh);
      _future = widget.store.load(includeArchived: true);
    }
  }

  void _refresh() {
    setState(() => _future = widget.store.load(includeArchived: true));
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CustomCategory>>(
    future: _future,
    builder: (context, snapshot) =>
        widget.builder(context, snapshot.data ?? const []),
  );
}

/// Additional active choices and the full picker, only shown with a store.
class CustomCategoryChoices extends StatelessWidget {
  const CustomCategoryChoices({
    super.key,
    required this.store,
    required this.language,
    required this.selected,
    required this.onSelected,
  });
  final CategoryStore store;
  final AppLanguage language;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => CategoryCatalog(
    store: store,
    builder: (context, categories) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (selected != null &&
            !starterCategories.contains(selected) &&
            selected != 'Income' &&
            !categories.any((c) => c.id == selected && !c.archived))
          Chip(
            avatar: Icon(
              findCustomCategory(selected!, categories)?.icon ??
                  Icons.more_horiz,
              color:
                  findCustomCategory(selected!, categories)?.color ??
                  AppColors.navigationGrey,
            ),
            label: Text(categoryDisplayName(language, selected!, categories)),
          ),
        for (final category in categories.where((c) => !c.archived))
          ActionChip(
            key: Key('custom-category-${category.id}'),
            avatar: Icon(category.icon, color: category.color),
            label: Text(category.name),
            backgroundColor: category.id == selected
                ? AppColors.lightGreen
                : AppColors.surface,
            onPressed: () => onSelected(category.id),
          ),
        ActionChip(
          key: const Key('category-more'),
          avatar: const Icon(Icons.more_horiz),
          label: Text(language == AppLanguage.bn ? 'আরও' : 'More'),
          onPressed: () async {
            final id = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _CategorySheet(store: store, language: language),
            );
            if (id != null && context.mounted) onSelected(id);
          },
        ),
      ],
    ),
  );
}

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.store, required this.language});
  final CategoryStore store;
  final AppLanguage language;
  String t(String en, String bn) => language == AppLanguage.bn ? bn : en;

  Future<void> _edit(BuildContext context, [CustomCategory? category]) async {
    final result = await showDialog<_CategoryDraft>(
      context: context,
      builder: (_) => _CategoryDialog(language: language, category: category),
    );
    if (result == null || !context.mounted) return;
    try {
      if (category == null) {
        final created = await store.add(
          result.name,
          iconIndex: result.icon,
          colorIndex: result.color,
        );
        if (context.mounted) Navigator.pop(context, created.id);
      } else {
        await store.rename(category.id, result.name);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('Could not save category.', 'বিভাগ সংরক্ষণ করা যায়নি।'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _archive(BuildContext context, CustomCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(t('Archive category?', 'বিভাগ আর্কাইভ করবেন?')),
        content: Text(
          t(
            'Existing entries will keep this category.',
            'আগের এন্ট্রিতে এই বিভাগ থাকবে।',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t('Cancel', 'বাতিল')),
          ),
          TextButton(
            key: const Key('confirm-archive-category'),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t('Archive', 'আর্কাইভ')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await store.archive(category.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('Could not archive category.', 'বিভাগ আর্কাইভ করা যায়নি।'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: CategoryCatalog(
      store: store,
      builder: (context, categories) => ListView(
        shrinkWrap: true,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          ListTile(title: Text(t('Categories', 'বিভাগসমূহ'))),
          for (final id in starterCategories)
            ListTile(
              leading: CategoryArtwork(category: id, size: 32),
              title: Text(categoryDisplayName(language, id, categories)),
              onTap: () => Navigator.pop(context, id),
            ),
          for (final category in categories.where((c) => !c.archived))
            ListTile(
              key: Key('category-sheet-${category.id}'),
              leading: Icon(category.icon, color: category.color),
              title: Text(category.name),
              onTap: () => Navigator.pop(context, category.id),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: t('Rename', 'নাম বদলান'),
                    icon: const Icon(Icons.edit),
                    onPressed: () => _edit(context, category),
                  ),
                  IconButton(
                    tooltip: t('Archive', 'আর্কাইভ'),
                    icon: const Icon(Icons.archive_outlined),
                    onPressed: () => _archive(context, category),
                  ),
                ],
              ),
            ),
          ListTile(
            key: const Key('new-category'),
            leading: const Icon(Icons.add),
            title: Text(t('New category', 'নতুন বিভাগ')),
            onTap: () => _edit(context),
          ),
        ],
      ),
    ),
  );
}

class _CategoryDraft {
  const _CategoryDraft(this.name, this.icon, this.color);
  final String name;
  final int icon;
  final int color;
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.language, this.category});
  final AppLanguage language;
  final CustomCategory? category;
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _name;
  int _icon = 0;
  int _color = 0;
  bool _invalid = false;
  String t(String en, String bn) => widget.language == AppLanguage.bn ? bn : en;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.category == null
          ? t('New category', 'নতুন বিভাগ')
          : t('Rename category', 'বিভাগের নাম বদলান'),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('category-name'),
            controller: _name,
            maxLength: 30,
            decoration: InputDecoration(
              labelText: t('Name', 'নাম'),
              errorText: _invalid ? t('Enter a name.', 'নাম লিখুন।') : null,
            ),
          ),
          if (widget.category == null) ...[
            Text(t('Icon', 'আইকন')),
            Wrap(
              children: [
                for (var i = 0; i < categoryIcons.length; i++)
                  IconButton(
                    key: Key('category-icon-$i'),
                    tooltip: '${t('Icon', 'আইকন')} ${i + 1}',
                    isSelected: _icon == i,
                    icon: Icon(categoryIcons[i]),
                    onPressed: () => setState(() => _icon = i),
                  ),
              ],
            ),
            Text(t('Colour', 'রং')),
            Wrap(
              children: [
                for (var i = 0; i < categoryColors.length; i++)
                  IconButton(
                    key: Key('category-color-$i'),
                    tooltip: '${t('Colour', 'রং')} ${i + 1}',
                    isSelected: _color == i,
                    icon: Icon(Icons.circle, color: categoryColors[i]),
                    onPressed: () => setState(() => _color = i),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t('Cancel', 'বাতিল')),
      ),
      TextButton(
        key: const Key('save-category'),
        onPressed: () {
          final name = _name.text.trim();
          if (name.isEmpty || name.runes.length > 30) {
            setState(() => _invalid = true);
            return;
          }
          Navigator.pop(context, _CategoryDraft(name, _icon, _color));
        },
        child: Text(t('Save', 'সংরক্ষণ')),
      ),
    ],
  );
}
