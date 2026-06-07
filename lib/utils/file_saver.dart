// Платформено-зависимо записване на текстов файл.
//
// На web сваля файл през браузъра (Blob). На io платформите не се ползва —
// там _exportData минава през share_plus. Conditional export избира импл-ята.
export 'file_saver_io.dart' if (dart.library.html) 'file_saver_web.dart';
