import 'package:flutter/material.dart';

/// Споделена палитра за цветовете на категориите (color picker-ите в Настройки,
/// Календар и екрана за задачи ползват ЕДИН списък, за да няма разминаване).
///
/// Първата група са меките материал тонове, втората — ярки/наситени (accent),
/// за хора, които искат по-живи цветове.
const List<Color> kCategoryColors = [
  // — Меки (Material 500) —
  Color(0xFFF44336), // red
  Color(0xFFE91E63), // pink
  Color(0xFF9C27B0), // purple
  Color(0xFF673AB7), // deepPurple
  Color(0xFF3F51B5), // indigo
  Color(0xFF2196F3), // blue
  Color(0xFF03A9F4), // lightBlue
  Color(0xFF00BCD4), // cyan
  Color(0xFF009688), // teal
  Color(0xFF4CAF50), // green
  Color(0xFF8BC34A), // lightGreen
  Color(0xFFCDDC39), // lime
  Color(0xFFFFEB3B), // yellow
  Color(0xFFFFC107), // amber
  Color(0xFFFF9800), // orange
  Color(0xFFFF5722), // deepOrange
  Color(0xFF795548), // brown
  Color(0xFF9E9E9E), // grey
  Color(0xFF607D8B), // blueGrey

  // — Ярки / наситени (accent & neon) —
  Color(0xFFFF1744), // ярко червено
  Color(0xFFFF4081), // ярко розово
  Color(0xFFF50057), // малина
  Color(0xFFD500F9), // ярко лилаво / магента
  Color(0xFF7C4DFF), // виолетово
  Color(0xFF536DFE), // ярко индиго
  Color(0xFF2979FF), // ярко синьо
  Color(0xFF00B0FF), // небесно
  Color(0xFF00E5FF), // ярко циан
  Color(0xFF1DE9B6), // мента
  Color(0xFF00E676), // ярко зелено
  Color(0xFF76FF03), // лайм-зелено
  Color(0xFFC6FF00), // ярко лайм
  Color(0xFFFFEA00), // ярко жълто
  Color(0xFFFFC400), // ярко кехлибар
  Color(0xFFFF9100), // ярко оранжево
  Color(0xFFFF3D00), // ярко керемидено
  Color(0xFFFF6E40), // корал
];
