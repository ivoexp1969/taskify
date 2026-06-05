import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/expiring_document.dart';
import '../../services/documents_service.dart';
import '../../utils/localization.dart';

/// Раздел „България" — местни функции, отделени от основния поток.
/// Засега: документи с изтичащ срок (винетка, ГО, тех. преглед и др.).
class BulgariaScreen extends StatefulWidget {
  const BulgariaScreen({super.key});

  @override
  State<BulgariaScreen> createState() => _BulgariaScreenState();
}

class _BulgariaScreenState extends State<BulgariaScreen> {
  List<ExpiringDocument> _docs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    DocumentsService.revision.addListener(_load);
  }

  @override
  void dispose() {
    DocumentsService.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final docs = await DocumentsService().getAll();
    if (!mounted) return;
    setState(() {
      _docs = docs;
      _loading = false;
    });
  }

  String get _lang => LanguageScope.of(context).locale.languageCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_tr(_sectionTitle)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: Text(_tr(_addBtn)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _docs.isEmpty
              ? _buildEmpty(theme)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  itemCount: _docs.length,
                  itemBuilder: (_, i) => _buildCard(_docs[i], theme),
                ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_rounded,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              _tr(_emptyState),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(ExpiringDocument doc, ThemeData theme) {
    final daysLeft = doc.daysLeft;
    final urgencyColor = doc.isExpired
        ? Colors.red
        : daysLeft <= 7
            ? Colors.orange
            : daysLeft <= 30
                ? Colors.amber.shade700
                : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: urgencyColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_iconFor(doc.type), color: urgencyColor),
        ),
        title: Text(documentTypeName(doc.type, _lang, label: doc.label)),
        subtitle: Text(
          _statusLine(doc),
          style: TextStyle(
            fontSize: 12,
            color: urgencyColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _openEditor(doc: doc);
            if (v == 'delete') _confirmDelete(doc);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(_tr(_editBtn))),
            PopupMenuItem(value: 'delete', child: Text(_tr(_deleteBtn))),
          ],
        ),
        onTap: () => _openEditor(doc: doc),
      ),
    );
  }

  String _statusLine(ExpiringDocument doc) {
    final d = doc.daysLeft;
    final dateStr =
        '${doc.expiryDate.day.toString().padLeft(2, '0')}.${doc.expiryDate.month.toString().padLeft(2, '0')}.${doc.expiryDate.year}';
    if (d < 0) {
      return '${_tr(_expiredOn)} $dateStr';
    } else if (d == 0) {
      return _tr(_expiresToday);
    } else {
      return _tr(_expiresInPrefix)
              .replaceAll('{days}', '$d') +
          ' · $dateStr';
    }
  }

  Future<void> _confirmDelete(ExpiringDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tr(_deleteBtn)),
        content: Text(documentTypeName(doc.type, _lang, label: doc.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tr(_cancelBtn)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tr(_deleteBtn)),
          ),
        ],
      ),
    );
    if (ok == true) await DocumentsService().delete(doc);
  }

  Future<void> _openEditor({ExpiringDocument? doc}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DocumentEditor(doc: doc, lang: _lang),
    );
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case 'vignette':
        return Icons.toll_rounded;
      case 'insurance':
        return Icons.verified_user_rounded;
      case 'inspection':
        return Icons.car_repair_rounded;
      case 'id_card':
        return Icons.badge_rounded;
      case 'passport':
        return Icons.menu_book_rounded;
      case 'license':
        return Icons.directions_car_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  // --- Локализация ---
  String _tr(Map<String, String> m) => m[_lang] ?? m['en']!;
}

