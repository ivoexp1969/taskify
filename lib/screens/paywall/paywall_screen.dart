import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../services/pro_service.dart';
import '../../utils/localization.dart';

// Условен import за Package тип
import '../../services/purchases_stub.dart' if (dart.library.io) 'package:purchases_flutter/purchases_flutter.dart';

class PaywallScreen extends StatefulWidget {
  final String? featureName;

  const PaywallScreen({super.key, this.featureName});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final ProService _proService = ProService();
  final TextEditingController _promoController = TextEditingController();
  List<Package> _packages = [];
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isApplyingPromo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _loadOfferings() async {
    // На web не зареждаме продукти
    if (kIsWeb) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final packages = await _proService.getOfferings();
      debugPrint('Loaded ${packages.length} packages');
      for (final p in packages) {
        debugPrint('  - ${p.identifier}: ${p.storeProduct.priceString}');
      }
      
      if (mounted) {
        setState(() {
          _packages = packages;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Load offerings error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _purchasePackage(Package package) async {
    if (kIsWeb) return;
    
    setState(() => _isPurchasing = true);

    try {
      final success = await _proService.purchasePackage(package);
      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Благодарим ти! Вече си Pro!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Грешка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _applyPromoCode() async {
    if (kIsWeb) return;
    
    final code = _promoController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isApplyingPromo = true);

    try {
      final result = await _proService.applyPromoCode(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );

        if (result.success) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Грешка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isApplyingPromo = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    if (kIsWeb) return;
    
    setState(() => _isPurchasing = true);

    try {
      final success = await _proService.restorePurchases();
      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Покупките са възстановени!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Няма намерени покупки'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Грешка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageController = LanguageScope.of(context);
    final isBg = languageController.locale.languageCode == 'bg';

    // На web показваме съобщение
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Taskify Pro')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.workspace_premium_rounded, size: 80, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  isBg ? 'Web версията е безплатна!' : 'Web version is free!',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  isBg 
                    ? 'Свали приложението за Android за Pro функции и офлайн достъп.'
                    : 'Download the Android app for Pro features and offline access.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(isBg ? 'Разбрах' : 'Got it'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taskify Pro'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isPurchasing ? null : _restorePurchases,
            child: Text(
              isBg ? 'Възстанови' : 'Restore',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOfferings,
                        child: Text(isBg ? 'Опитай отново' : 'Try again'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isBg ? 'Отключи пълния потенциал' : 'Unlock Full Potential',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isBg
                            ? 'Получи достъп до всички Pro функции'
                            : 'Get access to all Pro features',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),

                      // Промо код секция
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.card_giftcard_rounded,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    isBg ? 'Имаш промо код?' : 'Have a promo code?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _promoController,
                                      textCapitalization: TextCapitalization.characters,
                                      decoration: InputDecoration(
                                        hintText: isBg ? 'Въведи код' : 'Enter code',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _isApplyingPromo ? null : _applyPromoCode,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme.primary,
                                        foregroundColor: theme.colorScheme.onPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _isApplyingPromo
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(isBg ? 'Приложи' : 'Apply'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Функции
                      _FeatureItem(icon: Icons.all_inclusive, title: isBg ? 'Неограничени задачи' : 'Unlimited tasks'),
                      _FeatureItem(icon: Icons.category_rounded, title: isBg ? 'Персонализирани категории' : 'Custom categories'),
                      _FeatureItem(icon: Icons.notifications_active_rounded, title: isBg ? 'Множество напомняния' : 'Multiple reminders'),
                      _FeatureItem(icon: Icons.repeat_rounded, title: isBg ? 'Повтарящи се задачи' : 'Recurring tasks'),
                      _FeatureItem(icon: Icons.calendar_month_rounded, title: isBg ? 'Календарен изглед' : 'Calendar view'),
                      _FeatureItem(icon: Icons.bar_chart_rounded, title: isBg ? 'Статистики' : 'Statistics'),
                      _FeatureItem(icon: Icons.cloud_sync_rounded, title: isBg ? 'Облачна синхронизация' : 'Cloud sync'),
                      _FeatureItem(icon: Icons.widgets_rounded, title: isBg ? 'Home screen widget' : 'Home screen widget'),
                      _FeatureItem(icon: Icons.mic_rounded, title: isBg ? 'Гласов вход' : 'Voice input'),
                      _FeatureItem(icon: Icons.palette_rounded, title: isBg ? 'Всички теми' : 'All themes'),
                      _FeatureItem(icon: Icons.block_rounded, title: isBg ? 'Без реклами' : 'No ads', highlight: true),

                      const SizedBox(height: 24),

                      // Продукти от Offerings
                      if (_packages.isEmpty)
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.shopping_cart_outlined, 
                                   size: 48, 
                                   color: theme.colorScheme.onSurface.withOpacity(0.4)),
                              const SizedBox(height: 8),
                              Text(
                                isBg ? 'Няма налични продукти' : 'No products available',
                                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _loadOfferings,
                                child: Text(isBg ? 'Опитай отново' : 'Try again'),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._packages.map((package) => _PackageCard(
                          package: package,
                          onTap: _isPurchasing ? null : () => _purchasePackage(package),
                          isBg: isBg,
                        )),

                      if (_isPurchasing)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool highlight;

  const _FeatureItem({required this.icon, required this.title, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 24, color: highlight ? Colors.green : theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title, 
              style: TextStyle(
                fontSize: 15, 
                fontWeight: highlight ? FontWeight.w600 : FontWeight.normal, 
                color: highlight ? Colors.green : null,
              ),
            ),
          ),
          Icon(Icons.check_circle_rounded, size: 20, color: Colors.green.withOpacity(0.8)),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Package package;
  final VoidCallback? onTap;
  final bool isBg;

  const _PackageCard({required this.package, required this.onTap, required this.isBg});

  String _getPackageTitle() {
    final identifier = package.identifier.toLowerCase();
    if (identifier.contains('lifetime')) return isBg ? 'Завинаги' : 'Lifetime';
    if (identifier.contains('annual') || identifier.contains('yearly')) return isBg ? 'Годишен' : 'Yearly';
    if (identifier.contains('monthly')) return isBg ? 'Месечен' : 'Monthly';
    return package.storeProduct.title;
  }

  String _getPackageSubtitle() {
    final identifier = package.identifier.toLowerCase();
    if (identifier.contains('lifetime')) return isBg ? 'Еднократно плащане' : 'One-time payment';
    if (identifier.contains('annual') || identifier.contains('yearly')) return isBg ? 'Спестяваш 50%' : 'Save 50%';
    if (identifier.contains('monthly')) return isBg ? 'Отказ по всяко време' : 'Cancel anytime';
    return package.storeProduct.description;
  }

  bool _isPopular() {
    final identifier = package.identifier.toLowerCase();
    return identifier.contains('annual') || identifier.contains('yearly');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPopular = _isPopular();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isPopular ? theme.colorScheme.primary.withOpacity(0.1) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPopular ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3), 
                width: isPopular ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _getPackageTitle(), 
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (isPopular) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary, 
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isBg ? 'Популярен' : 'Popular', 
                                style: TextStyle(
                                  fontSize: 10, 
                                  fontWeight: FontWeight.bold, 
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getPackageSubtitle(), 
                        style: TextStyle(
                          fontSize: 13, 
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  package.storeProduct.priceString, 
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> showPaywallIfNeeded(BuildContext context, {required bool isFeatureAvailable, String? featureName}) async {
  if (isFeatureAvailable) return true;
  final result = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const PaywallScreen(featureName: null)));
  return result == true;
}
