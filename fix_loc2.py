with open('lib/utils/localization.dart', 'r', encoding='utf-8') as f:
    content = f.read()

marker = "String get untitledTask => _t("
pos = content.find(marker)
end_of_line = content.find('\n', pos) + 1

keys = (
"  String get backupSubject => _t({'en': 'Taskify Backup', 'bg': 'Taskify Архив', 'de': 'Taskify Sicherung', 'fr': 'Sauvegarde Taskify', 'it': 'Backup Taskify', 'el': 'Αντίγραφο Taskify', 'es': 'Copia de Taskify', 'pt': 'Backup Taskify', 'ru': 'Резервная копия Taskify', 'tr': 'Taskify Yedek'});\n"
"  String get catWork => _t({'en': 'Work', 'bg': 'Работа', 'de': 'Arbeit', 'fr': 'Travail', 'it': 'Lavoro', 'el': 'Εργασία', 'es': 'Trabajo', 'pt': 'Trabalho', 'ru': 'Работа', 'tr': 'İş'});\n"
"  String get catPersonal => _t({'en': 'Personal', 'bg': 'Лични', 'de': 'Persönlich', 'fr': 'Personnel', 'it': 'Personale', 'el': 'Προσωπικά', 'es': 'Personal', 'pt': 'Pessoal', 'ru': 'Личное', 'tr': 'Kişisel'});\n"
"  String get catShopping => _t({'en': 'Shopping', 'bg': 'Пазаруване', 'de': 'Einkaufen', 'fr': 'Courses', 'it': 'Acquisti', 'el': 'Αγορές', 'es': 'Compras', 'pt': 'Compras', 'ru': 'Покупки', 'tr': 'Alışveriş'});\n"
"  String get catBirthdays => _t({'en': 'Birthdays', 'bg': 'Рождени дни', 'de': 'Geburtstage', 'fr': 'Anniversaires', 'it': 'Compleanni', 'el': 'Γενέθλια', 'es': 'Cumpleaños', 'pt': 'Aniversários', 'ru': 'Дни рождения', 'tr': 'Doğum günleri'});\n"
"  String get catOutOfOffice => _t({'en': 'Out of Office', 'bg': 'Извън офиса', 'de': 'Außer Haus', 'fr': 'Hors du bureau', 'it': 'Fuori ufficio', 'el': 'Εκτός γραφείου', 'es': 'Fuera de la oficina', 'pt': 'Fora do escritório', 'ru': 'Вне офиса', 'tr': 'Ofis dışında'});\n"
"  String get catFocusTime => _t({'en': 'Focus Time', 'bg': 'Фокус', 'de': 'Fokuszeit', 'fr': 'Temps de concentration', 'it': 'Tempo di concentrazione', 'el': 'Χρόνος εστίασης', 'es': 'Tiempo de enfoque', 'pt': 'Tempo de foco', 'ru': 'Время фокуса', 'tr': 'Odaklanma zamanı'});\n"
"  String get catWorkLocation => _t({'en': 'Work Location', 'bg': 'Работно място', 'de': 'Arbeitsort', 'fr': 'Lieu de travail', 'it': 'Luogo di lavoro', 'el': 'Τοποθεσία εργασίας', 'es': 'Ubicación de trabajo', 'pt': 'Local de trabalho', 'ru': 'Место работы', 'tr': 'Çalışma yeri'});\n"
"  String get catCalendarEvents => _t({'en': 'Calendar Events', 'bg': 'Календарни събития', 'de': 'Kalendereinträge', 'fr': 'Événements du calendrier', 'it': 'Eventi del calendario', 'el': 'Εκδηλώσεις ημερολογίου', 'es': 'Eventos del calendario', 'pt': 'Eventos do calendário', 'ru': 'События календаря', 'tr': 'Takvim etkinlikleri'});\n"
)

content = content[:end_of_line] + keys + content[end_of_line:]

with open('lib/utils/localization.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('FIXED')
