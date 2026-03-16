import 'package:flutter/material.dart';
import '../../utils/localization.dart';

class _TypeItem {
  final String type;
  final IconData icon;
  final Color lightBg;
  final Color darkBg;
  final Color lightIcon;
  final Color darkIcon;
  final String Function(AppText) label;

  const _TypeItem({
    required this.type,
    required this.icon,
    required this.lightBg,
    required this.darkBg,
    required this.lightIcon,
    required this.darkIcon,
    required this.label,
  });
}

class TaskTypeSelector {
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _Sheet(),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet();

  static final List<_TypeItem> _types = [
    _TypeItem(
      type: 'task',
      icon: Icons.check_circle_outline_rounded,
      lightBg: const Color(0xFFEEEDFE),
      darkBg: const Color(0xFF1e1a3a),
      lightIcon: const Color(0xFF534AB7),
      darkIcon: const Color(0xFFAFA9EC),
      label: (t) => t.typeTask,
    ),
    _TypeItem(
      type: 'shopping',
      icon: Icons.shopping_cart_outlined,
      lightBg: const Color(0xFFE1F5EE),
      darkBg: const Color(0xFF0e2520),
      lightIcon: const Color(0xFF0F6E56),
      darkIcon: const Color(0xFF5DCAA5),
      label: (t) => t.typeShopping,
    ),
    _TypeItem(
      type: 'birthday',
      icon: Icons.cake_outlined,
      lightBg: const Color(0xFFFBEAF0),
      darkBg: const Color(0xFF261220),
      lightIcon: const Color(0xFF993556),
      darkIcon: const Color(0xFFED93B1),
      label: (t) => t.typeBirthday,
    ),
    _TypeItem(
      type: 'meeting',
      icon: Icons.phone_outlined,
      lightBg: const Color(0xFFE6F1FB),
      darkBg: const Color(0xFF0d1e2e),
      lightIcon: const Color(0xFF185FA5),
      darkIcon: const Color(0xFF85B7EB),
      label: (t) => t.typeMeeting,
    ),
    _TypeItem(
      type: 'workout',
      icon: Icons.fitness_center_outlined,
      lightBg: const Color(0xFFFAEEDA),
      darkBg: const Color(0xFF281e0d),
      lightIcon: const Color(0xFF854F0B),
      darkIcon: const Color(0xFFF0B84A),
      label: (t) => t.typeWorkout,
    ),
    _TypeItem(
      type: 'payment',
      icon: Icons.account_balance_wallet_outlined,
      lightBg: const Color(0xFFEAF3DE),
      darkBg: const Color(0xFF182210),
      lightIcon: const Color(0xFF3B6D11),
      darkIcon: const Color(0xFF97C459),
      label: (t) => t.typePayment,
    ),
    _TypeItem(
      type: 'travel',
      icon: Icons.flight_outlined,
      lightBg: const Color(0xFFEEEDFE),
      darkBg: const Color(0xFF1a1535),
      lightIcon: const Color(0xFF3C3489),
      darkIcon: const Color(0xFFC8C4F4),
      label: (t) => t.typeTravel,
    ),
    _TypeItem(
      type: 'gift',
      icon: Icons.card_giftcard_outlined,
      lightBg: const Color(0xFFFAECE7),
      darkBg: const Color(0xFF2a1208),
      lightIcon: const Color(0xFF993C1D),
      darkIcon: const Color(0xFFF0997B),
      label: (t) => t.typeGift,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppText.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF13131f) : theme.colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t.newEntry,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: _types.length,
            itemBuilder: (ctx, i) {
              final item = _types[i];
              final bg = isDark ? item.darkBg : item.lightBg;
              final iconColor = isDark ? item.darkIcon : item.lightIcon;
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, item.type),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 28,
                      child: Text(
                        item.label(t),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withOpacity(0.75),
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