const _sectionTitle = {
  'en': 'Bulgaria', 'bg': 'България', 'de': 'Bulgarien', 'fr': 'Bulgarie',
  'it': 'Bulgaria', 'el': 'Βουλγαρία', 'es': 'Bulgaria', 'pt': 'Bulgária',
  'ru': 'Болгария', 'tr': 'Bulgaristan',
};
const _addBtn = {
  'en': 'Add', 'bg': 'Добави', 'de': 'Hinzufügen', 'fr': 'Ajouter',
  'it': 'Aggiungi', 'el': 'Προσθήκη', 'es': 'Añadir', 'pt': 'Adicionar',
  'ru': 'Добавить', 'tr': 'Ekle',
};
const _editBtn = {
  'en': 'Edit', 'bg': 'Редактирай', 'de': 'Bearbeiten', 'fr': 'Modifier',
  'it': 'Modifica', 'el': 'Επεξεργασία', 'es': 'Editar', 'pt': 'Editar',
  'ru': 'Изменить', 'tr': 'Düzenle',
};
const _deleteBtn = {
  'en': 'Delete', 'bg': 'Изтрий', 'de': 'Löschen', 'fr': 'Supprimer',
  'it': 'Elimina', 'el': 'Διαγραφή', 'es': 'Eliminar', 'pt': 'Excluir',
  'ru': 'Удалить', 'tr': 'Sil',
};
const _cancelBtn = {
  'en': 'Cancel', 'bg': 'Отказ', 'de': 'Abbrechen', 'fr': 'Annuler',
  'it': 'Annulla', 'el': 'Ακύρωση', 'es': 'Cancelar', 'pt': 'Cancelar',
  'ru': 'Отмена', 'tr': 'İptal',
};
const _emptyState = {
  'en': 'Keep your important dates here — documents, holidays, name days. Start by adding your first one.',
  'bg': 'Тук ще пазиш важните си дати — документи, празници, именни дни. Започни, като добавиш първото.',
  'de': 'Bewahre hier deine wichtigen Termine auf — Dokumente, Feiertage, Namenstage. Füge den ersten hinzu.',
  'fr': 'Garde ici tes dates importantes — documents, fêtes, fêtes des prénoms. Commence par en ajouter une.',
  'it': 'Conserva qui le tue date importanti — documenti, festività, onomastici. Inizia aggiungendone una.',
  'el': 'Κράτα εδώ τις σημαντικές σου ημερομηνίες — έγγραφα, αργίες, ονομαστικές εορτές. Πρόσθεσε την πρώτη.',
  'es': 'Guarda aquí tus fechas importantes — documentos, festivos, onomásticas. Empieza añadiendo una.',
  'pt': 'Guarda aqui as tuas datas importantes — documentos, feriados, dias do nome. Começa por adicionar uma.',
  'ru': 'Храни здесь важные даты — документы, праздники, именины. Начни с первой.',
  'tr': 'Önemli tarihlerini burada sakla — belgeler, tatiller, isim günleri. İlkini ekleyerek başla.',
};
const _expiresInPrefix = {
  'en': 'Expires in {days} days', 'bg': 'Изтича след {days} дни',
  'de': 'Läuft in {days} Tagen ab', 'fr': 'Expire dans {days} jours',
  'it': 'Scade tra {days} giorni', 'el': 'Λήγει σε {days} ημέρες',
  'es': 'Caduca en {days} días', 'pt': 'Expira em {days} dias',
  'ru': 'Истекает через {days} дней', 'tr': '{days} gün içinde doluyor',
};
const _expiresToday = {
  'en': 'Expires today', 'bg': 'Изтича днес', 'de': 'Läuft heute ab',
  'fr': "Expire aujourd'hui", 'it': 'Scade oggi', 'el': 'Λήγει σήμερα',
  'es': 'Caduca hoy', 'pt': 'Expira hoje', 'ru': 'Истекает сегодня',
  'tr': 'Bugün doluyor',
};
const _expiredOn = {
  'en': 'Expired on', 'bg': 'Изтекъл на', 'de': 'Abgelaufen am',
  'fr': 'Expiré le', 'it': 'Scaduto il', 'el': 'Έληξε στις',
  'es': 'Caducó el', 'pt': 'Expirou em', 'ru': 'Истёк', 'tr': 'Doldu:',
};

/// Долен лист за добавяне/редакция на документ.
class _DocumentEditor extends StatefulWidget {
  final ExpiringDocument? doc;
  final String lang;
  const _DocumentEditor({this.doc, required this.lang});

