import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/pro_service.dart';
import '../../utils/localization.dart';

// Условен import за Package тип
import '../../services/purchases_stub.dart' if (dart.library.io) 'package:purchases_flutter/purchases_flutter.dart';

const _p = {
  'thanksPro': {'en': 'Thank you! You are now Pro!', 'nl': 'Bedankt! Je bent nu Pro!', 'uk': 'Дякуємо! Тепер ви Pro!', 'bg': 'Благодарим ти! Вече си Pro!', 'de': 'Danke! Du bist jetzt Pro!', 'fr': 'Merci! Vous êtes maintenant Pro!', 'it': 'Grazie! Ora sei Pro!', 'el': 'Ευχαριστούμε! Είσαι πλέον Pro!', 'es': '¡Gracias! ¡Ahora eres Pro!', 'pt': 'Obrigado! Agora você é Pro!', 'ru': 'Спасибо! Теперь вы Pro!', 'tr': 'Teşekkürler! Artık Pro\'sunuz!', 'ja': 'ありがとうございます！Proになりました！'},
  'error': {'en': 'Error', 'nl': 'Fout', 'uk': 'Помилка', 'bg': 'Грешка', 'de': 'Fehler', 'fr': 'Erreur', 'it': 'Errore', 'el': 'Σφάλμα', 'es': 'Error', 'pt': 'Erro', 'ru': 'Ошибка', 'tr': 'Hata', 'ja': 'エラー'},
  'purchasesRestored': {'en': 'Purchases restored!', 'nl': 'Aankopen hersteld!', 'uk': 'Покупки відновлено!', 'bg': 'Покупките са възстановени!', 'de': 'Käufe wiederhergestellt!', 'fr': 'Achats restaurés!', 'it': 'Acquisti ripristinati!', 'el': 'Οι αγορές επαναφέρθηκαν!', 'es': '¡Compras restauradas!', 'pt': 'Compras restauradas!', 'ru': 'Покупки восстановлены!', 'tr': 'Satın almalar geri yüklendi!', 'ja': '購入を復元しました！'},
  'noPurchases': {'en': 'No purchases found', 'nl': 'Geen aankopen gevonden', 'uk': 'Покупок не знайдено', 'bg': 'Няма намерени покупки', 'de': 'Keine Käufe gefunden', 'fr': 'Aucun achat trouvé', 'it': 'Nessun acquisto trovato', 'el': 'Δεν βρέθηκαν αγορές', 'es': 'No se encontraron compras', 'pt': 'Nenhuma compra encontrada', 'ru': 'Покупки не найдены', 'tr': 'Satın alma bulunamadı', 'ja': '購入が見つかりません'},
  'webFree': {'en': 'Web version is free!', 'nl': 'Webversie is gratis!', 'uk': 'Веб-версія безкоштовна!', 'bg': 'Web версията е безплатна!', 'de': 'Die Web-Version ist kostenlos!', 'fr': 'La version web est gratuite!', 'it': 'La versione web è gratuita!', 'el': 'Η web έκδοση είναι δωρεάν!', 'es': '¡La versión web es gratuita!', 'pt': 'A versão web é gratuita!', 'ru': 'Веб-версия бесплатна!', 'tr': 'Web sürümü ücretsiz!', 'ja': 'ウェブ版は無料です！'},
  'downloadAndroid': {'en': 'Download the Android app for Pro features and offline access.', 'nl': 'Download de Android-app voor Pro-functies en offline toegang.', 'uk': 'Завантажте застосунок для Android заради Pro-функцій та офлайн-доступу.', 'bg': 'Свали приложението за Android за Pro функции и офлайн достъп.', 'de': 'Laden Sie die Android-App für Pro-Funktionen herunter.', 'fr': "Téléchargez l'application Android pour les fonctionnalités Pro.", 'it': "Scarica l'app Android per le funzionalità Pro.", 'el': 'Κατεβάστε την εφαρμογή Android για Pro λειτουργίες.', 'es': 'Descarga la app de Android para funciones Pro.', 'pt': 'Baixe o app Android para recursos Pro.', 'ru': 'Скачайте Android-приложение для Pro-функций.', 'tr': 'Pro özellikler için Android uygulamasını indirin.', 'ja': 'Pro機能とオフラインアクセスにはAndroidアプリをダウンロードしてください。'},
  'gotIt': {'en': 'Got it', 'nl': 'Begrepen', 'uk': 'Зрозуміло', 'bg': 'Разбрах', 'de': 'Verstanden', 'fr': 'Compris', 'it': 'Capito', 'el': 'Κατάλαβα', 'es': 'Entendido', 'pt': 'Entendi', 'ru': 'Понятно', 'tr': 'Anladım', 'ja': '了解'},
  'restore': {'en': 'Restore', 'nl': 'Herstellen', 'uk': 'Відновити', 'bg': 'Възстанови', 'de': 'Wiederherstellen', 'fr': 'Restaurer', 'it': 'Ripristina', 'el': 'Επαναφορά', 'es': 'Restaurar', 'pt': 'Restaurar', 'ru': 'Восстановить', 'tr': 'Geri yükle', 'ja': '復元'},
  'tryAgain': {'en': 'Try again', 'nl': 'Opnieuw proberen', 'uk': 'Спробувати ще раз', 'bg': 'Опитай отново', 'de': 'Erneut versuchen', 'fr': 'Réessayer', 'it': 'Riprova', 'el': 'Δοκιμάστε ξανά', 'es': 'Intentar de nuevo', 'pt': 'Tentar novamente', 'ru': 'Попробовать снова', 'tr': 'Tekrar dene', 'ja': 'もう一度'},
  'unlockPotential': {'en': 'Unlock Full Potential', 'nl': 'Ontgrendel je volledige potentieel', 'uk': 'Розкрийте весь потенціал', 'bg': 'Отключи пълния потенциал', 'de': 'Volles Potenzial freischalten', 'fr': 'Débloquez tout le potentiel', 'it': 'Sblocca il pieno potenziale', 'el': 'Ξεκλειδώστε πλήρες δυναμικό', 'es': 'Desbloquea todo el potencial', 'pt': 'Desbloqueie todo o potencial', 'ru': 'Раскройте весь потенциал', 'tr': 'Tam potansiyeli açın', 'ja': 'すべての機能を解放'},
  'getAccess': {'en': 'Get access to all Pro features', 'nl': 'Krijg toegang tot alle Pro-functies', 'uk': 'Отримайте доступ до всіх Pro-функцій', 'bg': 'Получи достъп до всички Pro функции', 'de': 'Zugang zu allen Pro-Funktionen', 'fr': 'Accédez à toutes les fonctionnalités Pro', 'it': 'Accedi a tutte le funzionalità Pro', 'el': 'Αποκτήστε πρόσβαση σε όλες τις Pro λειτουργίες', 'es': 'Obtén acceso a todas las funciones Pro', 'pt': 'Tenha acesso a todos os recursos Pro', 'ru': 'Получите доступ ко всем Pro-функциям', 'tr': 'Tüm Pro özelliklere erişin', 'ja': 'すべてのPro機能を利用する'},
  'havePromo': {'en': 'Have a promo code?', 'nl': 'Heb je een promocode?', 'uk': 'Маєте промокод?', 'bg': 'Имаш промо код?', 'de': 'Hast du einen Promo-Code?', 'fr': 'Avez-vous un code promo?', 'it': 'Hai un codice promo?', 'el': 'Έχετε κωδικό προσφοράς;', 'es': '¿Tienes un código promocional?', 'pt': 'Tem um código promocional?', 'ru': 'Есть промокод?', 'tr': 'Promosyon kodunuz var mı?', 'ja': 'プロモコードをお持ちですか？'},
  'enterCode': {'en': 'Enter code', 'nl': 'Voer code in', 'uk': 'Введіть код', 'bg': 'Въведи код', 'de': 'Code eingeben', 'fr': 'Entrez le code', 'it': 'Inserisci codice', 'el': 'Εισάγετε κωδικό', 'es': 'Ingrese código', 'pt': 'Digite código', 'ru': 'Введите код', 'tr': 'Kodu girin', 'ja': 'コードを入力'},
  'apply': {'en': 'Apply', 'nl': 'Toepassen', 'uk': 'Застосувати', 'bg': 'Приложи', 'de': 'Anwenden', 'fr': 'Appliquer', 'it': 'Applica', 'el': 'Εφαρμογή', 'es': 'Aplicar', 'pt': 'Aplicar', 'ru': 'Применить', 'tr': 'Uygula', 'ja': '適用'},
  'noProducts': {'en': 'No products available', 'nl': 'Geen producten beschikbaar', 'uk': 'Немає доступних продуктів', 'bg': 'Няма налични продукти', 'de': 'Keine Produkte verfügbar', 'fr': 'Aucun produit disponible', 'it': 'Nessun prodotto disponibile', 'el': 'Δεν υπάρχουν διαθέσιμα προϊόντα', 'es': 'No hay productos disponibles', 'pt': 'Nenhum produto disponível', 'ru': 'Нет доступных продуктов', 'tr': 'Ürün bulunamadı', 'ja': '利用可能な商品がありません'},
  'unlimited': {'en': 'Unlimited tasks', 'nl': 'Onbeperkte taken', 'uk': 'Необмежені завдання', 'bg': 'Неограничени задачи', 'de': 'Unbegrenzte Aufgaben', 'fr': 'Tâches illimitées', 'it': 'Attività illimitate', 'el': 'Απεριόριστες εργασίες', 'es': 'Tareas ilimitadas', 'pt': 'Tarefas ilimitadas', 'ru': 'Безлимитные задачи', 'tr': 'Sınırsız görevler', 'ja': '無制限のタスク'},
  'customCat': {'en': 'Custom categories', 'nl': 'Eigen categorieën', 'uk': 'Власні категорії', 'bg': 'Персонализирани категории', 'de': 'Eigene Kategorien', 'fr': 'Catégories personnalisées', 'it': 'Categorie personalizzate', 'el': 'Προσαρμοσμένες κατηγορίες', 'es': 'Categorías personalizadas', 'pt': 'Categorias personalizadas', 'ru': 'Свои категории', 'tr': 'Özel kategoriler', 'ja': 'カスタムカテゴリー'},
  'multiRemind': {'en': 'Multiple reminders', 'nl': 'Meerdere herinneringen', 'uk': 'Кілька нагадувань', 'bg': 'Множество напомняния', 'de': 'Mehrere Erinnerungen', 'fr': 'Rappels multiples', 'it': 'Promemoria multipli', 'el': 'Πολλαπλές υπενθυμίσεις', 'es': 'Múltiples recordatorios', 'pt': 'Múltiplos lembretes', 'ru': 'Множество напоминаний', 'tr': 'Çoklu hatırlatıcılar', 'ja': '複数のリマインダー'},
  'recurring': {'en': 'Recurring tasks', 'nl': 'Terugkerende taken', 'uk': 'Повторювані завдання', 'bg': 'Повтарящи се задачи', 'de': 'Wiederkehrende Aufgaben', 'fr': 'Tâches récurrentes', 'it': 'Attività ricorrenti', 'el': 'Επαναλαμβανόμενες εργασίες', 'es': 'Tareas recurrentes', 'pt': 'Tarefas recorrentes', 'ru': 'Повторяющиеся задачи', 'tr': 'Tekrarlayan görevler', 'ja': '繰り返しタスク'},
  'calView': {'en': 'Calendar view', 'nl': 'Agendaweergave', 'uk': 'Вигляд календаря', 'bg': 'Календарен изглед', 'de': 'Kalenderansicht', 'fr': 'Vue calendrier', 'it': 'Vista calendario', 'el': 'Προβολή ημερολογίου', 'es': 'Vista de calendario', 'pt': 'Visualização de calendário', 'ru': 'Вид календаря', 'tr': 'Takvim görünümü', 'ja': 'カレンダー表示'},
  'stats': {'en': 'Statistics', 'nl': 'Statistieken', 'uk': 'Статистика', 'bg': 'Статистики', 'de': 'Statistiken', 'fr': 'Statistiques', 'it': 'Statistiche', 'el': 'Στατιστικά', 'es': 'Estadísticas', 'pt': 'Estatísticas', 'ru': 'Статистика', 'tr': 'İstatistikler', 'ja': '統計'},
  'cloudSync': {'en': 'Cloud sync', 'nl': 'Cloudsynchronisatie', 'uk': 'Хмарна синхронізація', 'bg': 'Облачна синхронизация', 'de': 'Cloud-Sync', 'fr': 'Synchronisation cloud', 'it': 'Sincronizzazione cloud', 'el': 'Συγχρονισμός cloud', 'es': 'Sincronización en la nube', 'pt': 'Sincronização na nuvem', 'ru': 'Облачная синхронизация', 'tr': 'Bulut senkronizasyonu', 'ja': 'クラウド同期'},
  'voiceInput': {'en': 'Voice input', 'nl': 'Spraakinvoer', 'uk': 'Голосове введення', 'bg': 'Гласов вход', 'de': 'Spracheingabe', 'fr': 'Saisie vocale', 'it': 'Input vocale', 'el': 'Φωνητική εισαγωγή', 'es': 'Entrada de voz', 'pt': 'Entrada de voz', 'ru': 'Голосовой ввод', 'tr': 'Sesli giriş', 'ja': '音声入力'},
  'allThemes': {'en': 'All themes', 'nl': 'Alle thema\'s', 'uk': 'Усі теми', 'bg': 'Всички теми', 'de': 'Alle Themen', 'fr': 'Tous les thèmes', 'it': 'Tutti i temi', 'el': 'Όλα τα θέματα', 'es': 'Todos los temas', 'pt': 'Todos os temas', 'ru': 'Все темы', 'tr': 'Tüm temalar', 'ja': 'すべてのテーマ'},
  'noAds': {'en': 'No ads', 'nl': 'Geen advertenties', 'uk': 'Без реклами', 'bg': 'Без реклами', 'de': 'Keine Werbung', 'fr': 'Sans publicité', 'it': 'Senza pubblicità', 'el': 'Χωρίς διαφημίσεις', 'es': 'Sin anuncios', 'pt': 'Sem anúncios', 'ru': 'Без рекламы', 'tr': 'Reklamsız', 'ja': '広告なし'},
  'lifetime': {'en': 'Lifetime', 'nl': 'Levenslang', 'uk': 'Довічно', 'bg': 'Завинаги', 'de': 'Lebenslang', 'fr': 'À vie', 'it': 'A vita', 'el': 'Εφ\' όρου ζωής', 'es': 'De por vida', 'pt': 'Vitalício', 'ru': 'Навсегда', 'tr': 'Ömür boyu', 'ja': '買い切り'},
  'yearly': {'en': 'Yearly', 'nl': 'Jaarlijks', 'uk': 'Щороку', 'bg': 'Годишен', 'de': 'Jährlich', 'fr': 'Annuel', 'it': 'Annuale', 'el': 'Ετήσιο', 'es': 'Anual', 'pt': 'Anual', 'ru': 'Годовой', 'tr': 'Yıllık', 'ja': '毎年'},
  'monthly': {'en': 'Monthly', 'nl': 'Maandelijks', 'uk': 'Щомісяця', 'bg': 'Месечен', 'de': 'Monatlich', 'fr': 'Mensuel', 'it': 'Mensile', 'el': 'Μηνιαίο', 'es': 'Mensual', 'pt': 'Mensal', 'ru': 'Месячный', 'tr': 'Aylık', 'ja': '毎月'},
  'oneTime': {'en': 'One-time payment', 'nl': 'Eenmalige betaling', 'uk': 'Одноразовий платіж', 'bg': 'Еднократно плащане', 'de': 'Einmalzahlung', 'fr': 'Paiement unique', 'it': 'Pagamento unico', 'el': 'Εφάπαξ πληρωμή', 'es': 'Pago único', 'pt': 'Pagamento único', 'ru': 'Единоразовый платёж', 'tr': 'Tek seferlik ödeme', 'ja': '1回限りの支払い'},
  // Динамична отстъпка: N се заменя с реалния процент (от цените на стора).
  'saveN': {'en': 'Save N%', 'nl': 'Bespaar N%', 'uk': 'Заощадьте N%', 'bg': 'Спестяваш N%', 'de': 'N% sparen', 'fr': 'Économisez N%', 'it': 'Risparmia il N%', 'el': 'Εξοικονομήστε N%', 'es': 'Ahorra N%', 'pt': 'Economize N%', 'ru': 'Скидка N%', 'tr': '%N tasarruf', 'ja': 'N%お得'},
  'cancelAnytime': {'en': 'Cancel anytime', 'nl': 'Altijd opzegbaar', 'uk': 'Скасування будь-коли', 'bg': 'Отказ по всяко време', 'de': 'Jederzeit kündbar', 'fr': "Annulez à tout moment", 'it': 'Annulla in qualsiasi momento', 'el': 'Ακύρωση οποτεδήποτε', 'es': 'Cancela en cualquier momento', 'pt': 'Cancele a qualquer momento', 'ru': 'Отмена в любое время', 'tr': 'İstediğiniz zaman iptal edin', 'ja': 'いつでもキャンセル可能'},
  'popular': {'en': 'Popular', 'nl': 'Populair', 'uk': 'Популярне', 'bg': 'Популярен', 'de': 'Beliebt', 'fr': 'Populaire', 'it': 'Popolare', 'el': 'Δημοφιλές', 'es': 'Popular', 'pt': 'Popular', 'ru': 'Популярный', 'tr': 'Popüler', 'ja': '人気'},
  'bestValue': {'en': 'Best value', 'nl': 'Beste keuze', 'uk': 'Найвигідніше', 'bg': 'Най-изгоден', 'de': 'Bester Wert', 'fr': 'Meilleure offre', 'it': 'Miglior valore', 'el': 'Καλύτερη αξία', 'es': 'Mejor valor', 'pt': 'Melhor valor', 'ru': 'Выгоднее всего', 'tr': 'En avantajlı', 'ja': '最もお得'},
  'unlimitedAi': {'en': 'Unlimited AI', 'nl': 'Onbeperkte AI', 'uk': 'Необмежений AI', 'bg': 'Неограничен AI', 'de': 'Unbegrenzte KI', 'fr': 'IA illimitée', 'it': 'IA illimitata', 'el': 'Απεριόριστη AI', 'es': 'IA ilimitada', 'pt': 'IA ilimitada', 'ru': 'Безлимитный AI', 'tr': 'Sınırsız yapay zekâ', 'ja': '無制限のAI'},
  // Съкращение „месец" за реда с месечна равностойност (≈ X/мес.).
  'perMonth': {'en': 'mo', 'nl': 'ma', 'uk': 'міс', 'bg': 'мес.', 'de': 'Mon.', 'fr': 'mois', 'it': 'mese', 'el': 'μήνα', 'es': 'mes', 'pt': 'mês', 'ru': 'мес.', 'tr': 'ay', 'ja': '月'},
  // Шаблон за trial badge; N се заменя с реалния брой дни от offering-а.
  'daysFree': {'en': 'N days free', 'nl': 'N dagen gratis', 'uk': 'N днів безкоштовно', 'bg': 'N дни безплатно', 'de': 'N Tage gratis', 'fr': 'N jours gratuits', 'it': 'N giorni gratis', 'el': 'N ημέρες δωρεάν', 'es': 'N días gratis', 'pt': 'N dias grátis', 'ru': 'N дней бесплатно', 'tr': 'N gün ücretsiz', 'ja': 'N日間無料'},
  'termsOfUse': {'en': 'Terms of Use', 'nl': 'Gebruiksvoorwaarden', 'uk': 'Умови використання', 'bg': 'Условия за ползване', 'de': 'Nutzungsbedingungen', 'fr': "Conditions d'utilisation", 'it': 'Termini di utilizzo', 'el': 'Όροι Χρήσης', 'es': 'Términos de uso', 'pt': 'Termos de uso', 'ru': 'Условия использования', 'tr': 'Kullanım Koşulları', 'ja': '利用規約'},
  'privacyPolicy': {'en': 'Privacy Policy', 'nl': 'Privacybeleid', 'uk': 'Політика конфіденційності', 'bg': 'Политика за поверителност', 'de': 'Datenschutzerklärung', 'fr': 'Politique de confidentialité', 'it': 'Informativa sulla privacy', 'el': 'Πολιτική Απορρήτου', 'es': 'Política de Privacidad', 'pt': 'Política de Privacidade', 'ru': 'Политика конфиденциальности', 'tr': 'Gizlilik Politikası', 'ja': 'プライバシーポリシー'},
  'widget': {'en': 'Home screen widget', 'nl': 'Widget op startscherm', 'uk': 'Віджет на головному екрані', 'bg': 'Джаджа на началния екран', 'de': 'Startbildschirm-Widget', 'fr': "Widget d'écran d'accueil", 'it': 'Widget schermata home', 'el': 'Widget αρχικής οθόνης', 'es': 'Widget de pantalla de inicio', 'pt': 'Widget do ecrã inicial', 'ru': 'Виджет на главном экране', 'tr': 'Ana ekran widget\'ı', 'ja': 'ホーム画面ウィジェット'},
  'nameDaysContacts': {'en': 'Name days + your contacts', 'nl': 'Naamdagen + je contacten', 'uk': 'Іменини + ваші контакти', 'bg': 'Имени дни + твоите контакти', 'de': 'Namenstage + deine Kontakte', 'fr': 'Fêtes des prénoms + tes contacts', 'it': 'Onomastici + i tuoi contatti', 'el': 'Ονομαστικές εορτές + οι επαφές σου', 'es': 'Onomásticas + tus contactos', 'pt': 'Dias do nome + os teus contactos', 'ru': 'Именины + ваши контакты', 'tr': 'İsim günleri + kişilerin', 'ja': '聖名祝日＋連絡先'},
  'sharedLists': {'en': 'Shared lists', 'nl': 'Gedeelde lijsten', 'uk': 'Спільні списки', 'bg': 'Споделени списъци', 'de': 'Geteilte Listen', 'fr': 'Listes partagées', 'it': 'Liste condivise', 'el': 'Κοινές λίστες', 'es': 'Listas compartidas', 'pt': 'Listas partilhadas', 'ru': 'Общие списки', 'tr': 'Paylaşılan listeler', 'ja': '共有リスト'},
  // Бутон „Продължи — {цена}"; {price} се замества с priceString на избрания план.
  'continueWith': {'en': 'Continue — {price}', 'nl': 'Doorgaan — {price}', 'uk': 'Продовжити — {price}', 'bg': 'Продължи — {price}', 'de': 'Weiter — {price}', 'fr': 'Continuer — {price}', 'it': 'Continua — {price}', 'el': 'Συνέχεια — {price}', 'es': 'Continuar — {price}', 'pt': 'Continuar — {price}', 'ru': 'Продолжить — {price}', 'tr': 'Devam — {price}', 'ja': '続ける — {price}'},
  // Хедър, когато paywall-ът е отворен за конкретна заключена функция.
  'unlockFeature': {'en': 'Unlock {feature}', 'nl': '{feature} ontgrendelen', 'uk': 'Розблокувати {feature}', 'bg': 'Отключи {feature}', 'de': '{feature} freischalten', 'fr': 'Débloquer {feature}', 'it': 'Sblocca {feature}', 'el': 'Ξεκλείδωμα {feature}', 'es': 'Desbloquear {feature}', 'pt': 'Desbloquear {feature}', 'ru': 'Открыть {feature}', 'tr': '{feature} kilidini aç', 'ja': '{feature}を解除'},
};

