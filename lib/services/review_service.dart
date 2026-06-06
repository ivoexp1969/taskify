import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';

/// Сервиз за In-App Review с pre-dialog логика
/// 
/// Логика:
/// 1. Показва се след celebration анимация (завършена задача)
/// 2. Pre-dialog: "Харесва ли ти Taskify?" → Да/Не
/// 3. Ако "Да" → системен review prompt
/// 4. Ако "Не" → благодарим и затваряме (без negative review)
/// 5. Не се показва повече от веднъж на 30 дни
/// 6. Минимум 5 завършени задачи преди първо питане
class ReviewService {
  ReviewService._internal();

  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;

  final InAppReview _inAppReview = InAppReview.instance;

  // Настройки
  static const int _minCompletedTasks = 10;
  static const int _daysBetweenPrompts = 30;
  static const String _lastPromptKey = 'review_last_prompt_date';
  static const String _completedTasksKey = 'review_completed_tasks_count';
  static const String _hasRatedKey = 'review_has_rated';
  static const String _hasDeclinedKey = 'review_has_declined';

  /// Увеличава брояча на завършени задачи
  Future<void> incrementCompletedTasks() async {
    if (kIsWeb) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_completedTasksKey) ?? 0;
      await prefs.setInt(_completedTasksKey, current + 1);
      debugPrint('ReviewService: Completed tasks count: ${current + 1}');
    } catch (e) {
      debugPrint('ReviewService: Error incrementing tasks: $e');
    }
  }

  /// Проверява дали може да покаже review prompt
  Future<bool> canShowReviewPrompt() async {
    if (kIsWeb) return false;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Ако вече е оценил - не показваме
      if (prefs.getBool(_hasRatedKey) ?? false) {
        debugPrint('ReviewService: Already rated, skipping');
        return false;
      }
      
      // Проверка за минимален брой задачи
      final completedTasks = prefs.getInt(_completedTasksKey) ?? 0;
      if (completedTasks < _minCompletedTasks) {
        debugPrint('ReviewService: Not enough tasks ($completedTasks < $_minCompletedTasks)');
        return false;
      }
      
      // Проверка за време от последния prompt
      final lastPromptStr = prefs.getString(_lastPromptKey);
      if (lastPromptStr != null) {
        final lastPrompt = DateTime.parse(lastPromptStr);
        final daysSinceLastPrompt = DateTime.now().difference(lastPrompt).inDays;
        if (daysSinceLastPrompt < _daysBetweenPrompts) {
          debugPrint('ReviewService: Too soon ($daysSinceLastPrompt < $_daysBetweenPrompts days)');
          return false;
        }
      }
      
      // Проверка дали In-App Review е наличен
      final isAvailable = await _inAppReview.isAvailable();
      if (!isAvailable) {
        debugPrint('ReviewService: In-App Review not available');
        return false;
      }
      
      debugPrint('ReviewService: Can show review prompt');
      return true;
    } catch (e) {
      debugPrint('ReviewService: Error checking: $e');
      return false;
    }
  }

  /// Показва pre-dialog и евентуално review prompt
  /// Извиквай след celebration анимация
  Future<void> maybeShowReviewDialog(BuildContext context) async {
    if (kIsWeb) return;
    if (!context.mounted) return;
    
    final canShow = await canShowReviewPrompt();
    if (!canShow) return;
    
    // Запомняме датата на prompt-а
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPromptKey, DateTime.now().toIso8601String());
    
    if (!context.mounted) return;
    
    // Показваме pre-dialog
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ReviewPreDialog(),
    );
    
    if (result == true) {
      // Потребителят харесва приложението - показваме review
      await _showInAppReview();
      await prefs.setBool(_hasRatedKey, true);
    } else {
      // Потребителят не харесва или затвори - запомняме
      await prefs.setBool(_hasDeclinedKey, true);
    }
  }

  /// Показва системния In-App Review
  Future<void> _showInAppReview() async {
    try {
      await _inAppReview.requestReview();
      debugPrint('ReviewService: Review requested');
    } catch (e) {
      debugPrint('ReviewService: Error requesting review: $e');
    }
  }

  /// Ресетва всички данни (за тестване)
  Future<void> resetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPromptKey);
    await prefs.remove(_completedTasksKey);
    await prefs.remove(_hasRatedKey);
    await prefs.remove(_hasDeclinedKey);
    debugPrint('ReviewService: Reset complete');
  }
}

/// Pre-dialog преди In-App Review
class _ReviewPreDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final lang = Localizations.localeOf(context).languageCode;
    
    const titleMap = {'en': 'Do you like Taskify?', 'bg': 'Харесва ли ти Taskify?', 'de': 'Gefällt dir Taskify?', 'fr': 'Tu aimes Taskify?', 'it': 'Ti piace Taskify?', 'el': 'Σου αρέσει το Taskify;', 'es': '¿Te gusta Taskify?', 'pt': 'Gosta do Taskify?', 'ru': 'Нравится Taskify?', 'tr': 'Taskify hoşuna gidiyor mu?', 'ja': 'Taskifyは気に入りましたか？'};
    const subtitleMap = {'en': 'Your opinion matters to us!', 'bg': 'Твоето мнение е важно за нас!', 'de': 'Deine Meinung ist uns wichtig!', 'fr': 'Votre avis compte pour nous!', 'it': 'La tua opinione conta per noi!', 'el': 'Η γνώμη σας μετράει!', 'es': '¡Tu opinión nos importa!', 'pt': 'Sua opinião é importante!', 'ru': 'Ваше мнение важно для нас!', 'tr': 'Görüşünüz bizim için önemli!', 'ja': 'あなたのご意見が大切です！'};
    const negMap = {'en': 'Needs improvement', 'bg': 'Има какво да се подобри', 'de': 'Verbesserungsbedarf', 'fr': 'À améliorer', 'it': 'Da migliorare', 'el': 'Χρειάζεται βελτίωση', 'es': 'Necesita mejorar', 'pt': 'Precisa melhorar', 'ru': 'Нужны улучшения', 'tr': 'İyileştirme gerekli', 'ja': '改善が必要'};
    const posMap = {'en': 'Yes, I love it!', 'bg': 'Да, много!', 'de': 'Ja, ich liebe es!', 'fr': "Oui, j'adore!", 'it': 'Sì, lo adoro!', 'el': 'Ναι, μου αρέσει!', 'es': '¡Sí, me encanta!', 'pt': 'Sim, adoro!', 'ru': 'Да, мне нравится!', 'tr': 'Evet, bayıldım!', 'ja': 'はい、大好きです！'};
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(Icons.star_rounded, size: 48, color: Colors.amber),
      title: Text(
        titleMap[lang] ?? titleMap['en']!,
        textAlign: TextAlign.center,
      ),
      content: Text(
        subtitleMap[lang] ?? subtitleMap['en']!,
        textAlign: TextAlign.center,
        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.sentiment_dissatisfied_rounded),
          label: Text(
            negMap[lang] ?? negMap['en']!,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.favorite_rounded),
          label: Text(posMap[lang] ?? posMap['en']!),
        ),
      ],
    );
  }
}

/// Extension за лесно извикване след celebration
extension ReviewServiceExtension on ReviewService {
  /// Извикай след завършване на задача (след celebration анимация)
  Future<void> onTaskCompleted(BuildContext context) async {
    await incrementCompletedTasks();
    
    // Малко забавяне след celebration анимацията
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (context.mounted) {
      await maybeShowReviewDialog(context);
    }
  }
}
