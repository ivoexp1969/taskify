import 'package:flutter/material.dart';

import '../task/task_screen.dart';
import '../calendar/calendar_screen.dart';
import '../settings/settings_screen.dart';
import '../../utils/localization.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../services/pro_service.dart';
import '../paywall/paywall_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final ProService _proService = ProService();

  late final List<Widget> _screens = const [
    TaskScreen(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _proService.addListener(_onProStatusChanged);
    _showTrialWelcome();
  }

  @override
  void dispose() {
    _proService.removeListener(_onProStatusChanged);
    super.dispose();
  }

  void _onProStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showTrialWelcome() {
    if (_proService.isTrial && _proService.trialDaysLeft >= 13) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final languageController = LanguageScope.of(context);
        final isBg = languageController.locale.languageCode == 'bg';
        
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.celebration_rounded, size: 48, color: Colors.amber),
            title: Text(isBg ? 'Добре дошъл!' : 'Welcome!'),
            content: Text(
              isBg 
                  ? 'Имаш 14 дни безплатен Pro достъп!\n\nИзползвай всички функции и виж как Taskify ще ти помогне да си по-продуктивен.'
                  : 'You have 14 days free Pro access!\n\nTry all features and see how Taskify can help you be more productive.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isBg ? 'Страхотно!' : 'Awesome!'),
              ),
            ],
          ),
        );
      });
    }
  }

  void _onDestinationSelected(int index) async {
    if (index == 1 && !_proService.canUseCalendar) {
      final languageController = LanguageScope.of(context);
      final isBg = languageController.locale.languageCode == 'bg';
      
      final upgraded = await showPaywallIfNeeded(
        context,
        isFeatureAvailable: false,
        featureName: isBg ? 'Календар' : 'Calendar',
      );
      
      if (!upgraded) return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Trial/Promo банер
            if (!_proService.isPaid && !_proService.isPromoCode && _proService.isTrial)
              _buildProBanner(context),
            
            // Основно съдържание
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
            
            // Банер реклама (само за Free потребители)
            const BannerAdWidget(),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: theme.colorScheme.surface,
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: NavigationBar(
              height: 64,
              backgroundColor: Colors.transparent,
              indicatorColor: theme.colorScheme.primary.withOpacity(isDark ? 0.25 : 0.12),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: _currentIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.checklist_rtl_outlined),
                  selectedIcon: const Icon(Icons.checklist_rtl),
                  label: t.tasks,
                ),
                NavigationDestination(
                  icon: Stack(
                    children: [
                      const Icon(Icons.calendar_today_outlined),
                      if (!_proService.canUseCalendar)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Icon(
                            Icons.lock,
                            size: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  selectedIcon: const Icon(Icons.calendar_today),
                  label: t.calendar,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: t.settings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProBanner(BuildContext context) {
    final theme = Theme.of(context);
    final languageController = LanguageScope.of(context);
    final isBg = languageController.locale.languageCode == 'bg';
    
    final daysLeft = _proService.isTrial 
        ? _proService.trialDaysLeft 
        : _proService.promoDaysLeft;
    
    final isUrgent = daysLeft <= 3;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUrgent 
              ? [Colors.orange.shade600, Colors.red.shade600]
              : [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent ? Icons.warning_rounded : Icons.workspace_premium_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _proService.isTrial
                  ? (isBg ? 'Пробен период: $daysLeft дни' : 'Trial: $daysLeft days left')
                  : (isBg ? 'Промо код: $daysLeft дни' : 'Promo: $daysLeft days left'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: Text(
              isBg ? 'Надгради' : 'Upgrade',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}


