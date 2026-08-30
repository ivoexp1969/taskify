import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../models/task.dart';
import '../../../models/category.dart';
import '../../../utils/localization.dart';
import '../../../utils/category_colors.dart';
import '../../../utils/natural_language_parser.dart';
import '../../../services/ai_service.dart';
import '../../../services/ai_usage_service.dart';
import '../../../services/pro_service.dart';
import '../../../services/google_calendar_service.dart';
import '../../../services/ios_calendar_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/widget_service.dart';
import '../../../services/analytics_service.dart';
import '../../../services/ad_service.dart';
import '../../../widgets/ai_limit.dart';
import '../../../widgets/reminder_selector.dart';
import '../../paywall/paywall_screen.dart';
import '../shopping_list_screen.dart';
import '../sections/task_editor_widgets.dart';
import '../sections/task_format.dart';
import '../dialogs/date_picker_dialog.dart';

/// Редактор на задача (създаване/редакция) като bottom sheet. Изнесено verbatim
/// от `task_screen.dart` `_openTaskDialog` без промяна на поведение.
///
/// Persist на „последно ползвани" defaults се връща към екрана през callbacks:
/// [onCategoryDefaultChanged]/[onPriorityDefaultChanged]/[onRecurrenceDefaultChanged];
/// [onClearCategoryFilter] изчиства филтъра по категория (при създаване на нова);
/// [onChanged] обновява родителския екран (= предишния `setState`/`refreshParent`).
/// [parentContext] е контекстът на екрана (за paywall/AI-limit/Shopping навигация,
/// които трябва да преживеят затварянето на sheet-а).
class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({
    super.key,
    required this.parentContext,
    required this.existing,
    required this.onSave,
    required this.taskBox,
    required this.categoryBox,
    required this.aiParsingEnabled,
    required this.voiceEnabled,
    required this.initialCategoryId,
    required this.initialPriority,
    required this.initialRecurrence,
    required this.onCategoryDefaultChanged,
    required this.onPriorityDefaultChanged,
    required this.onRecurrenceDefaultChanged,
    required this.onClearCategoryFilter,
    required this.onChanged,
  });

  final BuildContext parentContext;
  final Task? existing;
  final Future<void> Function(Task draft)? onSave;
  final Box<Task> taskBox;
  final Box<Category> categoryBox;
  final bool aiParsingEnabled;
  final bool voiceEnabled;
  final String initialCategoryId;
  final int initialPriority;
  final String initialRecurrence;
  final ValueChanged<String> onCategoryDefaultChanged;
  final ValueChanged<int> onPriorityDefaultChanged;
  final ValueChanged<String> onRecurrenceDefaultChanged;
  final VoidCallback onClearCategoryFilter;
  final VoidCallback onChanged;

  /// Отваря редактора. Зарежда AI настройките (както преди — при всяко отваряне),
  /// после показва sheet-а и извиква [onChanged] след затваряне.
  static Future<void> show(
    BuildContext context, {
    Task? existing,
    Future<void> Function(Task draft)? onSave,
    required Box<Task> taskBox,
    required Box<Category> categoryBox,
    required String initialCategoryId,
    required int initialPriority,
    required String initialRecurrence,
    required ValueChanged<String> onCategoryDefaultChanged,
    required ValueChanged<int> onPriorityDefaultChanged,
    required ValueChanged<String> onRecurrenceDefaultChanged,
    required VoidCallback onClearCategoryFilter,
    required VoidCallback onChanged,
  }) async {
    // Зареждаме AI настройките при всяко отваряне, за да са актуални
    final aiParsingEnabled = await AiUsageService.instance.isParsingEnabled();
    final voiceEnabled = await AiUsageService.instance.isVoiceEnabled();
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => TaskEditorSheet(
        parentContext: context,
        existing: existing,
        onSave: onSave,
        taskBox: taskBox,
        categoryBox: categoryBox,
        aiParsingEnabled: aiParsingEnabled,
        voiceEnabled: voiceEnabled,
        initialCategoryId: initialCategoryId,
        initialPriority: initialPriority,
        initialRecurrence: initialRecurrence,
        onCategoryDefaultChanged: onCategoryDefaultChanged,
        onPriorityDefaultChanged: onPriorityDefaultChanged,
        onRecurrenceDefaultChanged: onRecurrenceDefaultChanged,
        onClearCategoryFilter: onClearCategoryFilter,
        onChanged: onChanged,
      ),
    );
    onChanged();
  }

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _titleController;
  late final AnimationController _micPulseController;
  late final SpeechToText _speech;
  bool _isListening = false;

  late DateTime tempDueDate;
  TimeOfDay? tempTime;
  late String tempCategoryId;
  late int tempPriority;
  late String tempRecurrence;
  late List<String> tempReminders;
  late List<Map<String, dynamic>> tempSubtasks;
  late String tempNotes;
  NlpResult? nlpSuggestion;
  bool aiLoading = false;

  @override
  void initState() {
    super.initState();
    _speech = SpeechToText();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    tempDueDate = existing?.dueDate ?? DateTime.now();
    if (existing != null &&
        (existing.dueDate.hour != 0 || existing.dueDate.minute != 0)) {
      tempTime = TimeOfDay.fromDateTime(existing.dueDate);
    }
    tempCategoryId = existing?.categoryId ?? widget.initialCategoryId;
    tempPriority = existing?.priority ?? widget.initialPriority;
    tempRecurrence = existing?.recurrence ?? widget.initialRecurrence;
    tempReminders = List<String>.from(existing?.remindersList ?? []);
    tempSubtasks = existing?.subtasksList ?? [];
    tempNotes = existing?.notes ?? '';
  }

  @override
  void dispose() {
    _micPulseController.dispose();
    _titleController.dispose();
    if (_isListening) _speech.cancel();
    super.dispose();
  }

  /// Обвивка около `setState`, за да остане тялото verbatim (беше `setSheetState`).
  void setSheetState(VoidCallback fn) => setState(fn);

  void _showAddCategoryDialog(StateSetter setDialogState) {
    final t = AppText.of(context);
    final TextEditingController controller = TextEditingController();
    Color selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setColorState) {
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
                        textCapitalization: TextCapitalization.sentences,
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
                        children: kCategoryColors.map((color) {
                          final isSelected = selectedColor.value == color.value;
                          return GestureDetector(
                            onTap: () {
                              setColorState(() {
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
                      if (!ProService().canAddCategory(widget.categoryBox.length)) {
                        Navigator.pop(ctx);
                        showPaywallIfNeeded(widget.parentContext, isFeatureAvailable: false);
                        return;
                      }
                      final id = DateTime.now().millisecondsSinceEpoch.toString();
                      final newCat = Category(
                        id: id,
                        name: name,
                        colorValue: selectedColor.value,
                        isDefault: false,
                      );
                      widget.categoryBox.put(id, newCat);
                      widget.onChanged();
                      setDialogState(() {
                        widget.onCategoryDefaultChanged(id);
                        widget.onClearCategoryFilter();
                      });
                      Navigator.pop(ctx);
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

  Future<Category?> _pickSchoolSubject(List<Category> subjects, AppText t) {
    return showModalBottomSheet<Category>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('🎒 ${schoolLabel[t.lang] ?? schoolLabel['en']!}',
                  style: Theme.of(ctx).textTheme.titleLarge),
            ),
            for (final s in subjects)
              ListTile(
                leading: CircleAvatar(
                    radius: 9, backgroundColor: Color(s.colorValue)),
                title: Text(s.name),
                onTap: () => Navigator.pop(ctx, s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final innerContext = context;
    final parentContext = widget.parentContext;
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final existing = widget.existing;
    final onSave = widget.onSave;
    final taskBox = widget.taskBox;
    final categoryBox = widget.categoryBox;
    final refreshParent = widget.onChanged;
    final aiParsingEnabled = widget.aiParsingEnabled;
    final voiceEnabled = widget.voiceEnabled;
    final bool isEditing = existing != null;

            final categories = categoryBox.values.toList();
            final languageController = LanguageScope.of(innerContext);
            final langCode = languageController.locale.languageCode;
            final bottomPadding = MediaQuery.of(innerContext).viewInsets.bottom;
            
            // Локали за гласово въвеждане
            const voiceLocales = {
              'en': 'en-US', 'bg': 'bg-BG', 'de': 'de-DE', 'fr': 'fr-FR', 
              'it': 'it-IT', 'el': 'el-GR', 'es': 'es-ES', 'pt': 'pt-PT',
              'ru': 'ru-RU', 'tr': 'tr-TR', 'ja': 'ja-JP',
            };
            final voiceLocale = voiceLocales[langCode] ?? 'en-US';
            // Apple Speech не поддържа български → скриваме микрофона на iOS за bg.
            final voiceUnsupported =
                !kIsWeb && Platform.isIOS && langCode == 'bg';

            // Взимаме цвета на избраната категория
            final selectedCat = categories.firstWhere(
              (c) => c.id == tempCategoryId,
              orElse: () => categories.first,
            );
            final categoryColor = Color(selectedCat.colorValue);

            void startPulse() => _micPulseController.repeat(reverse: true);
            void stopPulse() {
              _micPulseController.stop();
              _micPulseController.value = 0;
            }

            // AI parse — преизползвана и от бутона, и от авто-parse след диктовка.
            // fromVoice=true прави тихо падане към локалния NLP (без paywall/грешки),
            // за да не прекъсва гласовия поток.
            Future<void> runAiParse({bool fromVoice = false}) async {
              final text = _titleController.text.trim();
              if (text.isEmpty) return;
              // ФАЗА 2: AI е freemium. Free → до 3/ден (споделен пул с breakdown);
              // Pro → неограничено (canUse() винаги true). При изчерпана квота на
              // free: тих fallback към локалния текст при глас, иначе мек limit
              // sheet с CTA към paywall (input-ът в редактора се запазва).
              if (!ProService().isPro && !await AiUsageService.instance.canUse()) {
                if (fromVoice) return;
                if (parentContext.mounted) await showAiLimitSheet(parentContext);
                return;
              }
              setSheetState(() => aiLoading = true);
              final catNames = categories.map((c) => c.name).toList();
              final r = await AiService.parseTask(text, catNames, lang: langCode);
              if (!innerContext.mounted) return;
              setSheetState(() => aiLoading = false);
              if (r == null) {
                if (!fromVoice) {
                  ScaffoldMessenger.of(innerContext).showSnackBar(
                      SnackBar(content: Text(t.aiError)));
                }
                return;
              }
              await AiUsageService.instance.recordUse();
              setSheetState(() {
                _titleController.text = r.title;
                tempPriority = r.priority;
                widget.onPriorityDefaultChanged(r.priority);
                if (r.recurring != null) {
                  tempRecurrence = r.recurring!;
                  widget.onRecurrenceDefaultChanged(r.recurring!);
                }
                if (r.categoryName != null) {
                  final catNameLower = r.categoryName!.toLowerCase();
                  final matched = categories.where(
                    (c) => c.name.toLowerCase() == catNameLower,
                  );
                  if (matched.isNotEmpty) {
                    tempCategoryId = matched.first.id;
                    widget.onCategoryDefaultChanged(matched.first.id);
                  }
                }
                // AI time fallback — само ако NLP не е хванал час
                if (tempTime == null && r.time != null) {
                  final parts = r.time!.split(':');
                  if (parts.length == 2) {
                    final h = int.tryParse(parts[0]);
                    final m = int.tryParse(parts[1]);
                    if (h != null && m != null && h <= 23 && m <= 59) {
                      tempTime = TimeOfDay(hour: h, minute: m);
                      tempDueDate = DateTime(
                        tempDueDate.year, tempDueDate.month, tempDueDate.day, h, m,
                      );
                    }
                  }
                }
              });
            }

            // AI разбиване на подзадачи — пълни ЛОКАЛНИЯ списък tempSubtasks (не
            // Hive), за да работи и при редактиране, и в СПОДЕЛЕНИТЕ задачи
            // (записът минава през onSave → Firestore GroupTask).
            Future<void> runAiBreakdown() async {
              final text = _titleController.text.trim();
              if (text.isEmpty) return;
              // ФАЗА 2: breakdown също е freemium (споделя 3/ден пула с parse).
              if (!ProService().isPro && !await AiUsageService.instance.canUse()) {
                if (parentContext.mounted) await showAiLimitSheet(parentContext);
                return;
              }
              setSheetState(() => aiLoading = true);
              final catNames = categories.map((c) => c.name).toList();
              final r = await AiService.breakdownTask(text, catNames, langCode);
              if (!innerContext.mounted) return;
              setSheetState(() => aiLoading = false);
              if (r == null || r.subtasks.isEmpty) {
                if (innerContext.mounted) {
                  ScaffoldMessenger.of(innerContext).showSnackBar(
                      SnackBar(content: Text(t.aiError)));
                }
                return;
              }
              await AiUsageService.instance.recordUse();
              setSheetState(() {
                for (final s in r.subtasks) {
                  final txt = s.trim();
                  if (txt.isNotEmpty) {
                    tempSubtasks.add({'done': false, 'qty': 1, 'text': txt});
                  }
                }
              });
            }
            return Container(
              height: MediaQuery.of(innerContext).size.height * 0.85,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
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
                            color: categoryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEditing ? Icons.edit_rounded : Icons.add_task_rounded,
                            color: categoryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          isEditing 
                              ? (t.editTask)
                              : t.newTask,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            _titleController.clear();
                            Navigator.pop(innerContext);
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding + 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Заглавие
                          TextField(
                            controller: _titleController,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: t.whatNeedsToBeDone,
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                fontWeight: FontWeight.normal,
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.outline.withValues(alpha: 0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(
                                Icons.title_rounded,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                              suffixIcon: (!voiceEnabled || voiceUnsupported) ? null : GestureDetector(
                                onTap: () async {
                                  if (_isListening) {
                                    await _speech.stop();
                                    stopPulse();
                                    setSheetState(() => _isListening = false);
                                    return;
                                  }
                                  final available = await _speech.initialize(
                                    onError: (_) {
                                      stopPulse();
                                      setSheetState(() => _isListening = false);
                                    },
                                    onStatus: (s) {
                                      if (s == 'done' || s == 'notListening') {
                                        stopPulse();
                                        setSheetState(() => _isListening = false);
                                      }
                                    },
                                  );
                                  if (!available) {
                                    if (innerContext.mounted) {
                                      ScaffoldMessenger.of(innerContext).showSnackBar(
                                        SnackBar(content: Text(t.voiceError)),
                                      );
                                    }
                                    return;
                                  }
                                  // Apple Speech не поддържа всички езици (напр. bg-BG
                                  // липсва). Ако моделът за текущия език не е наличен,
                                  // диктовката връща грешен език — затова спираме и
                                  // информираме, вместо да разпознаваме на грешен език.
                                  bool localeSupported = true;
                                  try {
                                    final installed = await _speech.locales();
                                    localeSupported = installed.any((l) =>
                                        l.localeId.replaceAll('_', '-') == voiceLocale);
                                  } catch (_) {}
                                  if (!localeSupported) {
                                    if (innerContext.mounted) {
                                      ScaffoldMessenger.of(innerContext).showSnackBar(
                                        SnackBar(content: Text(t.voiceLangUnsupported)),
                                      );
                                    }
                                    return;
                                  }
                                  setSheetState(() => _isListening = true);
                                  startPulse();
                                  await _speech.listen(
                                    onResult: (result) {
                                      if (result.finalResult) {
                                        final words = result.recognizedWords.trim();
                                        stopPulse();
                                        if (words.isEmpty) {
                                          setSheetState(() => _isListening = false);
                                          if (innerContext.mounted) {
                                            ScaffoldMessenger.of(innerContext).showSnackBar(
                                              SnackBar(content: Text(t.voiceNoSpeech)),
                                            );
                                          }
                                          return;
                                        }
                                        setSheetState(() {
                                          _isListening = false;
                                          _titleController.text = words;
                                          _titleController.selection = TextSelection.collapsed(
                                            offset: words.length,
                                          );
                                          final nlp = NaturalLanguageParser.parse(words, langCode);
                                          nlpSuggestion = nlp;
                                          if (nlp != null) {
                                            tempDueDate = DateTime(
                                              nlp.date.year, nlp.date.month, nlp.date.day,
                                              nlp.time?.hour ?? tempDueDate.hour,
                                              nlp.time?.minute ?? tempDueDate.minute,
                                            );
                                            if (nlp.time != null) tempTime = nlp.time;
                                          }
                                        });
                                        // Авто-parse след диктовка (глас→parse→preview),
                                        // ако AI парсването е вкл. Тихо пада към локалния NLP по-горе.
                                        if (aiParsingEnabled) runAiParse(fromVoice: true);
                                      } else {
                                        setSheetState(() {
                                          _titleController.text = result.recognizedWords;
                                        });
                                      }
                                    },
                                    localeId: voiceLocale,
                                    listenFor: const Duration(seconds: 30),
                                    pauseFor: const Duration(seconds: 3),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: _isListening
                                      ? ScaleTransition(
                                          scale: Tween<double>(begin: 1.0, end: 1.25).animate(
                                            CurvedAnimation(
                                              parent: _micPulseController,
                                              curve: Curves.easeInOut,
                                            ),
                                          ),
                                          child: const Icon(Icons.mic, color: Colors.redAccent),
                                        )
                                      : Icon(
                                          Icons.mic_none_rounded,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                        ),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                            ),
                            onChanged: (value) {
                              final result = NaturalLanguageParser.parse(value, langCode);
                              setSheetState(() {
                                nlpSuggestion = result;
                                if (result != null) {
                                  tempDueDate = DateTime(
                                    result.date.year, result.date.month, result.date.day,
                                    result.time?.hour ?? tempDueDate.hour,
                                    result.time?.minute ?? tempDueDate.minute,
                                  );
                                  if (result.time != null) tempTime = result.time;
                                }
                              });
                            },
                          ),
                          if (nlpSuggestion != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 16, color: categoryColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    nlpSuggestion!.label,
                                    style: TextStyle(
                                      color: categoryColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setSheetState(() => nlpSuggestion = null),
                                    child: Icon(Icons.close_rounded, size: 16, color: categoryColor.withValues(alpha: 0.7)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else
                            const SizedBox(height: 8),
                          // AI Parse button
                          if (aiParsingEnabled) Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ФАЗА 2: дискретен брояч „използвани/лимит" —
                                // само за free (за Pro връща SizedBox.shrink).
                                const AiQuotaChip(),
                                aiLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : GestureDetector(
                                    onTap: () => runAiParse(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF7B2FF7), Color(0xFF2196F3)],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text(
                                            t.aiParse,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Секция: Категория
                          taskSectionLabel(t.category, Icons.folder_outlined, theme),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              // Училищните предмети (subj_*) НЕ се показват в
                              // плоския ред — те са зад синтетичния чип „🎒 Училище"
                              // по-долу (за да не задръстват селектора).
                              ...categories
                                  .where((c) => !c.id.startsWith('subj_'))
                                  .map((cat) {
                                final isSelected = cat.id == tempCategoryId;
                                final catColor = Color(cat.colorValue);
                                return GestureDetector(
                                  onTap: () {
                                    setSheetState(() {
                                      tempCategoryId = cat.id;
                                      widget.onCategoryDefaultChanged(cat.id);
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? catColor.withValues(alpha: 0.2)
                                          : theme.colorScheme.outline.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? catColor : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: catColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          localizedCategoryName(cat, t),
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            color: isSelected
                                                ? catColor
                                                : theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              // Синтетичен чип „🎒 Училище" — само ако ученикът е
                              // добавил предмети. Отваря шийт за избор на предмет;
                              // крайната задача се категоризира по конкретния предмет.
                              if (categories.any((c) => c.id.startsWith('subj_')))
                                Builder(builder: (_) {
                                  final subjects = categories
                                      .where((c) => c.id.startsWith('subj_'))
                                      .toList();
                                  final sel = subjects
                                      .where((c) => c.id == tempCategoryId);
                                  final selSubj = sel.isEmpty ? null : sel.first;
                                  final schoolColor = selSubj != null
                                      ? Color(selSubj.colorValue)
                                      : const Color(0xFF6A3DE8);
                                  final isSel = selSubj != null;
                                  final label = selSubj != null
                                      ? '🎒 ${selSubj.name}'
                                      : '🎒 ${schoolLabel[t.lang] ?? schoolLabel['en']!}';
                                  return GestureDetector(
                                    onTap: () async {
                                      final picked = await _pickSchoolSubject(
                                          subjects, t);
                                      if (picked != null) {
                                        setSheetState(() {
                                          tempCategoryId = picked.id;
                                          widget.onCategoryDefaultChanged(picked.id);
                                        });
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? schoolColor.withValues(alpha: 0.2)
                                            : theme.colorScheme.outline
                                                .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: isSel
                                                ? schoolColor
                                                : Colors.transparent,
                                            width: 2),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(label,
                                              style: TextStyle(
                                                  fontWeight: isSel
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  color: isSel
                                                      ? schoolColor
                                                      : theme.colorScheme
                                                          .onSurface)),
                                          const SizedBox(width: 4),
                                          Icon(Icons.expand_more,
                                              size: 18,
                                              color: isSel
                                                  ? schoolColor
                                                  : theme.colorScheme.onSurface
                                                      .withValues(alpha: 0.5)),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              // Add category button
                              GestureDetector(
                                onTap: () => _showAddCategoryDialog(setSheetState),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                                      style: BorderStyle.solid,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add_rounded,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        t.newCat,
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Секция: Приоритет
                          taskSectionLabel(t.priority, Icons.flag_outlined, theme),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              taskPriorityButton(
                                label: t.low,
                                value: 0,
                                selected: tempPriority == 0,
                                color: Colors.green,
                                onTap: () => setSheetState(() {
                                  tempPriority = 0;
                                  widget.onPriorityDefaultChanged(0);
                                }),
                              ),
                              const SizedBox(width: 10),
                              taskPriorityButton(
                                label: t.medium,
                                value: 1,
                                selected: tempPriority == 1,
                                color: Colors.orange,
                                onTap: () => setSheetState(() {
                                  tempPriority = 1;
                                  widget.onPriorityDefaultChanged(1);
                                }),
                              ),
                              const SizedBox(width: 10),
                              taskPriorityButton(
                                label: t.high,
                                value: 2,
                                selected: tempPriority == 2,
                                color: Colors.redAccent,
                                onTap: () => setSheetState(() {
                                  tempPriority = 2;
                                  widget.onPriorityDefaultChanged(2);
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Секция: Дата и час
                          taskSectionLabel(t.dateAndTime, Icons.calendar_today_outlined, theme),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final picked = await pickTaskDate(innerContext, tempDueDate);
                                    if (picked != null) {
                                      setSheetState(() {
                                        tempDueDate = DateTime(
                                          picked.year,
                                          picked.month,
                                          picked.day,
                                          tempTime?.hour ?? 0,
                                          tempTime?.minute ?? 0,
                                        );
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          size: 20,
                                          color: categoryColor,
                                        ),
                                        const SizedBox(width: 10),
                                        Flexible(
                                          child: Text(
                                            formatDate(tempDueDate),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: innerContext,
                                      initialTime: tempTime ?? TimeOfDay.now(),
                                    );
                                    if (picked != null) {
                                      setSheetState(() {
                                        tempTime = picked;
                                        tempDueDate = DateTime(
                                          tempDueDate.year,
                                          tempDueDate.month,
                                          tempDueDate.day,
                                          picked.hour,
                                          picked.minute,
                                        );
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 20,
                                          color: categoryColor,
                                        ),
                                        const SizedBox(width: 10),
                                        Flexible(
                                          child: Text(
                                            tempTime != null 
                                                ? formatTime(tempTime)
                                                : (t.time),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: tempTime != null
                                                  ? theme.colorScheme.onSurface
                                                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Секция: Повторение
                          taskSectionLabel(t.repeat, Icons.repeat_rounded, theme),
                          const SizedBox(height: 12),
                          taskDropdownTile(
                            value: tempRecurrence,
                            items: {
                              'none': t.noRepeat,
                              'daily': t.daily,
                              'weekly': t.weekly,
                              'monthly': t.monthly,
                              'yearly': t.yearly,
                            },
                            theme: theme,
                            onChanged: (val) => setSheetState(() {
                              tempRecurrence = val;
                              widget.onRecurrenceDefaultChanged(val);
                            }),
                          ),
                          const SizedBox(height: 24),

                          // Секция: Напомняне
                          taskSectionLabel(
                            t.reminders,
                            Icons.notifications_outlined,
                            theme,
                          ),
                          const SizedBox(height: 12),
                          ReminderSelector(
                            selectedReminders: tempReminders,
                            onChanged: (list) => setSheetState(() {
                              tempReminders = list;
                            }),
                            langCode: langCode,
                            theme: theme,
                          ),
                          const SizedBox(height: 24),

                          // Секция: Подзадачи
                          taskSectionLabel(
                            t.subtasks,
                            Icons.checklist_rounded,
                            theme,
                          ),
                          const SizedBox(height: 12),
                          // AI разбиване на подзадачи — ВИНАГИ видим (работи и в
                          // споделените задачи); Pro/лимит се проверяват в runAiBreakdown.
                          Align(
                              alignment: Alignment.centerLeft,
                              child: aiLoading
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 4),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : GestureDetector(
                                      onTap: () => runAiBreakdown(),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF7B2FF7), Color(0xFF2196F3)],
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.auto_awesome,
                                                size: 14, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text(
                                              t.aiBreakdownTitle,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                          ),
                          const SizedBox(height: 12),
                          // Списък с подзадачи
                          ...tempSubtasks.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final subtask = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setSheetState(() {
                                        tempSubtasks[idx]['done'] = !(tempSubtasks[idx]['done'] as bool);
                                      });
                                    },
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: subtask['done'] == true
                                            ? categoryColor
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: subtask['done'] == true
                                              ? categoryColor
                                              : theme.colorScheme.outline.withValues(alpha: 0.3),
                                          width: 2,
                                        ),
                                      ),
                                      child: subtask['done'] == true
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      subtask['text'] as String,
                                      style: TextStyle(
                                        fontSize: 15,
                                        decoration: subtask['done'] == true
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: subtask['done'] == true
                                            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                    onPressed: () {
                                      setSheetState(() {
                                        tempSubtasks.removeAt(idx);
                                      });
                                    },
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            );
                          }),
                          // Бутон за добавяне на подзадача
                          GestureDetector(
                            onTap: () async {
                              final controller = TextEditingController();
                              final result = await showDialog<String>(
                                context: innerContext,
                                builder: (ctx) => AlertDialog(
                                  title: Text(t.newSubtask),
                                  content: TextField(
                                    controller: controller,
                                    autofocus: true,
                                    textCapitalization: TextCapitalization.sentences,
                                    decoration: InputDecoration(
                                      hintText: t.enterSubtask,
                                    ),
                                    onSubmitted: (val) => Navigator.pop(ctx, val),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text(t.cancel),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, controller.text),
                                      child: Text(t.add),
                                    ),
                                  ],
                                ),
                              );
                              if (result != null && result.trim().isNotEmpty) {
                                setSheetState(() {
                                  tempSubtasks.add({'done': false, 'text': result.trim()});
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 20,
                                    color: categoryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    t.addSubtask,
                                    style: TextStyle(
                                      color: categoryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Секция: Бележки
                          Text(
                            t.notes,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final controller = TextEditingController(text: tempNotes);
                              final result = await showDialog<String>(
                                context: innerContext,
                                builder: (ctx) => AlertDialog(
                                  title: Text(t.notes),
                                  content: TextField(
                                    controller: controller,
                                    maxLines: 6,
                                    autofocus: true,
                                    textCapitalization: TextCapitalization.sentences,
                                    decoration: InputDecoration(
                                      hintText: t.additionalInfo,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text(t.cancel),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, controller.text),
                                      child: Text(t.save),
                                    ),
                                  ],
                                ),
                              );
                              if (result != null) {
                                setSheetState(() {
                                  tempNotes = result;
                                });
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.outline.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: tempNotes.trim().isNotEmpty
                                    ? Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    tempNotes.trim().isNotEmpty ? Icons.note_rounded : Icons.note_add_outlined,
                                    size: 20,
                                    color: tempNotes.trim().isNotEmpty
                                        ? Colors.amber.shade700
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      tempNotes.trim().isNotEmpty
                                          ? tempNotes.trim()
                                          : (t.addNote),
                                      style: TextStyle(
                                        color: tempNotes.trim().isNotEmpty
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (tempNotes.trim().isNotEmpty)
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  // Bottom action button
                  Container(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(innerContext).padding.bottom),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () async {
                          final titleText = _titleController.text.trim();
                          if (titleText.isEmpty) return;

                          final dueDateToSave = DateTime(
                            tempDueDate.year,
                            tempDueDate.month,
                            tempDueDate.day,
                            tempTime?.hour ?? 0,
                            tempTime?.minute ?? 0,
                          );

                          final recurrenceToSave =
                              tempRecurrence == 'none' ? null : tempRecurrence;

                          // Външен режим (напр. споделени групи): НЕ пипаме Hive/
                          // календар/нотификации — само връщаме готовата задача през
                          // callback-а. Личният път (else по-долу) остава непроменен.
                          if (onSave != null) {
                            final draft = existing ??
                                Task(
                                  title: titleText,
                                  dueDate: dueDateToSave,
                                  categoryId: tempCategoryId,
                                  priority: tempPriority,
                                );
                            draft
                              ..title = titleText
                              ..dueDate = dueDateToSave
                              ..categoryId = tempCategoryId
                              ..priority = tempPriority
                              ..recurrence = recurrenceToSave
                              ..notes = tempNotes.trim().isEmpty
                                  ? null
                                  : tempNotes.trim();
                            draft.setReminders(tempReminders);
                            draft.setSubtasks(tempSubtasks);
                            _titleController.clear();
                            if (innerContext.mounted) Navigator.pop(innerContext);
                            await onSave(draft);
                            return;
                          }

                          Task? _openShoppingAfterCreate;
                          if (isEditing) {
                            existing!
                              ..title = titleText
                              ..dueDate = dueDateToSave
                              ..categoryId = tempCategoryId
                              ..priority = tempPriority
                              ..recurrence = recurrenceToSave
                              ..notes = tempNotes.trim().isEmpty ? null : tempNotes.trim();
                            existing.setReminders(tempReminders);
                            existing.setSubtasks(tempSubtasks);
                            if (existing.template == null || existing.template == 'shopping') { existing.template = tempCategoryId == 'shopping' ? 'shopping' : null; }
                            await existing.save();
                            // Google Calendar: обнови вече свързаното събитие
                            // (важи и за импортирани задачи) → без дублиране.
                            if (GoogleCalendarService().isConnected &&
                                !IosCalendarService.exportEnabled &&
                                existing.googleCalendarEventId != null) {
                              await GoogleCalendarService().updateCalendarEvent(
                                  existing.googleCalendarEventId!, existing);
                            }
                            // Apple Calendar (export-only): създава или обновява
                            // СЪЩОТО събитие по appleEventId → без дублиране.
                            if (!kIsWeb && IosCalendarService.exportEnabled) {
                              await IosCalendarService().syncTask(existing);
                            }
                            await NotificationService().scheduleForTask(existing);
                          } else {
                            // Paywall check — free limit 50 tasks
                            if (!ProService().canAddTask(taskBox.length)) {
                              Navigator.pop(innerContext);
                              if (parentContext.mounted) showPaywallIfNeeded(parentContext, isFeatureAvailable: false);
                              return;
                            }
                            // Auto-detect template от category
                            final String? autoTemplate = tempCategoryId == 'shopping' ? 'shopping' : null;
                            
                            final newTask = Task(
                              title: titleText,
                              dueDate: dueDateToSave,
                              categoryId: tempCategoryId,
                              priority: tempPriority,
                              recurrence: recurrenceToSave,
                              reminders: tempReminders.isEmpty ? null : tempReminders,
                              notes: tempNotes.trim().isEmpty ? null : tempNotes.trim(),
                              template: autoTemplate,
                            );
                            newTask.setSubtasks(tempSubtasks);
                            await taskBox.add(newTask);
                            AnalyticsService().logTaskCreated(newTask);
                            AdService().onUserAction();
                            // Google Calendar sync (само ако Apple не е активен —
                            // източниците са взаимно изключващи се).
                            if (GoogleCalendarService().isConnected && !IosCalendarService.exportEnabled) {
                              final eventId = await GoogleCalendarService().addTaskToCalendar(newTask);
                              if (eventId != null) {
                                newTask.googleCalendarEventId = eventId;
                                await newTask.save();
                              }
                            }
                            // Apple Calendar (export-only) — само ако е избран
                            // Apple източник (взаимно изключващ се с Google).
                            if (!kIsWeb && IosCalendarService.exportEnabled) {
                              await IosCalendarService().syncTask(newTask);
                            }

                            await NotificationService().scheduleForTask(newTask);
                            _openShoppingAfterCreate = autoTemplate == 'shopping' ? newTask : null;
                          }

                          await WidgetService.updateWidget();
                          _titleController.clear();
                          refreshParent();  // Обновяваме главния екран
                          if (innerContext.mounted) Navigator.pop(innerContext);
                          if (_openShoppingAfterCreate != null && parentContext.mounted) {
                            Navigator.push(parentContext, MaterialPageRoute(
                              builder: (_) => ShoppingListScreen(task: _openShoppingAfterCreate!),
                            )).then((_) => refreshParent());
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: categoryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isEditing
                              ? (t.saveChanges)
                              : (t.addTask),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
  }
}