  @override
  State<_DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<_DocumentEditor> {
  static const _types = [
    'vignette',
    'insurance',
    'inspection',
    'id_card',
    'passport',
    'license',
    'other',
  ];
  static const _reminderOptions = [60, 30, 14, 7, 3, 1];

  late String _type;
  late TextEditingController _labelCtrl;
  DateTime? _expiry;
  late Set<int> _reminders;

  @override
  void initState() {
    super.initState();
    final d = widget.doc;
    _type = d?.type ?? 'vignette';
    _labelCtrl = TextEditingController(text: d?.label ?? '');
    _expiry = d?.expiryDate;
    _reminders = {...(d?.reminderDays ?? const [30, 7, 1])};
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  String _tr(Map<String, String> m) => m[widget.lang] ?? m['en']!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final canSave = _expiry != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(_tr(_typeLabel),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((t) {
                final selected = t == _type;
                return ChoiceChip(
                  label: Text(documentTypeName(t, widget.lang)),
                  selected: selected,
                  onSelected: (_) => setState(() => _type = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Свободно име (по желание; за „друго" е по-важно)
            TextField(
              controller: _labelCtrl,
              decoration: InputDecoration(
                labelText: _tr(_optionalLabel),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            // Дата на изтичане
            Text(_tr(_expiryLabel),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(_expiry == null
                  ? _tr(_pickDate0)
                  : '${_expiry!.day.toString().padLeft(2, '0')}.${_expiry!.month.toString().padLeft(2, '0')}.${_expiry!.year}'),
            ),
            const SizedBox(height: 16),
            // Напомняния
            Text(_tr(_remindersLabel),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            // Web е безплатна lite версия без локални нотификации — показваме
            // датите, но напомнянията са само в мобилното приложение.
            if (kIsWeb)
              Text(
                _tr(_remindersWebOnly),
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                children: _reminderOptions.map((d) {
                  final on = _reminders.contains(d);
                  return FilterChip(
                    label: Text(_tr(_daysBefore).replaceAll('{days}', '$d')),
                    selected: on,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _reminders.add(d);
                      } else {
                        _reminders.remove(d);
                      }
                    }),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(_tr(_cancelBtn)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: canSave ? _save : null,
                    child: Text(_tr(_saveBtn)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) {
      setState(() =>
          _expiry = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    if (_expiry == null) return;
    final existing = widget.doc;
    final doc = ExpiringDocument(
      id: existing?.id ??
          'doc_${DateTime.now().microsecondsSinceEpoch}',
      type: _type,
      label: _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
      expiryDate: _expiry!,
      reminderDays: (_reminders.toList()..sort((a, b) => b.compareTo(a))),
      notificationIds: existing?.notificationIds ?? [],
    );
    await DocumentsService().save(doc);
    if (mounted) Navigator.pop(context);
  }
}

const _typeLabel = {
  'en': 'Type', 'bg': 'Тип', 'de': 'Typ', 'fr': 'Type', 'it': 'Tipo',
  'el': 'Τύπος', 'es': 'Tipo', 'pt': 'Tipo', 'ru': 'Тип', 'tr': 'Tür',
};
const _optionalLabel = {
  'en': 'Name (optional)', 'bg': 'Име (по желание)', 'de': 'Name (optional)',
  'fr': 'Nom (facultatif)', 'it': 'Nome (facoltativo)',
  'el': 'Όνομα (προαιρετικό)', 'es': 'Nombre (opcional)',
  'pt': 'Nome (opcional)', 'ru': 'Название (необязательно)',
  'tr': 'Ad (isteğe bağlı)',
};
const _expiryLabel = {
  'en': 'Expiry date', 'bg': 'Дата на изтичане', 'de': 'Ablaufdatum',
  'fr': "Date d'expiration", 'it': 'Data di scadenza',
  'el': 'Ημερομηνία λήξης', 'es': 'Fecha de caducidad',
  'pt': 'Data de validade', 'ru': 'Дата окончания', 'tr': 'Bitiş tarihi',
};
const _pickDate0 = {
  'en': 'Pick a date', 'bg': 'Избери дата', 'de': 'Datum wählen',
  'fr': 'Choisir une date', 'it': 'Scegli una data',
  'el': 'Επίλεξε ημερομηνία', 'es': 'Elige una fecha',
  'pt': 'Escolhe uma data', 'ru': 'Выбери дату', 'tr': 'Tarih seç',
};
const _remindersLabel = {
  'en': 'Remind me', 'bg': 'Напомни ми', 'de': 'Erinnere mich',
  'fr': 'Me rappeler', 'it': 'Ricordamelo', 'el': 'Υπενθύμισέ μου',
  'es': 'Recordarme', 'pt': 'Lembrar-me', 'ru': 'Напомнить', 'tr': 'Hatırlat',
};
const _daysBefore = {
  'en': '{days} days before', 'bg': '{days} дни преди',
  'de': '{days} Tage vorher', 'fr': '{days} jours avant',
  'it': '{days} giorni prima', 'el': '{days} ημέρες πριν',
  'es': '{days} días antes', 'pt': '{days} dias antes',
  'ru': 'за {days} дней', 'tr': '{days} gün önce',
};
const _remindersWebOnly = {
  'en': 'Reminders work in the mobile app 📱',
  'bg': 'Напомнянията работят в мобилното приложение 📱',
  'de': 'Erinnerungen funktionieren in der App 📱',
  'fr': 'Les rappels fonctionnent dans l\'app mobile 📱',
  'it': 'I promemoria funzionano nell\'app mobile 📱',
  'el': 'Οι υπενθυμίσεις λειτουργούν στην εφαρμογή 📱',
  'es': 'Los recordatorios funcionan en la app móvil 📱',
  'pt': 'Os lembretes funcionam na app móvel 📱',
  'ru': 'Напоминания работают в мобильном приложении 📱',
  'tr': 'Hatırlatmalar mobil uygulamada çalışır 📱',
};
const _saveBtn = {
  'en': 'Save', 'bg': 'Запази', 'de': 'Speichern', 'fr': 'Enregistrer',
  'it': 'Salva', 'el': 'Αποθήκευση', 'es': 'Guardar', 'pt': 'Guardar',
  'ru': 'Сохранить', 'tr': 'Kaydet',
};