String _pt(String key, String lang) => _p[key]?[lang] ?? _p[key]?['en'] ?? '';

/// „N дни безплатно" с реалния брой дни (от offering-а).
String _daysFree(int days, String lang) =>
    _pt('daysFree', lang).replaceAll('N', '$days');

/// „Спестяваш N%" с реален процент (сметнат от цените на стора).
String _saveN(int percent, String lang) =>
    _pt('saveN', lang).replaceAll('N', '$percent');

/// „Продължи — {цена}".
String _continueWith(String price, String lang) =>
    _pt('continueWith', lang).replaceAll('{price}', price);

/// „Отключи {функция}".
String _unlockFeature(String feature, String lang) =>
    _pt('unlockFeature', lang).replaceAll('{feature}', feature);

/// ФАЗА 3.3: превръща intro периода в брой ДНИ (за trial badge). Връща null при
/// неизвестна единица.
int? _introDays(IntroductoryPrice intro) {
  switch (intro.periodUnit) {
    case PeriodUnit.day:
      return intro.periodNumberOfUnits;
    case PeriodUnit.week:
      return intro.periodNumberOfUnits * 7;
    case PeriodUnit.month:
      return intro.periodNumberOfUnits * 30;
    case PeriodUnit.year:
      return intro.periodNumberOfUnits * 365;
    case PeriodUnit.unknown:
      return null;
  }
}

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
  Package? _selectedPackage; // избраният план (Lifetime по подразбиране)
  int? _yearlySavings; // % отстъпка на годишния спрямо 12× месечния (ако е смятаемо)
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isApplyingPromo = false;
  String? _error;

  /// Планът по подразбиране при отваряне = Lifetime (иначе първият наличен).
  Package? _defaultPackage(List<Package> pkgs) {
    for (final p in pkgs) {
      if (p.identifier.toLowerCase().contains('lifetime')) return p;
    }
    return pkgs.isNotEmpty ? pkgs.first : null;
  }

  /// Реална отстъпка на годишния спрямо 12× месечния (закръглено). null ако някоя
  /// цена липсва/е 0 или няма спестяване → тогава не показваме твърд процент.
  int? _computeYearlySavings(List<Package> pkgs) {
    Package? monthly, yearly;
    for (final p in pkgs) {
      final id = p.identifier.toLowerCase();
      if (id.contains('monthly')) monthly = p;
      if (id.contains('annual') || id.contains('yearly')) yearly = p;
    }
    if (monthly == null || yearly == null) return null;
    final m = monthly.storeProduct.price;
    final y = yearly.storeProduct.price;
    if (m <= 0 || y <= 0) return null;
    final pct = (1 - (y / (m * 12))) * 100;
    if (pct <= 0) return null;
    return pct.round();
  }

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
          _selectedPackage = _defaultPackage(packages);
          _yearlySavings = _computeYearlySavings(packages);
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
                        widget.featureName != null
                            ? _unlockFeature(widget.featureName!, lang)
                            : _pt('getAccess', lang),
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

                      // ФАЗА 3.5: ред на ползите — 1) Без реклами, 2) Неограничен
                      // AI, 3) останалите съществуващи.
                      // ФАЗА 3.5 / 1.0.67: само РЕАЛНО Pro функции. „Повтарящи се
                      // задачи" и „Гласов вход" са БЕЗПЛАТНИ (FreeLimits) → махнати.
                      _FeatureItem(icon: Icons.block_rounded, title: _pt('noAds', lang), highlight: true),
                      _FeatureItem(icon: Icons.auto_awesome_rounded, title: _pt('unlimitedAi', lang), highlight: true),
                      _FeatureItem(icon: Icons.all_inclusive, title: _pt('unlimited', lang)),
                      _FeatureItem(icon: Icons.category_rounded, title: _pt('customCat', lang)),
                      _FeatureItem(icon: Icons.notifications_active_rounded, title: _pt('multiRemind', lang)),
                      _FeatureItem(icon: Icons.calendar_month_rounded, title: _pt('calView', lang)),
                      _FeatureItem(icon: Icons.bar_chart_rounded, title: _pt('stats', lang)),
                      _FeatureItem(icon: Icons.cloud_sync_rounded, title: _pt('cloudSync', lang)),
                      _FeatureItem(icon: Icons.widgets_rounded, title: _pt('widget', lang)),
                      _FeatureItem(icon: Icons.celebration_rounded, title: _pt('nameDaysContacts', lang)),
                      _FeatureItem(icon: Icons.group_rounded, title: _pt('sharedLists', lang)),
                      _FeatureItem(icon: Icons.palette_rounded, title: _pt('allThemes', lang)),

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
                      else ...[
                        // Радио-избор: тап само ИЗБИРА плана (не купува веднага).
                        ..._packages.map((package) => _PackageCard(
                              package: package,
                              selected: identical(package, _selectedPackage),
                              savingsPercent: _yearlySavings,
                              lang: lang,
                              onTap: _isPurchasing
                                  ? null
                                  : () => setState(
                                      () => _selectedPackage = package),
                            )),
                        const SizedBox(height: 8),
                        // Единствен бутон за покупка на ИЗБРАНИЯ план.
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                (_isPurchasing || _selectedPackage == null)
                                    ? null
                                    : () => _purchasePackage(_selectedPackage!),
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isPurchasing
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    _continueWith(
                                        _selectedPackage
                                                ?.storeProduct.priceString ??
                                            '',
                                        lang),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () async {
                                final uri = Uri.parse('https://taskify1969.com/terms');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Text(_pt('termsOfUse', lang)),
                            ),
                            const Text(' • '),
                            TextButton(
                              onPressed: () async {
                                final uri = Uri.parse('https://taskify1969.com/privacy');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Text(_pt('privacyPolicy', lang)),
                            ),
                          ],
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
  final bool selected;
  final int? savingsPercent;
  final VoidCallback? onTap;
  final String lang;

  const _PackageCard({
    required this.package,
    required this.selected,
    required this.savingsPercent,
    required this.onTap,
    required this.lang,
  });

  bool get _isLifetime => package.identifier.toLowerCase().contains('lifetime');
  bool get _isYearly {
    final id = package.identifier.toLowerCase();
    return id.contains('annual') || id.contains('yearly');
  }

  bool get _isMonthly => package.identifier.toLowerCase().contains('monthly');

  String _getPackageTitle() {
    if (_isLifetime) return _pt('lifetime', lang);
    if (_isYearly) return _pt('yearly', lang);
    if (_isMonthly) return _pt('monthly', lang);
    return package.storeProduct.title;
  }

  String _getPackageSubtitle() {
    if (_isLifetime) return _pt('oneTime', lang);
    if (_isYearly) {
      // Реална отстъпка, ако е смятаема; иначе неутрален текст (без твърд „50%").
      return savingsPercent != null
          ? _saveN(savingsPercent!, lang)
          : _pt('cancelAnytime', lang);
    }
    if (_isMonthly) return _pt('cancelAnytime', lang);
    return package.storeProduct.description;
  }

  /// ФАЗА 3.2: месечна равностойност на годишния — ДИНАМИЧНО (price/12) с
  /// валутата от стора. Не hardcoded (цените варират по регион).
  String? _monthlyEquivalent() {
    if (!_isYearly) return null;
    final p = package.storeProduct;
    if (p.price <= 0 || p.currencyCode.isEmpty) return null;
    try {
      final f = NumberFormat.simpleCurrency(locale: lang, name: p.currencyCode);
      return '≈ ${f.format(p.price / 12.0)}/${_pt('perMonth', lang)}';
    } catch (_) {
      return null;
    }
  }

  /// ФАЗА 3.3: trial badge САМО ако offering-ът връща безплатен intro offer.
  String? _trialLabel() {
    final intro = package.storeProduct.introductoryPrice;
    if (intro == null || intro.price != 0) return null;
    final days = _introDays(intro);
    if (days == null || days <= 0) return null;
    return _daysFree(days, lang);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = selected; // избраният план = визуален акцент
    final monthlyEq = _monthlyEquivalent();
    final trial = _trialLabel();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: accent
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accent
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.3),
                width: accent ? 2.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  accent
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: accent
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _getPackageTitle(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (trial != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                trial,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
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
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      package.storeProduct.priceString,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (monthlyEq != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        monthlyEq,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
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
  final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PaywallScreen(featureName: featureName)));
  return result == true;
}
