import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Сваля текстов файл през браузъра (data download), без сървър.
Future<void> saveTextFile(String fileName, String content) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob(<dynamic>[bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
