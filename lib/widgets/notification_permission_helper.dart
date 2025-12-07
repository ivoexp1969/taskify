import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// Widget за заявка на разрешение за нотификации
/// На iOS Web трябва да има user interaction преди да покажем prompt
class NotificationPermissionHelper {
  static Future<bool> requestPermissionWithDialog(BuildContext context) async {
    final notificationService = NotificationService();
    
    // Провери дали вече има разрешение
    final alreadyEnabled = await notificationService.areNotificationsEnabled();
    if (alreadyEnabled) return true;

    // Покажи диалог
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Разреши нотификации'),
        content: const Text(
          'За да получаваш напомняния за задачите си, '
          'трябва да разрешиш нотификациите.\n\n'
          'Натисни "Разреши" и потвърди в следващия прозорец.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('По-късно'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Разреши'),
          ),
        ],
      ),
    );

    if (shouldRequest != true) return false;

    // Заяви разрешение
    final granted = await notificationService.requestPermission();
    
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Нотификациите не бяха разрешени. '
            'Можеш да ги разрешиш от настройките на браузъра.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }

    return granted;
  }

  /// Показва банер ако нотификациите не са разрешени
  static Widget buildPermissionBanner({
    required BuildContext context,
    required VoidCallback onDismiss,
  }) {
    if (!kIsWeb) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: NotificationService().areNotificationsEnabled(),
      builder: (context, snapshot) {
        if (snapshot.data == true) return const SizedBox.shrink();
        
        return MaterialBanner(
          content: const Text(
            'Разреши нотификациите за да получаваш напомняния',
          ),
          leading: const Icon(Icons.notifications_off, color: Colors.orange),
          actions: [
            TextButton(
              onPressed: onDismiss,
              child: const Text('По-късно'),
            ),
            TextButton(
              onPressed: () async {
                await requestPermissionWithDialog(context);
                onDismiss();
              },
              child: const Text('Разреши'),
            ),
          ],
        );
      },
    );
  }
}
