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
    // The store notifies from inside an async gap (after its write), so the
    // reload is scheduled as a plain microtask; setState runs synchronously.
    Future<void>.microtask(() {
      if (mounted) {
        setState(() {
          _future = widget.store.load(includeArchived: true);
        });
      }
    });
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
            avatar: Icon(category.icon, color: category.color, size: 18),
            label: Text(category.name),
            backgroundColor: category.id == selected
                ? AppColors.lightGreen
                : AppColors.surface,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: category.id == selected
                  ? AppColors.primaryGreen
                  : AppColors.darkText,
            ),
            side: BorderSide(
              color: category.id == selected
                  ? AppColors.primaryGreen
                  : AppColors.beige,
            ),
            shape: const StadiumBorder(),
            onPressed: () => onSelected(category.id),
          ),
        ActionChip(
          key: const Key('category-more'),
          avatar: const Icon(Icons.more_horiz, size: 18),
          label: Text(language == AppLanguage.bn ? 'আরও' : 'More'),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.darkText,
          ),
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.beige),
          shape: const StadiumBorder(),
          onPressed: () async {
            final id = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              // Ivory, not the ambient surface tone: the sheet belongs to the
              // warm paper palette every other card on these screens uses.
              backgroundColor: AppColors.surface,
              builder: (_) => _CategorySheet(
                store: store,
                language: language,
                selected: selected,
              ),
            );
            if (id != null && context.mounted) onSelected(id);
          },
        ),
      ],
    ),
  );
}

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({
    required this.store,
    required this.language,
    this.selected,
  });
  final CategoryStore store;
  final AppLanguage language;
  final String? selected;
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
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Drag handle + a header that stays put while the choices scroll:
        // the sheet is a picker, so its title should not scroll away.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  t('Categories', 'বিভাগসমূহ'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              IconButton(
                key: const Key('category-sheet-close'),
                tooltip: t('Close', 'বন্ধ করুন'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.softText),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.beige),
        Flexible(
          child: CategoryCatalog(
            store: store,
            builder: (context, categories) {
              final List<CustomCategory> custom = categories
                  .where((c) => !c.archived)
                  .toList(growable: false);
              return ListView(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  16 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: <Widget>[
                  _starterGrid(context, categories),
                  if (custom.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 18),
                    _SheetCaption(t('Your categories', 'আপনার বিভাগ')),
                    const SizedBox(height: 4),
                    for (final category in custom)
                      ListTile(
                        key: Key('category-sheet-${category.id}'),
                        contentPadding: EdgeInsets.zero,
                        selected: category.id == selected,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: category.color.withValues(
                            alpha: 0.16,
                          ),
                          child: Icon(
                            category.icon,
                            size: 18,
                            color: category.color,
                          ),
                        ),
                        title: Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkText,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, category.id),
                        trailing: Wrap(
                          children: [
                            IconButton(
                              tooltip: t('Rename', 'নাম বদলান'),
                              icon: const Icon(
                                Icons.edit,
                                size: 20,
                                color: AppColors.softText,
                              ),
                              onPressed: () => _edit(context, category),
                            ),
                            IconButton(
                              tooltip: t('Archive', 'আর্কাইভ'),
                              icon: const Icon(
                                Icons.archive_outlined,
                                size: 20,
                                color: AppColors.softText,
                              ),
                              onPressed: () => _archive(context, category),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 18),
                  _NewCategoryTile(
                    label: t('New category', 'নতুন বিভাগ'),
                    onTap: () => _edit(context),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );

  /// The five built-in categories as the same artwork tiles Add Entry uses,
  /// laid out in as many even columns as the sheet is wide.
  Widget _starterGrid(BuildContext context, List<CustomCategory> categories) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = 12;
        // Three columns at phone width, more on a tablet, never so many that
        // a tile gets narrower than its own label.
        final int fitting = (constraints.maxWidth / 82).floor();
        final int columns = fitting < 3
            ? 3
            : fitting > 6
            ? 6
            : fitting;
        final double width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 14,
          children: <Widget>[
            for (final String id in starterCategories)
              SizedBox(
                width: width,
                child: _CategoryTile(
                  key: Key('category-sheet-$id'),
                  label: categoryDisplayName(language, id, categories),
                  selected: id == selected,
                  onTap: () => Navigator.pop(context, id),
                  child: CategoryArtwork(category: id, size: 56),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One artwork tile in the picker: a rounded frame, the illustration and the
/// name underneath, with the chosen category ringed and tinted.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: selected ? AppColors.lightGreen : AppColors.warmIvory,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? AppColors.primaryGreen : AppColors.beige,
                    width: selected ? 1.8 : 1.1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: child,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primaryGreen : AppColors.softText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet section caption inside the sheet.
class _SheetCaption extends StatelessWidget {
  const _SheetCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: AppColors.softText,
      ),
    );
  }
}

/// The "new category" row: an outlined slot rather than a list row, so it
/// reads as an action at the end of the picker.
class _NewCategoryTile extends StatelessWidget {
  const _NewCategoryTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warmIvory,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: AppColors.primaryGreen.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        key: const Key('new-category'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: <Widget>[
              const Icon(Icons.add, size: 20, color: AppColors.primaryGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
