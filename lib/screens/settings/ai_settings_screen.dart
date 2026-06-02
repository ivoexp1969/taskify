import 'package:flutter/material.dart';

import '../../utils/localization.dart';
import '../../services/ai_usage_service.dart';

/// Малък екран за AI настройки: toggle за AI парсване, toggle за гласово
/// въвеждане и ред с дневната употреба (Използвани днес: X/20).
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _usage = AiUsageService.instance;
  bool _parsingEnabled = true;
  bool _voiceEnabled = true;
  int _usedToday = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final parsing = await _usage.isParsingEnabled();
    final voice = await _usage.isVoiceEnabled();
    final used = await _usage.usedToday();
    if (!mounted) return;
    setState(() {
      _parsingEnabled = parsing;
      _voiceEnabled = voice;
      _usedToday = used;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.aiSettings)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.purple),
                        ),
                        title: Text(t.aiParsingSetting),
                        subtitle: Text(
                          t.aiParsingSettingDesc,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        value: _parsingEnabled,
                        onChanged: (v) async {
                          setState(() => _parsingEnabled = v);
                          await _usage.setParsingEnabled(v);
                        },
                      ),
                      const Divider(height: 0),
                      SwitchListTile(
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.mic_rounded, color: Colors.blue),
                        ),
                        title: Text(t.voiceInputSetting),
                        subtitle: Text(
                          t.voiceInputSettingDesc,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        value: _voiceEnabled,
                        onChanged: (v) async {
                          setState(() => _voiceEnabled = v);
                          await _usage.setVoiceEnabled(v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.speed_rounded, color: Colors.teal),
                    ),
                    title: Text(t.aiUsageSettingTitle),
                    subtitle: Text(
                      t.aiUsageToday(_usedToday, AiUsageService.dailyLimit),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
