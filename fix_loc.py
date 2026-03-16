with open('lib/utils/localization.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

to_remove = []
for i, line in enumerate(lines):
    if any(x in line for x in [
        'String get backupSubject =>',
        'String get catWork =>',
        'String get catPersonal =>',
        'String get catShopping =>',
        'String get catBirthdays =>',
        'String get catOutOfOffice =>',
        'String get catFocusTime =>',
        'String get catWorkLocation =>',
        'String get catCalendarEvents =>'
    ]):
        to_remove.append(i)

# Намираме дубликатите - тези след ред 500
duplicates = [i for i in to_remove if i > 500]
print('Removing lines:', [i+1 for i in duplicates])

for i in sorted(duplicates, reverse=True):
    lines.pop(i)

with open('lib/utils/localization.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('FIXED')
