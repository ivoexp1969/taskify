import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/group.dart';
import '../../services/group_service.dart';
import '../../utils/localization.dart';

/// Екран „Покани": показва кода едро + бутон Сподели (share_plus с
/// sharePositionOrigin fix-а за iPad). По избор бутон „Отвори списъка".
class GroupInviteScreen extends StatelessWidget {
  final Group group;
  final bool showOpenButton;

  const GroupInviteScreen({
    super.key,
    required this.group,
    this.showOpenButton = false,
  });

  Future<void> _share(BuildContext context) async {
    final lang = LanguageScope.of(context).locale.languageCode;
    final code = group.inviteCode ?? '';
    final text = GroupService.shareText(group.name, code, lang);

    // iOS popover anchor (share_plus иска non-zero sharePositionOrigin на iPad).
    final box = context.findRenderObject() as RenderBox?;
    final size = MediaQuery.of(context).size;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: 1,
            height: 1,
          );

    await Share.share(text, sharePositionOrigin: origin);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final code = group.inviteCode ?? '—';

    return Scaffold(
      appBar: AppBar(title: Text(t.inviteTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.group_add_rounded,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                group.name,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                t.inviteSubtitle,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Кодът — едро и copy-able.
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(code)),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SelectableText(
                        code,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.copy_rounded,
                          size: 20,
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => _share(context),
                icon: const Icon(Icons.share_rounded),
                label: Text(t.shareInvite),
              ),
              if (showOpenButton) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.sharedTab),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
