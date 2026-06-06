import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expiring_document.dart';
import 'notification_service.dart';

/// Управлява документите с изтичащ срок (Hive + локални нотификации).
/// Данните са изцяло локални; нищо не се тегли от мрежата.
class DocumentsService {
  DocumentsService._internal();
  static final DocumentsService _instance = DocumentsService._internal();
  factory DocumentsService() => _instance;

  static const String boxName = 'bg_documents';
  static const String _counterKey = 'doc_notif_counter';
  static const int _notifBase = 9200; // диапазон за нотификации на документи
  static const int _notifHour = 9; // час на напомнянето

  /// Известява списъка с документи за промени (екранът слуша).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<Box> _openBox() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
    return Hive.openBox(boxName);
  }

  /// Всички документи, сортирани по дата на изтичане (най-близкият първи).
  Future<List<ExpiringDocument>> getAll() async {
    final box = await _openBox();
    final list = <ExpiringDocument>[];
    for (final v in box.values) {
      if (v is String && v.isNotEmpty) {
        try {
          list.add(ExpiringDocument.fromJson(
              json.decode(v) as Map<String, dynamic>));
        } catch (_) {/* пропускаме повреден запис */}
      }
    }
    list.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return list;
  }

  /// Добавя или обновява документ (пренасрочва нотификациите).
  Future<void> save(ExpiringDocument doc) async {
    // Отменяме старите нотификации, преди да планираме наново.
    await _cancel(doc);
    doc.notificationIds = await _schedule(doc);

    final box = await _openBox();
    await box.put(doc.id, json.encode(doc.toJson()));
    revision.value++;
  }

  /// Изтрива документ и отменя нотификациите му.
  Future<void> delete(ExpiringDocument doc) async {
    await _cancel(doc);
    final box = await _openBox();
    await box.delete(doc.id);
    revision.value++;
  }

  Future<void> _cancel(ExpiringDocument doc) async {
    for (final id in doc.notificationIds) {
      await NotificationService().cancelNotification(id);
    }
  }

  /// Планира по едно напомняне за всеки `reminderDays` преди изтичането.
  /// Връща новите notification id-та. Пропуска вече минали дати.
  Future<List<int>> _schedule(ExpiringDocument doc) async {
    final ids = <int>[];
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    int counter = prefs.getInt(_counterKey) ?? 0;

    final lang = prefs.getString('app_language') ?? 'en';

    for (final days in doc.reminderDays) {
      // Денят на напомнянето = изтичане - days, в _notifHour часа.
      final fire = DateTime(doc.expiryDate.year, doc.expiryDate.month,
          doc.expiryDate.day - days, _notifHour);
      if (fire.isBefore(now)) continue;

      final id = _notifBase + (counter % 700);
      counter++;

      await NotificationService().scheduleNotification(
        id: id,
        title: _title(lang),
        body: _body(doc, days, lang),
        scheduledDate: fire,
      );
      ids.add(id);
    }

    await prefs.setInt(_counterKey, counter);
    return ids;
  }

  String _title(String lang) {
    const m = {
      'en': 'Renewal reminder', 'bg': 'Напомняне за подновяване',
      'de': 'Erinnerung zur Verlängerung', 'fr': 'Rappel de renouvellement',
      'it': 'Promemoria di rinnovo', 'el': 'Υπενθύμιση ανανέωσης',
      'es': 'Recordatorio de renovación', 'pt': 'Lembrete de renovação',
      'ru': 'Напоминание о продлении', 'tr': 'Yenileme hatırlatması', 'ja': '更新のリマインダー',
    };
    return m[lang] ?? m['en']!;
  }

  /// Топъл, личен текст: „Винетката ти изтича след 7 дни — време е за подновяване".
  String _body(ExpiringDocument doc, int days, String lang) {
    final name = documentTypeName(doc.type, lang, label: doc.label);
    const tpl = {
      'en': '{name} expires in {days} days — time to renew 🔔',
      'bg': '{name} изтича след {days} дни — време е за подновяване 🔔',
      'de': '{name} läuft in {days} Tagen ab — Zeit zu verlängern 🔔',
      'fr': '{name} expire dans {days} jours — pense à renouveler 🔔',
      'it': '{name} scade tra {days} giorni — è ora di rinnovare 🔔',
      'el': '{name} λήγει σε {days} ημέρες — ώρα για ανανέωση 🔔',
      'es': '{name} caduca en {days} días — hora de renovar 🔔',
      'pt': '{name} expira em {days} dias — hora de renovar 🔔',
      'ru': '{name} истекает через {days} дней — пора продлить 🔔',
      'tr': '{name} {days} gün içinde doluyor — yenileme zamanı 🔔', 'ja': '{name}は{days}日後に期限切れ — 更新時期です 🔔',
    };
    final t = tpl[lang] ?? tpl['en']!;
    return t.replaceAll('{name}', name).replaceAll('{days}', '$days');
  }
}

