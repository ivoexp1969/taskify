with open('lib/screens/task/task_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

seen = set()
new_lines = []
for line in lines:
    stripped = line.strip()
    if stripped.startswith('import') and stripped in seen:
        print('Removed duplicate:', stripped)
        continue
    if stripped.startswith('import'):
        seen.add(stripped)
    new_lines.append(line)

with open('lib/screens/task/task_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print('FIXED')
