import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../utils/localization.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';

class DeleteAccountFlow {
  static Future<void> start(BuildContext context) async {
    // Step 1: First confirmation
    final t1 = AppText.of(context);
    if (!await _confirm1(context, t1)) return;

    // Step 2: Gather Firestore stats + second confirmation
    final stats = await _gatherStats();
    if (!context.mounted) return;
    final t2 = AppText.of(context);
    if (!await _confirm2(context, t2, stats)) return;

    // Step 3: Subscription notice
    if (!context.mounted) return;
    final t3 = AppText.of(context);
    if (!await _subscriptionNotice(context, t3)) return;

    // Step 4: Re-authenticate with email/password
    if (!context.mounted) return;
    final t4 = AppText.of(context);
    final password = await _askPassword(context, t4);
    if (password == null) return;

    // Step 5: Show progress dialog
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(AppText.of(context).deleteAccountInProgress)),
          ],
        ),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final email = user.email!;
      final uid = user.uid;

      // Re-auth
      final cred = EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(cred);

      // Delete all Firestore data
      await _deleteFirestoreData(uid);

      // Revoke Google Calendar OAuth tokens
      try {
        await GoogleSignIn.instance.signOut();
        await GoogleSignIn.instance.disconnect();
      } catch (_) {}

      // Delete Firebase Auth user
      await user.delete();

      // Чистим запазените credentials за тихия повторен вход.
      await AuthService().clearSavedCredentials();

      // Close progress + navigate to HomeScreen (root) — remove all routes.
      // НЕ навигираме към LoginScreen, защото тя прави pop() при успешен login,
      // което би оставило празен стек → черен екран.
      if (context.mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // close progress
        _showError(context, AppText.of(context), e);
      }
    }
  }

  static Future<bool> _confirm1(BuildContext context, AppText t) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteAccountConfirm1Title),
        content: Text(t.deleteAccountConfirm1Body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t.continueAction),
          ),
        ],
      ),
    );
    return result == true;
  }

  static Future<bool> _confirm2(
      BuildContext context, AppText t, Map<String, int> stats) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteAccountConfirm2Title),
        content: Text(t.deleteAccountConfirm2Body(
          stats['tasks'] ?? 0,
          stats['categories'] ?? 0,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result == true;
  }

  static Future<bool> _subscriptionNotice(BuildContext context, AppText t) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteAccountSubscriptionTitle),
        content: Text(t.deleteAccountSubscriptionBody),
        actions: [
          TextButton(
            onPressed: () async {
              final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Text(t.manageSubscriptions),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t.continueAction),
          ),
        ],
      ),
    );
    return result == true;
  }

  static Future<String?> _askPassword(BuildContext context, AppText t) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        bool obscure = true;
        return StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
            title: Text(t.deleteAccountReauthTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.deleteAccountReauthBody),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: t.password,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(t.delete,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  static Future<Map<String, int>> _gatherStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {'tasks': 0, 'categories': 0};
    try {
      final tasks = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .count()
          .get();
      final cats = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('categories')
          .count()
          .get();
      return {
        'tasks': tasks.count ?? 0,
        'categories': cats.count ?? 0,
      };
    } catch (_) {
      return {'tasks': 0, 'categories': 0};
    }
  }

  static Future<void> _deleteFirestoreData(String uid) async {
    final db = FirebaseFirestore.instance;

    final tasksSnap = await db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .get();
    for (final doc in tasksSnap.docs) {
      await doc.reference.delete();
    }

    final catsSnap = await db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .get();
    for (final doc in catsSnap.docs) {
      await doc.reference.delete();
    }

    await db.collection('users').doc(uid).delete();
  }

  static void _showError(BuildContext context, AppText t, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.deleteAccountError),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
