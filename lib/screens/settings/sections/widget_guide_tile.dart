import 'package:flutter/material.dart';

/// Упътване „Как да добавя widget" (iOS). Изнесено от [SettingsScreen] без
/// промяна на поведение — само локализирани текстове + диалог със стъпки.
class WidgetGuideTile extends StatelessWidget {
  const WidgetGuideTile({super.key, required this.lang});

  final String lang;

  // ── Упътване „Как да добавя widget" (iOS) ─────────────────────────────
  static const Map<String, Map<String, String>> _widgetGuide = {
    'title': {
      'en': 'Add the widget', 'bg': 'Добави widget', 'de': 'Widget hinzufügen',
      'fr': 'Ajouter le widget', 'it': 'Aggiungi il widget', 'el': 'Πρόσθεσε το widget',
      'es': 'Añadir el widget', 'pt': 'Adicionar o widget', 'ru': 'Добавить виджет',
      'tr': 'Widget ekle', 'ja': 'ウィジェットを追加',
    },
    'subtitle': {
      'en': "See today's tasks on your Home Screen",
      'bg': 'Виж днешните си задачи на началния екран',
      'de': 'Zeige heutige Aufgaben auf dem Home-Bildschirm',
      'fr': "Vois tes tâches du jour sur l'écran d'accueil",
      'it': 'Vedi le attività di oggi nella schermata Home',
      'el': 'Δες τις σημερινές εργασίες στην αρχική οθόνη',
      'es': 'Ve las tareas de hoy en la pantalla de inicio',
      'pt': 'Vê as tarefas de hoje no ecrã inicial',
      'ru': 'Смотри задачи на сегодня на главном экране',
      'tr': 'Bugünkü görevleri ana ekranda gör',
      'ja': 'ホーム画面で今日のタスクを表示',
    },
    's1': {
      'en': 'Touch and hold an empty spot on the Home Screen.',
      'bg': 'Задръж пръст върху празно място на началния екран.',
      'de': 'Halte eine leere Stelle auf dem Home-Bildschirm gedrückt.',
      'fr': "Appuie longuement sur une zone vide de l'écran d'accueil.",
      'it': 'Tieni premuto uno spazio vuoto nella schermata Home.',
      'el': 'Κράτα πατημένο ένα κενό σημείο στην αρχική οθόνη.',
      'es': 'Mantén pulsado un espacio vacío en la pantalla de inicio.',
      'pt': 'Toca e mantém num espaço vazio do ecrã inicial.',
      'ru': 'Нажми и удерживай пустое место на главном экране.',
      'tr': 'Ana ekranda boş bir yere basılı tut.',
      'ja': 'ホーム画面の空いている場所を長押しします。',
    },
    's2': {
      'en': 'Tap the + button in the top corner.',
      'bg': 'Натисни бутона + в горния ъгъл.',
      'de': 'Tippe auf + in der oberen Ecke.',
      'fr': 'Touche le bouton + dans le coin supérieur.',
      'it': 'Tocca il pulsante + in alto.',
      'el': 'Πάτησε το + στην επάνω γωνία.',
      'es': 'Toca el botón + en la esquina superior.',
      'pt': 'Toca no botão + no canto superior.',
      'ru': 'Нажми кнопку + в верхнем углу.',
      'tr': 'Üst köşedeki + düğmesine dokun.',
      'ja': '上隅の + ボタンをタップします。',
    },
    's3': {
      'en': 'Search for “Taskify”.', 'bg': 'Потърси „Taskify".',
      'de': 'Suche nach „Taskify".', 'fr': 'Cherche « Taskify ».',
      'it': 'Cerca “Taskify”.', 'el': 'Αναζήτησε «Taskify».',
      'es': 'Busca «Taskify».', 'pt': 'Procura “Taskify”.',
      'ru': 'Найди «Taskify».', 'tr': '“Taskify” ara.', 'ja': '「Taskify」を検索します。',
    },
    's4': {
      'en': 'Pick a size and tap “Add Widget”.',
      'bg': 'Избери размер и натисни „Добави widget".',
      'de': 'Wähle eine Größe und tippe auf „Widget hinzufügen".',
      'fr': 'Choisis une taille et touche « Ajouter le widget ».',
      'it': 'Scegli una dimensione e tocca “Aggiungi widget”.',
      'el': 'Διάλεξε μέγεθος και πάτησε «Προσθήκη widget».',
      'es': 'Elige un tamaño y toca «Añadir widget».',
      'pt': 'Escolhe um tamanho e toca “Adicionar widget”.',
      'ru': 'Выбери размер и нажми «Добавить виджет».',
      'tr': 'Bir boyut seç ve “Widget Ekle”ye dokun.',
      'ja': 'サイズを選んで「ウィジェットを追加」をタップします。',
    },
    'ok': {
      'en': 'Got it', 'bg': 'Разбрах', 'de': 'Verstanden', 'fr': 'Compris',
      'it': 'Ho capito', 'el': 'Κατάλαβα', 'es': 'Entendido', 'pt': 'Percebi',
      'ru': 'Понятно', 'tr': 'Anladım', 'ja': 'わかりました',
    },
  };

  static String _wg(String k, String lang) =>
      _widgetGuide[k]?[lang] ?? _widgetGuide[k]?['en'] ?? '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6A3DE8).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.widgets_outlined, color: Color(0xFF6A3DE8)),
          ),
          title: Text(_wg('title', lang)),
          subtitle: Text(_wg('subtitle', lang)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(_wg('title', lang)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in ['s1', 's2', 's3', 's4'])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${['s1', 's2', 's3', 's4'].indexOf(s) + 1}.  ',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(child: Text(_wg(s, lang))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_wg('ok', lang)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
