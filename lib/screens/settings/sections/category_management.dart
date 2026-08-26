import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../models/category.dart';
import '../../../utils/localization.dart';
import '../../../utils/category_colors.dart';

/// Управление на категориите (списък + добавяне/редакция/изтриване).
/// Изнесено от `settings_screen.dart` без промяна на поведение.
///
/// [onChanged] се вика, когато категориите се променят, за да пребилдне
/// екрана Настройки (замества предишния `setState(() {})`).
class CategoryManagement {
  const CategoryManagement._();

  static const List<Color> _categoryColors = kCategoryColors;

  static void show(BuildContext context, {required VoidCallback onChanged}) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final categoryBox = Hive.box<Category>('categories');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (innerContext, setSheetState) {
            final categories = categoryBox.values.toList();

            return Container(
              height: MediaQuery.of(innerContext).size.height * 0.7,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.category_rounded,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          t.categories,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(innerContext),
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Category list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final catColor = Color(cat.colorValue);
                        final localizedName = cat.id == 'cal_events'
                            ? t.catCalendarEvents
                            : cat.id == 'documents'
                            ? t.catDocuments
                            : cat.isDefault
                            ? {
                                'work': t.catWork,
                                'personal': t.catPersonal,
                                'shopping': t.catShopping,
                                'birthday': t.catBirthdays,
                                'meeting': t.catMeeting,
                                'workout': t.catWorkout,
                                'payment': t.catPayment,
                                'travel': t.catTravel,
                                'gift': t.catGift,
                              }[cat.id] ?? cat.name
                            : cat.name;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.folder_rounded,
                                color: catColor,
                              ),
                            ),
                            title: Text(
                              localizedName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: cat.isDefault
                                ? Text(
                                    t.defaultCategory,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit button
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: theme.colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    _showEditCategoryDialog(
                                      context,
                                      cat,
                                      t,
                                      theme,
                                      () {
                                        setSheetState(() {});
                                        onChanged();
                                      },
                                    );
                                  },
                                ),
                                // Delete button (само за не-default)
                                if (!cat.isDefault)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: innerContext,
                                        builder: (ctx) => AlertDialog(
                                          title: Text(t.deletion),
                                          content: Text(t.deleteCategoryMessage(cat.name)),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: Text(t.cancel),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.redAccent,
                                              ),
                                              child: Text(t.delete),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await categoryBox.delete(cat.id);
                                        setSheetState(() {});
                                        onChanged();
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Add category button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showAddCategoryDialog(context, t, theme, () {
                            setSheetState(() {});
                            onChanged();
                          });
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: Text(t.addCategory),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Показва диалог за добавяне на нова категория
  static void _showAddCategoryDialog(
      BuildContext context, AppText t, ThemeData theme, VoidCallback onComplete) {
    final controller = TextEditingController();
    Color selectedColor = Colors.blue;
    final categoryBox = Hive.box<Category>('categories');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(t.newCategory),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: t.name,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.color,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categoryColors.map((color) {
                          final isSelected = selectedColor.value == color.value;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(t.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      final id = DateTime.now().millisecondsSinceEpoch.toString();
                      final newCat = Category(
                        id: id,
                        name: name,
                        colorValue: selectedColor.value,
                        isDefault: false,
                      );
                      categoryBox.put(id, newCat);
                      Navigator.pop(ctx);
                      onComplete();
                    }
                  },
                  child: Text(t.add),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Показва диалог за редактиране на категория
  static void _showEditCategoryDialog(BuildContext context, Category cat,
      AppText t, ThemeData theme, VoidCallback onComplete) {
    final controller = TextEditingController(text: cat.name);
    Color selectedColor = Color(cat.colorValue);
    final categoryBox = Hive.box<Category>('categories');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(t.editCategory),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: controller,
                        enabled: !cat.isDefault, // Default категориите не могат да се преименуват
                        decoration: InputDecoration(
                          labelText: t.name,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          helperText: cat.isDefault
                              ? (t.defaultCategoryNameCannotChange)
                              : null,
                          helperMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.color,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categoryColors.map((color) {
                          final isSelected = selectedColor.value == color.value;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(t.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      // За default категории, запазваме оригиналното име
                      final updatedCat = Category(
                        id: cat.id,
                        name: cat.isDefault ? cat.name : name,
                        colorValue: selectedColor.value,
                        isDefault: cat.isDefault,
                      );
                      categoryBox.put(cat.id, updatedCat);
                      Navigator.pop(ctx);
                      onComplete();
                    }
                  },
                  child: Text(t.save),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
