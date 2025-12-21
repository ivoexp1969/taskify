import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../services/pro_service.dart';
import '../../utils/localization.dart';

class PaywallScreen extends StatefulWidget {
  final String? featureName;
  
  const PaywallScreen({super.key, this.featureName});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final ProService _proService = ProService();
  final TextEditingController _promoController = TextEditingController();
  List<StoreProduct> _products = [];
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isApplyingPromo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final products = await _proService.getProducts();
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _purchase(StoreProduct product) async {
    setState(() => _isPurchasing = true);

    try {
      final success = await _proService.purchase(product);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taskify Pro'),
        actions: [
          TextButton(
            onPressed: _isPurchasing ? null : _restorePurchases,
            child: Text(isBg ? 'Възстанови' : 'Restore'),
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
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProducts,
                        child: Text(isBg ? 'Опитай отново' : 'Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 80,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isBg ? 'Отключи всички функции' : 'Unlock all features',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      if (widget.featureName != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${isBg ? "Нужен е Pro за" : "Pro required for"}: ${widget.featureName}',
                            style: const TextStyle(color: Colors.amber),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Промо код секция
                      Card(
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

                      // Продукти
                      if (_products.isEmpty)
                        Center(
                          child: Text(
                            isBg ? 'Няма налични продукти' : 'No products available',
                            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                          ),
                        )
                      else
                        ..._products.map((product) => _ProductCard(
                          product: product,
                          onTap: _isPurchasing ? null : () => _purchase(product),
                          isBg: isBg,
                        )),

                      if (_isPurchasing)
                        const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),

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
            child: Text(title, style: TextStyle(fontSize: 15, fontWeight: highlight ? FontWeight.w600 : FontWeight.normal, color: highlight ? Colors.green : null)),
          ),
          Icon(Icons.check_circle_rounded, size: 20, color: Colors.green.withOpacity(0.8)),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final StoreProduct product;
  final VoidCallback? onTap;
  final bool isBg;

  const _ProductCard({required this.product, required this.onTap, required this.isBg});

  String _getProductTitle() {
    if (product.identifier.contains('lifetime')) return isBg ? 'Завинаги' : 'Lifetime';
    if (product.identifier.contains('yearly')) return isBg ? 'Годишен' : 'Yearly';
    if (product.identifier.contains('monthly')) return isBg ? 'Месечен' : 'Monthly';
    return product.title;
  }

  String _getProductSubtitle() {
    if (product.identifier.contains('lifetime')) return isBg ? 'Еднократно плащане' : 'One-time payment';
    if (product.identifier.contains('yearly')) return isBg ? 'Спестяваш 50%' : 'Save 50%';
    if (product.identifier.contains('monthly')) return isBg ? 'Отказ по всяко време' : 'Cancel anytime';
    return product.description;
  }

  bool _isPopular() => product.identifier.contains('yearly');

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
              border: Border.all(color: isPopular ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3), width: isPopular ? 2 : 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_getProductTitle(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (isPopular) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                              child: Text(isBg ? 'Популярен' : 'Popular', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimary)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(_getProductSubtitle(), style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                    ],
                  ),
                ),
                Text(product.priceString, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
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
