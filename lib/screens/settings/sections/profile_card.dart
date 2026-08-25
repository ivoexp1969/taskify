import 'dart:io';

import 'package:flutter/material.dart';

import '../../../utils/localization.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_calendar_service.dart';
import '../../../services/university_service.dart';
import '../../profile/profile_screen.dart';

/// Компактна карта „Профил" горе в Настройки (Пакет 2). Два реда (аватар +
/// име/имейл) БЕЗ CTA; трети ред само при активен режим. Тап → [ProfileScreen].
///
/// Изнесена 1:1 от [SettingsScreen] (`_buildProfileCard`). Снимката се подава
/// през [profilePhotoPath]; след връщане от [ProfileScreen] родителят
/// презарежда снимката/името през [onReturn].
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.profilePhotoPath,
    required this.onReturn,
  });

  final String? profilePhotoPath;
  final Future<void> Function() onReturn;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final theme = Theme.of(context);
    final lang = LanguageScope.of(context).locale.languageCode;
    String tr(Map<String, String> m) => m[lang] ?? m['en']!;
    final rawUser = authService.currentUser;
    final user = (rawUser != null && !rawUser.isAnonymous) ? rawUser : null;
    final name = authService.displayName;
    final email = user?.email ?? '';
    final title = name.isNotEmpty
        ? name
        : (email.isNotEmpty ? email : tr(const {
            'en': 'Profile', 'bg': 'Профил', 'de': 'Profil', 'fr': 'Profil',
            'it': 'Profilo', 'el': 'Προφίλ', 'es': 'Perfil', 'pt': 'Perfil',
            'ru': 'Профиль', 'tr': 'Profil', 'ja': 'プロフィール',
          }));
    final initial = (title.isNotEmpty ? title : '?').substring(0, 1).toUpperCase();

    // Ред за режим (само ако е активен).
    String? modeLine;
    final school = SchoolCalendarService();
    final uni = UniversityService();
    if (school.enabled && school.grade != null) {
      modeLine = '🎒 ${tr(const {
        'en': 'Pupil', 'bg': 'Ученик', 'de': 'Schüler', 'fr': 'Élève',
        'it': 'Alunno', 'el': 'Μαθητής', 'es': 'Alumno', 'pt': 'Aluno',
        'ru': 'Ученик', 'tr': 'Öğrenci', 'ja': '生徒',
      })} · ${school.grade} ${tr(const {
        'en': 'grade', 'bg': 'клас', 'de': 'Klasse', 'fr': 'classe',
        'it': 'classe', 'el': 'τάξη', 'es': 'grado', 'pt': 'ano',
        'ru': 'класс', 'tr': 'sınıf', 'ja': '年生',
      })}';
    } else if (uni.enabled && uni.profile != null) {
      modeLine = '🎓 ${tr(const {
        'en': 'Student', 'bg': 'Студент', 'de': 'Student', 'fr': 'Étudiant',
        'it': 'Studente', 'el': 'Φοιτητής', 'es': 'Estudiante', 'pt': 'Estudante',
        'ru': 'Студент', 'tr': 'Üniversite', 'ja': '大学生',
      })}${uni.displayUniversityName != null ? ' · ${uni.displayUniversityName}' : ''}';
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
          await onReturn(); // снимката/името може да са сменени
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primary,
                backgroundImage: profilePhotoPath != null
                    ? FileImage(File(profilePhotoPath!))
                    : null,
                child: profilePhotoPath == null
                    ? Text(initial,
                        style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (email.isNotEmpty && name.isNotEmpty)
                      Text(email,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    if (modeLine != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(modeLine,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
