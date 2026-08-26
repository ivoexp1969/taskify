import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../models/task.dart';
import '../../../models/category.dart';
import '../../../utils/localization.dart';
import '../../../services/pro_service.dart';
import '../../../services/ai_service.dart';
import '../../../services/ai_usage_service.dart';
import '../../../widgets/ai_limit.dart';

/// AI разбиване на задача на подзадачи (bottom sheet с редактируем преглед).
/// Изнесено от `task_screen.dart` без промяна на поведение.
///
/// [onApplied] се вика след запис на новите подзадачи (замества предишния
/// `setState(() {})` на екрана Задачи).
Future<void> showAiBreakdownSheet(
  BuildContext context,
  Task task,
  Box<Category> categoryBox, {
  required VoidCallback onApplied,
}) async {
  // ФАЗА 2: freemium — free до 3/ден (споделен пул), Pro неограничено.
  if (!ProService().isPro && !await AiUsageService.instance.canUse()) {
    if (context.mounted) await showAiLimitSheet(context);
    return;
  }

  final t = AppText.of(context);
  final theme = Theme.of(context);
  bool callInitiated = false;
  bool loading = true;
  bool hasError = false;
  final List<TextEditingController> controllers = [];

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (_, setS) {
          if (!callInitiated) {
            callInitiated = true;
            AiService.breakdownTask(
              task.title,
              categoryBox.values.map((c) => c.name).toList(),
              t.lang,
            ).then((r) {
              if (!sheetCtx.mounted) return;
              if (r != null) AiUsageService.instance.recordUse();
              setS(() {
                loading = false;
                hasError = r == null;
                if (r != null) {
                  controllers.clear();
                  controllers.addAll(
                    r.subtasks.map((s) => TextEditingController(text: s)),
                  );
                }
              });
            });
          }

          return Container(
            padding: EdgeInsets.fromLTRB(
              24, 20, 24, 24 + MediaQuery.of(sheetCtx).padding.bottom),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B2FF7), Color(0xFF2196F3)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.aiBreakdownTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                if (loading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            t.aiBreaking,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (hasError)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        t.aiError,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  )
                else if (!hasError) ...[
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...controllers.asMap().entries.map((e) {
                            final idx = e.key;
                            final ctrl = e.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.drag_indicator_rounded,
                                      size: 18,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: TextField(
                                      controller: ctrl,
                                      textCapitalization: TextCapitalization.sentences,
                                      style: const TextStyle(fontSize: 15),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        filled: true,
                                        fillColor: theme.colorScheme.outline.withValues(alpha: 0.08),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 20),
                                    color: Colors.redAccent,
                                    onPressed: () => setS(() {
                                      controllers.removeAt(idx).dispose();
                                    }),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final selected = controllers
                            .map((c) => c.text.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        if (selected.isEmpty) {
                          Navigator.pop(sheetCtx);
                          return;
                        }
                        final current = task.subtasksList;
                        final newList = [
                          ...current,
                          ...selected.map((s) => {'done': false, 'qty': 1, 'text': s}),
                        ];
                        task.setSubtasks(newList);
                        await task.save();
                        if (context.mounted) onApplied();
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B2FF7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        t.aiBreakdownApply,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );

  // Освобождаваме контролерите след затваряне на sheet-а
  for (final c in controllers) {
    c.dispose();
  }
}
