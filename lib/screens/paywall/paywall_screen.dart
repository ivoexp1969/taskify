import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../services/pro_service.dart';
import '../../utils/localization.dart';

// Условен import за Package тип
import '../../services/purchases_stub.dart' if (dart.library.io) 'package:purchases_flutter/purchases_flutter.dart';

const _p = {
  'thanksPro': {'en': 'Thank you! You are now Pro!', 'bg': 'Благодарим ти! Вече си Pro!', 'de': 'Danke! Du bist jetzt Pro!', 'fr': 'Merci! Vous êtes maintenant Pro!', 'it': 'Grazie! Ora sei Pro!', 'el': 'Ευχαριστούμε! Είσαι πλέον Pro!', 'es': '¡Gracias! ¡Ahora eres Pro!', 'pt': 'Obrigado! Agora você é Pro!', 'ru': 'Спасибо! Теперь вы Pro!', 'tr': 'Teşekkürler! Artık Pro\'sunuz!'},
  'error': {'en': 'Error', 'bg': 'Грешка', 'de': 'Fehler', 'fr': 'Erreur', 'it': 'Errore', 'el': 'Σφάλμα', 'es': 'Error', 'pt': 'Erro', 'ru': 'Ошибка', 'tr': 'Hata'},
  'purchasesRestored': {'en': 'Purchases restored!', 'bg': 'Покупките са възстановени!', 'de': 'Käufe wiederhergestellt!', 'fr': 'Achats restaurés!', 'it': 'Acquisti ripristinati!', 'el': 'Οι αγορές επαναφέρθηκαν!', 'es': '¡Compras restauradas!', 'pt': 'Compras restauradas!', 'ru': 'Покупки восстановлены!', 'tr': 'Satın almalar geri yüklendi!'},
  'noPurchases': {'en': 'No purchases found', 'bg': 'Няма намерени покупки', 'de': 'Keine Käufe gefunden', 'fr': 'Aucun achat trouvé', 'it': 'Nessun acquisto trovato', 'el': 'Δεν βρέθηκαν αγορές', 'es': 'No se encontraron compras', 'pt': 'Nenhuma compra encontrada', 'ru': 'Покупки не найдены', 'tr': 'Satın alma bulunamadı'},
  'webFree': {'en': 'Web version is free!', 'bg': 'Web версията е безплатна!', 'de': 'Die Web-Version ist kostenlos!', 'fr': 'La version web est gratuite!', 'it': 'La versione web è gratuita!', 'el': 'Η web έκδοση είναι δωρεάν!', 'es': '¡La versión web es gratuita!', 'pt': 'A versão web é gratuita!', 'ru': 'Веб-версия бесплатна!', 'tr': 'Web sürümü ücretsiz!'},
  'downloadAndroid': {'en': 'Download the Android app for Pro features and offline access.', 'bg': 'Свали приложението за Android за Pro функции и офлайн достъп.', 'de': 'Laden Sie die Android-App für Pro-Funktionen herunter.', 'fr': "Téléchargez l'application Android pour les fonctionnalités Pro.", 'it': "Scarica l'app Android per le funzionalità Pro.", 'el': 'Κατεβάστε την εφαρμογή Android για Pro λειτουργίες.', 'es': 'Descarga la app de Android para funciones Pro.', 'pt': 'Baixe o app Android para recursos Pro.', 'ru': 'Скачайте Android-приложение для Pro-функций.', 'tr': 'Pro özellikler için Android uygulamasını indirin.'},
  'gotIt': {'en': 'Got it', 'bg': 'Разбрах', 'de': 'Verstanden', 'fr': 'Compris', 'it': 'Capito', 'el': 'Κατάλαβα', 'es': 'Entendido', 'pt': 'Entendi', 'ru': 'Понятно', 'tr': 'Anladım'},
  'restore': {'en': 'Restore', 'bg': 'Възстанови', 'de': 'Wiederherstellen', 'fr': 'Restaurer', 'it': 'Ripristina', 'el': 'Επαναφορά', 'es': 'Restaurar', 'pt': 'Restaurar', 'ru': 'Восстановить', 'tr': 'Geri yükle'},
  'tryAgain': {'en': 'Try again', 'bg': 'Опитай отново', 'de': 'Erneut versuchen', 'fr': 'Réessayer', 'it': 'Riprova', 'el': 'Δοκιμάστε ξανά', 'es': 'Intentar de nuevo', 'pt': 'Tentar novamente', 'ru': 'Попробовать снова', 'tr': 'Tekrar dene'},
  'unlockPotential': {'en': 'Unlock Full Potential', 'bg': 'Отключи пълния потенциал', 'de': 'Volles Potenzial freischalten', 'fr': 'Débloquez tout le potentiel', 'it': 'Sblocca il pieno potenziale', 'el': 'Ξεκλειδώστε πλήρες δυναμικό', 'es': 'Desbloquea todo el potencial', 'pt': 'Desbloqueie todo o potencial', 'ru': 'Раскройте весь потенциал', 'tr': 'Tam potansiyeli açın'},
  'getAccess': {'en': 'Get access to all Pro features', 'bg': 'Получи достъп до всички Pro функции', 'de': 'Zugang zu allen Pro-Funktionen', 'fr': 'Accédez à toutes les fonctionnalités Pro', 'it': 'Accedi a tutte le funzionalità Pro', 'el': 'Αποκτήστε πρόσβαση σε όλες τις Pro λειτουργίες', 'es': 'Obtén acceso a todas las funciones Pro', 'pt': 'Tenha acesso a todos os recursos Pro', 'ru': 'Получите доступ ко всем Pro-функциям', 'tr': 'Tüm Pro özelliklere erişin'},
  'havePromo': {'en': 'Have a promo code?', 'bg': 'Имаш промо код?', 'de': 'Hast du einen Promo-Code?', 'fr': 'Avez-vous un code promo?', 'it': 'Hai un codice promo?', 'el': 'Έχετε κωδικό προσφοράς;', 'es': '¿Tienes un código promocional?', 'pt': 'Tem um código promocional?', 'ru': 'Есть промокод?', 'tr': 'Promosyon kodunuz var mı?'},
  'enterCode': {'en': 'Enter code', 'bg': 'Въведи код', 'de': 'Code eingeben', 'fr': 'Entrez le code', 'it': 'Inserisci codice', 'el': 'Εισάγετε κωδικό', 'es': 'Ingrese código', 'pt': 'Digite código', 'ru': 'Введите код', 'tr': 'Kodu girin'},
  'apply': {'en': 'Apply', 'bg': 'Приложи', 'de': 'Anwenden', 'fr': 'Appliquer', 'it': 'Applica', 'el': 'Εφαρμογή', 'es': 'Aplicar', 'pt': 'Aplicar', 'ru': 'Применить', 'tr': 'Uygula'},
  'noProducts': {'en': 'No products available', 'bg': 'Няма налични продукти', 'de': 'Keine Produkte verfügbar', 'fr': 'Aucun produit disponible', 'it': 'Nessun prodotto disponibile', 'el': 'Δεν υπάρχουν διαθέσιμα προϊόντα', 'es': 'No hay productos disponibles', 'pt': 'Nenhum produto disponível', 'ru': 'Нет доступных продуктов', 'tr': 'Ürün bulunamadı'},
  'unlimited': {'en': 'Unlimited tasks', 'bg': 'Неограничени задачи', 'de': 'Unbegrenzte Aufgaben', 'fr': 'Tâches illimitées', 'it': 'Attività illimitate', 'el': 'Απεριόριστες εργασίες', 'es': 'Tareas ilimitadas', 'pt': 'Tarefas ilimitadas', 'ru': 'Безлимитные задачи', 'tr': 'Sınırsız görevler'},
  'customCat': {'en': 'Custom categories', 'bg': 'Персонализирани категории', 'de': 'Eigene Kategorien', 'fr': 'Catégories personnalisées', 'it': 'Categorie personalizzate', 'el': 'Προσαρμοσμένες κατηγορίες', 'es': 'Categorías personalizadas', 'pt': 'Categorias personalizadas', 'ru': 'Свои категории', 'tr': 'Özel kategoriler'},
  'multiRemind': {'en': 'Multiple reminders', 'bg': 'Множество напомняния', 'de': 'Mehrere Erinnerungen', 'fr': 'Rappels multiples', 'it': 'Promemoria multipli', 'el': 'Πολλαπλές υπενθυμίσεις', 'es': 'Múltiples recordatorios', 'pt': 'Múltiplos lembretes', 'ru': 'Множество напоминаний', 'tr': 'Çoklu hatırlatıcılar'},
  'recurring': {'en': 'Recurring tasks', 'bg': 'Повтарящи се задачи', 'de': 'Wiederkehrende Aufgaben', 'fr': 'Tâches récurrentes', 'it': 'Attività ricorrenti', 'el': 'Επαναλαμβανόμενες εργασίες', 'es': 'Tareas recurrentes', 'pt': 'Tarefas recorrentes', 'ru': 'Повторяющиеся задачи', 'tr': 'Tekrarlayan görevler'},
  'calView': {'en': 'Calendar view', 'bg': 'Календарен изглед', 'de': 'Kalenderansicht', 'fr': 'Vue calendrier', 'it': 'Vista calendario', 'el': 'Προβολή ημερολογίου', 'es': 'Vista de calendario', 'pt': 'Visualização de calendário', 'ru': 'Вид календаря', 'tr': 'Takvim görünümü'},
  'stats': {'en': 'Statistics', 'bg': 'Статистики', 'de': 'Statistiken', 'fr': 'Statistiques', 'it': 'Statistiche', 'el': 'Στατιστικά', 'es': 'Estadísticas', 'pt': 'Estatísticas', 'ru': 'Статистика', 'tr': 'İstatistikler'},
  'cloudSync': {'en': 'Cloud sync', 'bg': 'Облачна синхронизация', 'de': 'Cloud-Sync', 'fr': 'Synchronisation cloud', 'it': 'Sincronizzazione cloud', 'el': 'Συγχρονισμός cloud', 'es': 'Sincronización en la nube', 'pt': 'Sincronização na nuvem', 'ru': 'Облачная синхронизация', 'tr': 'Bulut senkronizasyonu'},
  'voiceInput': {'en': 'Voice input', 'bg': 'Гласов вход', 'de': 'Spracheingabe', 'fr': 'Saisie vocale', 'it': 'Input vocale', 'el': 'Φωνητική εισαγωγή', 'es': 'Entrada de voz', 'pt': 'Entrada de voz', 'ru': 'Голосовой ввод', 'tr': 'Sesli giriş'},
  'allThemes': {'en': 'All themes', 'bg': 'Всички теми', 'de': 'Alle Themen', 'fr': 'Tous les thèmes', 'it': 'Tutti i temi', 'el': 'Όλα τα θέματα', 'es': 'Todos los temas', 'pt': 'Todos os temas', 'ru': 'Все темы', 'tr': 'Tüm temalar'},
  'noAds': {'en': 'No ads', 'bg': 'Без реклами', 'de': 'Keine Werbung', 'fr': 'Sans publicité', 'it': 'Senza pubblicità', 'el': 'Χωρίς διαφημίσεις', 'es': 'Sin anuncios', 'pt': 'Sem anúncios', 'ru': 'Без рекламы', 'tr': 'Reklamsız'},
  'lifetime': {'en': 'Lifetime', 'bg': 'Завинаги', 'de': 'Lebenslang', 'fr': 'À vie', 'it': 'A vita', 'el': 'Εφ\' όρου ζωής', 'es': 'De por vida', 'pt': 'Vitalício', 'ru': 'Навсегда', 'tr': 'Ömür boyu'},
  'yearly': {'en': 'Yearly', 'bg': 'Годишен', 'de': 'Jährlich', 'fr': 'Annuel', 'it': 'Annuale', 'el': 'Ετήσιο', 'es': 'Anual', 'pt': 'Anual', 'ru': 'Годовой', 'tr': 'Yıllık'},
  'monthly': {'en': 'Monthly', 'bg': 'Месечен', 'de': 'Monatlich', 'fr': 'Mensuel', 'it': 'Mensile', 'el': 'Μηνιαίο', 'es': 'Mensual', 'pt': 'Mensal', 'ru': 'Месячный', 'tr': 'Aylık'},
  'oneTime': {'en': 'One-time payment', 'bg': 'Еднократно плащане', 'de': 'Einmalzahlung', 'fr': 'Paiement unique', 'it': 'Pagamento unico', 'el': 'Εφάπαξ πληρωμή', 'es': 'Pago único', 'pt': 'Pagamento único', 'ru': 'Единоразовый платёж', 'tr': 'Tek seferlik ödeme'},
  'save50': {'en': 'Save 50%', 'bg': 'Спестяваш 50%', 'de': '50% sparen', 'fr': 'Économisez 50%', 'it': 'Risparmia il 50%', 'el': 'Εξοικονομήστε 50%', 'es': 'Ahorra 50%', 'pt': 'Economize 50%', 'ru': 'Скидка 50%', 'tr': '%50 tasarruf'},
  'cancelAnytime': {'en': 'Cancel anytime', 'bg': 'Отказ по всяко време', 'de': 'Jederzeit kündbar', 'fr': "Annulez à tout moment", 'it': 'Annulla in qualsiasi momento', 'el': 'Ακύρωση οποτεδήποτε', 'es': 'Cancela en cualquier momento', 'pt': 'Cancele a qualquer momento', 'ru': 'Отмена в любое время', 'tr': 'İstediğiniz zaman iptal edin'},
  'popular': {'en': 'Popular', 'bg': 'Популярен', 'de': 'Beliebt', 'fr': 'Populaire', 'it': 'Popolare', 'el': 'Δημοφιλές', 'es': 'Popular', 'pt': 'Popular', 'ru': 'Популярный', 'tr': 'Popüler'},
};

