/// io stub — не се ползва на мобилни/desktop платформи (те минават през
/// share_plus в _exportData). Съществува само за да компилира conditional
/// импортът. Извикването му е защитено с `if (kIsWeb)`.
Future<void> saveTextFile(String fileName, String content) async {
  throw UnsupportedError('saveTextFile е достъпно само на web');
}
