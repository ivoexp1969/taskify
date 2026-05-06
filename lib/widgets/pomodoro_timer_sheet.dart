import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../utils/localization.dart';

class PomodoroTimerSheet extends StatefulWidget {
  final Task task;

  const PomodoroTimerSheet({super.key, required this.task});

  static Future<void> show(BuildContext context, Task task) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => PomodoroTimerSheet(task: task),
    );
  }

  @override
  State<PomodoroTimerSheet> createState() => _PomodoroTimerSheetState();
}

class _PomodoroTimerSheetState extends State<PomodoroTimerSheet> {
  static const int _totalSeconds = 25 * 60;

  int _remaining = _totalSeconds;
  bool _running = false;
  bool _finished = false;
  Timer? _timer;
  int _pomodoroCount = 0;

  String _prefKey() => 'pomodoro_${widget.task.key}';

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _pomodoroCount = prefs.getInt(_prefKey()) ?? 0);
    }
  }

  Future<void> _saveCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey(), _pomodoroCount);
  }

  void _start() {
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }
      if (_remaining <= 1) {
        _timer?.cancel();
        setState(() {
          _remaining = 0;
          _running = false;
          _finished = true;
          _pomodoroCount++;
        });
        _saveCount();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _stop() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _remaining = _totalSeconds;
      _running = false;
      _finished = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeStr {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppText.of(context);
    final progress = 1.0 - (_remaining / _totalSeconds);
    final accentColor = _finished ? Colors.green : theme.colorScheme.primary;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Text(
              '🍅 ${t.pomodoroSession}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              widget.task.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 32),

            // Circular timer
            SizedBox(
              width: 200, height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200, height: 200,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_finished)
                        const Text('✅', style: TextStyle(fontSize: 52))
                      else
                        Text(
                          _timeStr,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      if (_finished)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            t.pomodoroComplete,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '25 min',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pomodoro count
            if (_pomodoroCount > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pomodoroCount.clamp(0, 8),
                  (_) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Text('🍅', style: TextStyle(fontSize: 20)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Buttons
            if (_finished)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _stop,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(t.pomodoroClose),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(t.pomodoroAgain),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop_rounded, size: 18),
                      label: Text(t.pomodoroStop),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _running ? _pause : _start,
                      icon: Icon(
                        _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                      label: Text(_running ? t.pomodoroPause : t.pomodoroStart),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