String _pt(String key, String lang) => _p[key]?[lang] ?? _p[key]?['en'] ?? '';

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

  String get _lang => LanguageScope.of(context).locale.languageCode;

  Future<void> _loadOfferings() async {
    if (kIsWeb) {
      setState(() => _isLoading = false);
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
            SnackBar(
              content: Text(_pt('thanksPro', _lang)),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_pt('error', _lang)}: $e'), backgroundColor: Colors.red),
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
          SnackBar(content: Text('${_pt('error', _lang)}: $e'), backgroundColor: Colors.red),
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
            SnackBar(
              content: Text(_pt('purchasesRestored', _lang)),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_pt('noPurchases', _lang)),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_pt('error', _lang)}: $e'), backgroundColor: Colors.red),
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
    final lang = _lang;

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
                  _pt('webFree', lang),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _pt('downloadAndroid', lang),
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_pt('gotIt', lang)),
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
              _pt('restore', lang),
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
                        child: Text(_pt('tryAgain', lang)),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _pt('unlockPotential', lang),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _pt('getAccess', lang),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),

                      Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                                    _pt('havePromo', lang),
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
                                        hintText: _pt('enterCode', lang),
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
                                          : Text(_pt('apply', lang)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      _FeatureItem(icon: Icons.all_inclusive, title: _pt('unlimited', lang)),
                      _FeatureItem(icon: Icons.category_rounded, title: _pt('customCat', lang)),
                      _FeatureItem(icon: Icons.notifications_active_rounded, title: _pt('multiRemind', lang)),
                      _FeatureItem(icon: Icons.repeat_rounded, title: _pt('recurring', lang)),
                      _FeatureItem(icon: Icons.calendar_month_rounded, title: _pt('calView', lang)),
                      _FeatureItem(icon: Icons.bar_chart_rounded, title: _pt('stats', lang)),
                      _FeatureItem(icon: Icons.cloud_sync_rounded, title: _pt('cloudSync', lang)),
                      _FeatureItem(icon: Icons.widgets_rounded, title: 'Home screen widget'),
                      _FeatureItem(icon: Icons.mic_rounded, title: _pt('voiceInput', lang)),
                      _FeatureItem(icon: Icons.palette_rounded, title: _pt('allThemes', lang)),
                      _FeatureItem(icon: Icons.block_rounded, title: _pt('noAds', lang), highlight: true),

                      const SizedBox(height: 24),

                      if (_packages.isEmpty)
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.shopping_cart_outlined, 
                                   size: 48, 
                                   color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                              const SizedBox(height: 8),
                              Text(
                                _pt('noProducts', lang),
                                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _loadOfferings,
                                child: Text(_pt('tryAgain', lang)),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._packages.map((package) => _PackageCard(
                          package: package,
                          onTap: _isPurchasing ? null : () => _purchasePackage(package),
                          lang: lang,
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
          Icon(Icons.check_circle_rounded, size: 20, color: Colors.green.withValues(alpha: 0.8)),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Package package;
  final VoidCallback? onTap;
  final String lang;

  const _PackageCard({required this.package, required this.onTap, required this.lang});

  String _getPackageTitle() {
    final identifier = package.identifier.toLowerCase();
    if (identifier.contains('lifetime')) return _pt('lifetime', lang);
    if (identifier.contains('annual') || identifier.contains('yearly')) return _pt('yearly', lang);
    if (identifier.contains('monthly')) return _pt('monthly', lang);
    return package.storeProduct.title;
  }

  String _getPackageSubtitle() {
    final identifier = package.identifier.toLowerCase();
    if (identifier.contains('lifetime')) return _pt('oneTime', lang);
    if (identifier.contains('annual') || identifier.contains('yearly')) return _pt('save50', lang);
    if (identifier.contains('monthly')) return _pt('cancelAnytime', lang);
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
        color: isPopular ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPopular ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3), 
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
                                _pt('popular', lang), 
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
