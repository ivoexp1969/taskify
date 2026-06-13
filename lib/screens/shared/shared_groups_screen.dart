import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/group.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../services/pro_service.dart';
import '../../utils/localization.dart';
import '../auth/login_screen.dart';
import '../paywall/paywall_screen.dart';
import 'group_invite_screen.dart';
import 'group_tasks_screen.dart';

/// Таб „Споделени" — корен. Изисква акаунт: нелогнат вижда покана за вход.
/// Логнат вижда групите си на живо + създай/присъедини.
class SharedGroupsScreen extends StatefulWidget {
  const SharedGroupsScreen({super.key});

  @override
  State<SharedGroupsScreen> createState() => _SharedGroupsScreenState();
}

class _SharedGroupsScreenState extends State<SharedGroupsScreen> {
  final GroupService _service = GroupService();

  Future<void> _showError(BuildContext context, GroupException e) async {
    final t = AppText.of(context);
    final msg = switch (e.code) {
      'owner-limit' => t.groupErrOwnerLimit,
      'member-limit' => t.groupErrMemberLimit,
      'task-limit' => t.groupErrTaskLimit,
      'invalid-code' => t.groupErrInvalidCode,
      _ => t.groupErrGeneric,
    };
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _createGroup() async {
    final t = AppText.of(context);

    // СЪЗДАВАНЕ е премиум функция (присъединяването е безплатно).
    if (!ProService().isPro) {
      final upgraded = await showPaywallIfNeeded(
        context,
        isFeatureAvailable: false,
        featureName: t.sharedTab,
      );
      if (!upgraded) return;
    }
    if (!mounted) return;

    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.newGroup),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: t.groupNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(t.createGroupAction),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    try {
      final group = await _service.createGroup(name);
      if (!mounted) return;
      // След създаване → екран „Покани" с кода.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupInviteScreen(group: group, showOpenButton: true),
        ),
      );
    } on GroupException catch (e) {
      if (mounted) await _showError(context, e);
    } catch (_) {
      if (mounted) await _showError(context, GroupException('generic'));
    }
  }

  Future<void> _joinGroup() async {
    final t = AppText.of(context);
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.joinWithCode),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: t.joinCodeHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(t.joinAction),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;

    try {
      final groupName = await _service.joinByCode(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.joinedGroup(groupName))),
        );
      }
    } on GroupException catch (e) {
      if (mounted) await _showError(context, e);
    } catch (_) {
      if (mounted) await _showError(context, GroupException('generic'));
    }
  }

  Widget _buildSignedOut(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_rounded,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              t.sharedSignInPrompt,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.login),
              label: Text(t.login),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsList(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final uid = AuthService().currentUser?.uid ?? '';

    return StreamBuilder<List<Group>>(
      stream: _service.watchMyGroups(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final groups = snap.data ?? const <Group>[];
        if (groups.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_rounded,
                      size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    t.sharedEmpty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _createGroup,
                    icon: const Icon(Icons.add),
                    label: Text(t.newGroup),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _joinGroup,
                    icon: const Icon(Icons.group_add_outlined),
                    label: Text(t.joinWithCode),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final g = groups[i];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.groups_rounded,
                      color: theme.colorScheme.onPrimaryContainer),
                ),
                title: Text(g.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(t.membersCount(g.memberCount)),
                trailing: g.isOwner(uid)
                    ? Chip(
                        label: Text(t.ownerLabel),
                        visualDensity: VisualDensity.compact,
                      )
                    : const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GroupTasksScreen(group: g),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    // Рендираме реактивно спрямо auth състоянието (вход/изход на живо).
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, authSnap) {
        final signedIn = AuthService().isLoggedIn;
        return Scaffold(
          appBar: AppBar(
            title: Text(t.sharedTab),
            actions: signedIn
                ? [
                    IconButton(
                      icon: const Icon(Icons.group_add_outlined),
                      tooltip: t.joinWithCode,
                      onPressed: _joinGroup,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: t.newGroup,
                      onPressed: _createGroup,
                    ),
                  ]
                : null,
          ),
          body: signedIn
              ? _buildGroupsList(context)
              : _buildSignedOut(context),
        );
      },
    );
  }
}
