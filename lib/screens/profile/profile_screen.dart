import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../services/school_calendar_service.dart';
import '../../services/university_service.dart';
import '../../models/university.dart';
import '../../utils/localization.dart';
import '../modes/student_onboarding_screen.dart';
import '../settings/delete_account_flow.dart';

/// Екран „Профил" (Пакет 2, Фаза 1) — извикан от картата „Профил" горе в
/// Настройки. Съдържа: Акаунт (име/имейл/изход), Режим (винаги видим — активен
/// режим ИЛИ активиране), Опасна зона (изтрий акаунт).
///
/// ★ЧИСТА UI/навигация★ — преизползва съществуващата логика (AuthService,
/// SchoolCalendarService, UniversityService, StudentOnboardingScreen,
/// DeleteAccountFlow). Нищо от тях не се пипа.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final _school = SchoolCalendarService();
  final _uni = UniversityService();

  static String _t(Map<String, String> m, String lang) => m[lang] ?? m['en']!;

  // ── Локализирани стрингове (нови за Профил) ──
  static const _titleProfile = {
    'en': 'Profile', 'bg': 'Профил', 'de': 'Profil', 'fr': 'Profil',
    'it': 'Profilo', 'el': 'Προφίλ', 'es': 'Perfil', 'pt': 'Perfil',
    'ru': 'Профиль', 'tr': 'Profil', 'ja': 'プロフィール',
  };
  static const _modeSection = {
    'en': 'Mode', 'bg': 'Режим', 'de': 'Modus', 'fr': 'Mode', 'it': 'Modalità',
    'el': 'Λειτουργία', 'es': 'Modo', 'pt': 'Modo', 'ru': 'Режим',
    'tr': 'Mod', 'ja': 'モード',
  };
  static const _activateMode = {
    'en': 'Activate a mode', 'bg': 'Активирай режим', 'de': 'Modus aktivieren',
    'fr': 'Activer un mode', 'it': 'Attiva una modalità', 'el': 'Ενεργοποίηση λειτουργίας',
    'es': 'Activar un modo', 'pt': 'Ativar um modo', 'ru': 'Активируй режим',
    'tr': 'Bir mod etkinleştir', 'ja': 'モードを有効化',
  };
  static const _pupil = {
    'en': 'Pupil', 'bg': 'Ученик', 'de': 'Schüler', 'fr': 'Élève', 'it': 'Alunno',
    'el': 'Μαθητής', 'es': 'Alumno', 'pt': 'Aluno', 'ru': 'Ученик',
    'tr': 'Öğrenci', 'ja': '生徒',
  };
  static const _student = {
    'en': 'Student', 'bg': 'Студент', 'de': 'Student', 'fr': 'Étudiant',
    'it': 'Studente', 'el': 'Φοιτητής', 'es': 'Estudiante', 'pt': 'Estudante',
    'ru': 'Студент', 'tr': 'Üniversite', 'ja': '大学生',
  };
  static const _gradeWord = {
    'en': 'grade', 'bg': 'клас', 'de': 'Klasse', 'fr': 'classe', 'it': 'classe',
    'el': 'τάξη', 'es': 'grado', 'pt': 'ano', 'ru': 'класс', 'tr': 'sınıf',
    'ja': '年生',
  };
  static const _yearWord = {
    'en': 'year', 'bg': 'курс', 'de': 'Studienjahr', 'fr': 'année', 'it': 'anno',
    'el': 'έτος', 'es': 'curso', 'pt': 'ano', 'ru': 'курс', 'tr': 'sınıf',
    'ja': '年',
  };
  static const _switchToStudent = {
    'en': 'Switch to Student', 'bg': 'Смени на Студент', 'de': 'Zu Student wechseln',
    'fr': 'Passer à Étudiant', 'it': 'Passa a Studente', 'el': 'Άλλαξε σε Φοιτητή',
    'es': 'Cambiar a Estudiante', 'pt': 'Mudar para Estudante',
    'ru': 'Переключить на Студента', 'tr': 'Üniversiteye geç', 'ja': '大学生に切替',
  };
  static const _switchToPupil = {
    'en': 'Switch to Pupil', 'bg': 'Смени на Ученик', 'de': 'Zu Schüler wechseln',
    'fr': 'Passer à Élève', 'it': 'Passa a Alunno', 'el': 'Άλλαξε σε Μαθητή',
    'es': 'Cambiar a Alumno', 'pt': 'Mudar para Aluno',
    'ru': 'Переключить на Ученика', 'tr': 'Öğrenciye geç', 'ja': '生徒に切替',
  };
  static const _turnOffMode = {
    'en': 'Turn off mode', 'bg': 'Изключи режима', 'de': 'Modus ausschalten',
    'fr': 'Désactiver le mode', 'it': 'Disattiva la modalità', 'el': 'Απενεργοποίηση',
    'es': 'Desactivar el modo', 'pt': 'Desativar o modo', 'ru': 'Выключить режим',
    'tr': 'Modu kapat', 'ja': 'モードをオフ',
  };
  static const _dangerZone = {
    'en': 'Danger zone', 'bg': 'Опасна зона', 'de': 'Gefahrenzone',
    'fr': 'Zone dangereuse', 'it': 'Zona pericolosa', 'el': 'Ζώνη κινδύνου',
    'es': 'Zona de peligro', 'pt': 'Zona de perigo', 'ru': 'Опасная зона',
    'tr': 'Tehlikeli bölge', 'ja': '危険ゾーン',
  };
  static const _formLabels = {
    'redovno': {
      'en': 'Full-time', 'bg': 'редовно', 'de': 'Vollzeit', 'fr': 'temps plein',
      'it': 'tempo pieno', 'el': 'πλήρης', 'es': 'presencial', 'pt': 'tempo integral',
      'ru': 'очно', 'tr': 'örgün', 'ja': '通学',
    },
    'zadochno': {
      'en': 'Part-time', 'bg': 'задочно', 'de': 'Teilzeit', 'fr': 'temps partiel',
      'it': 'part-time', 'el': 'μερική', 'es': 'semipresencial', 'pt': 'tempo parcial',
      'ru': 'заочно', 'tr': 'ikinci öğretim', 'ja': '夜間',
    },
    'distancionno': {
      'en': 'Distance', 'bg': 'дистанционно', 'de': 'Fernstudium', 'fr': 'à distance',
      'it': 'a distanza', 'el': 'εξ αποστάσεως', 'es': 'a distancia', 'pt': 'à distância',
      'ru': 'дистанционно', 'tr': 'uzaktan', 'ja': '通信',
    },
  };

  // ── Режим: активиране / смяна / изключване (същата логика като Настройки) ──

  Future<int?> _pickGrade(String lang) {
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;
    const question = {
      'en': 'Which grade are you in?', 'bg': 'В кой клас си?',
      'de': 'In welcher Klasse bist du?', 'fr': 'Tu es en quelle classe ?',
      'it': 'In che classe sei?', 'el': 'Σε ποια τάξη είσαι;',
      'es': '¿En qué grado estás?', 'pt': 'Em que ano estás?',
      'ru': 'В каком ты классе?', 'tr': 'Hangi sınıftasın?', 'ja': '何年生ですか？',
    };
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(question)),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(12, (i) {
              final g = i + 1;
              return ChoiceChip(
                label: Text('$g'),
                selected: _school.grade == g,
                onSelected: (_) => Navigator.pop(ctx, g),
              );
            }),
          ),
        ),
      ),
    );
  }

  Future<void> _enablePupil(String lang) async {
    final g = await _pickGrade(lang);
    if (g == null) return;
    await _school.setGrade(g);
    await _school.setEnabled(true);
    await _school.load();
    await _uni.setEnabled(false); // взаимно изключващи се
    if (mounted) setState(() {});
  }

  Future<void> _enableStudent() async {
    await _uni.loadUniversities();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudentOnboardingScreen()),
    );
    // Онбордингът изключва Ученик при запис (взаимно изключване).
    if (mounted) setState(() {});
  }

  Future<void> _disablePupil() async {
    await _school.setEnabled(false);
    if (mounted) setState(() {});
  }

  Future<void> _disableStudent() async {
    await _uni.setEnabled(false);
    if (mounted) setState(() {});
  }

  // ── Акаунт (преизползва логиката от Настройки) ──

  Future<void> _editName(AppText t) async {
    final ctrl = TextEditingController(text: _auth.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.displayName),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: t.displayName,
            helperText: t.displayNameDesc,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(t.save)),
        ],
      ),
    );
    if (name == null) return;
    await _auth.updateDisplayName(name);
    await GroupService().syncMyMemberInfo();
    if (mounted) setState(() {});
  }

  Future<void> _logout(AppText t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.logout),
        content: Text(t.logoutConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(t.logout),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _auth.logout();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final lang = LanguageScope.of(context).locale.languageCode;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_t(_titleProfile, lang))),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          SchoolCalendarService.enabledNotifier,
          SchoolCalendarService.revision,
          UniversityService.enabledNotifier,
          UniversityService.revision,
        ]),
        builder: (context, _) {
          final rawUser = _auth.currentUser;
          final user =
              (rawUser != null && !rawUser.isAnonymous) ? rawUser : null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
            children: [
              _sectionLabel(theme, t.account),
              _accountCard(context, t, user),
              const SizedBox(height: 20),
              _sectionLabel(theme, _t(_modeSection, lang)),
              _modeSection2(context, lang, theme),
              const SizedBox(height: 20),
              _sectionLabel(theme, _t(_dangerZone, lang)),
              _dangerCard(context, t, theme),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary)),
      );

  Widget _accountCard(BuildContext context, AppText t, dynamic user) {
    final theme = Theme.of(context);
    final name = _auth.displayName;
    final email = user?.email as String? ?? '';
    final initial =
        (name.isNotEmpty ? name : (email.isNotEmpty ? email : '?'))
            .substring(0, 1)
            .toUpperCase();
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              child: Text(initial,
                  style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold)),
            ),
            title: Text(name.isNotEmpty ? name : t.addName),
            subtitle: email.isNotEmpty ? Text(email) : null,
            trailing: user != null
                ? const Icon(Icons.edit_outlined, size: 18)
                : const Icon(Icons.chevron_right),
            onTap: () => _editName(t),
          ),
          if (user != null) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: Text(t.logout,
                  style: const TextStyle(color: Colors.redAccent)),
              onTap: () => _logout(t),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeSection2(BuildContext context, String lang, ThemeData theme) {
    final pupilOn = _school.enabled && _school.grade != null;
    final studentOn = _uni.enabled && _uni.profile != null;

    // ── Активен режим ──
    if (pupilOn) {
      final school = _school.school;
      final title =
          '🎒 ${_t(_pupil, lang)} · ${_school.grade} ${_t(_gradeWord, lang)}'
          '${school != null && school.isNotEmpty ? ' · $school' : ''}';
      return _activeModeCard(
        context,
        theme,
        title: title,
        onTapCard: () => _enablePupil(lang), // редакция на класа
        switchLabel: _t(_switchToStudent, lang),
        onSwitch: _enableStudent,
        onTurnOff: _disablePupil,
        lang: lang,
      );
    }
    if (studentOn) {
      final p = _uni.profile!;
      final uniName = _uni.displayUniversityName ?? '';
      final form = _t(_formLabels[p.form.key] ?? _formLabels['redovno']!, lang);
      final title =
          '🎓 ${_t(_student, lang)} · $uniName · ${p.year}. ${_t(_yearWord, lang)} · $form';
      return _activeModeCard(
        context,
        theme,
        title: title,
        onTapCard: _enableStudent, // редакция на профила
        switchLabel: _t(_switchToPupil, lang),
        onSwitch: () => _enablePupil(lang),
        onTurnOff: _disableStudent,
        lang: lang,
      );
    }

    // ── Няма активен режим → „Активирай режим" + две карти ──
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(_t(_activateMode, lang),
              style: TextStyle(
                  fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
        ),
        Row(
          children: [
            Expanded(
              child: _roleChoiceCard(
                emoji: '🎒',
                label: _t(_pupil, lang),
                onTap: () => _enablePupil(lang),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _roleChoiceCard(
                emoji: '🎓',
                label: _t(_student, lang),
                onTap: _enableStudent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _activeModeCard(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required VoidCallback onTapCard,
    required String switchLabel,
    required VoidCallback onSwitch,
    required VoidCallback onTurnOff,
    required String lang,
  }) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTapCard,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.swap_horiz_rounded),
            title: Text(switchLabel),
            onTap: onSwitch,
          ),
          ListTile(
            leading: Icon(Icons.power_settings_new, color: theme.colorScheme.error),
            title: Text(_t(_turnOffMode, lang)),
            onTap: onTurnOff,
          ),
        ],
      ),
    );
  }

  Widget _roleChoiceCard(
      {required String emoji,
      required String label,
      required VoidCallback onTap}) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dangerCard(BuildContext context, AppText t, ThemeData theme) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.delete_forever, color: Colors.red),
        title: Text(t.deleteAccount,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
        subtitle: Text(t.deleteAccountSubtitle,
            style: const TextStyle(fontSize: 12)),
        onTap: () => DeleteAccountFlow.start(context),
      ),
    );
  }
}