/// Локализирано име на типа документ. За 'other' ползва потребителския label.
String documentTypeName(String type, String lang, {String? label}) {
  if (type == 'other') {
    return (label != null && label.trim().isNotEmpty)
        ? label.trim()
        : _otherName(lang);
  }
  final m = _typeNames[type];
  final base = m != null ? (m[lang] ?? m['en']!) : type;
  // Ако има допълнителен label, добавяме го в скоби.
  if (label != null && label.trim().isNotEmpty) {
    return '$base (${label.trim()})';
  }
  return base;
}

String _otherName(String lang) {
  const m = {
    'en': 'Document', 'bg': 'Документ', 'de': 'Dokument', 'fr': 'Document',
    'it': 'Documento', 'el': 'Έγγραφο', 'es': 'Documento', 'pt': 'Documento',
    'ru': 'Документ', 'tr': 'Belge', 'ja': '書類',
  };
  return m[lang] ?? m['en']!;
}

/// Имена на типовете документи на 10 езика.
const Map<String, Map<String, String>> _typeNames = {
  'vignette': {
    'en': 'Vignette', 'bg': 'Винетка', 'de': 'Vignette', 'fr': 'Vignette',
    'it': 'Vignetta', 'el': 'Βινιέτα', 'es': 'Viñeta', 'pt': 'Vinheta',
    'ru': 'Виньетка', 'tr': 'Vinyet', 'ja': '高速道路ステッカー',
  },
  'insurance': {
    'en': 'Car insurance', 'bg': 'Гражданска отговорност',
    'de': 'Kfz-Haftpflicht', 'fr': 'Assurance auto',
    'it': 'Assicurazione auto', 'el': 'Ασφάλεια αυτοκινήτου',
    'es': 'Seguro del coche', 'pt': 'Seguro do carro',
    'ru': 'Автостраховка', 'tr': 'Trafik sigortası', 'ja': '自動車保険',
  },
  'inspection': {
    'en': 'Vehicle inspection', 'bg': 'Технически преглед',
    'de': 'Hauptuntersuchung', 'fr': 'Contrôle technique',
    'it': 'Revisione auto', 'el': 'Τεχνικός έλεγχος (ΚΤΕΟ)',
    'es': 'Inspección técnica (ITV)', 'pt': 'Inspeção do veículo',
    'ru': 'Техосмотр', 'tr': 'Araç muayenesi', 'ja': '車検',
  },
  'id_card': {
    'en': 'ID card', 'bg': 'Лична карта', 'de': 'Personalausweis',
    'fr': "Carte d'identité", 'it': "Carta d'identità",
    'el': 'Ταυτότητα', 'es': 'DNI', 'pt': 'Cartão de cidadão',
    'ru': 'Удостоверение личности', 'tr': 'Kimlik kartı', 'ja': '身分証明書',
  },
  'passport': {
    'en': 'Passport', 'bg': 'Паспорт', 'de': 'Reisepass', 'fr': 'Passeport',
    'it': 'Passaporto', 'el': 'Διαβατήριο', 'es': 'Pasaporte',
    'pt': 'Passaporte', 'ru': 'Паспорт', 'tr': 'Pasaport', 'ja': 'パスポート',
  },
  'license': {
    'en': "Driver's license", 'bg': 'Шофьорска книжка',
    'de': 'Führerschein', 'fr': 'Permis de conduire',
    'it': 'Patente di guida', 'el': 'Δίπλωμα οδήγησης',
    'es': 'Carnet de conducir', 'pt': 'Carta de condução',
    'ru': 'Водительские права', 'tr': 'Ehliyet', 'ja': '運転免許証',
  },
};
