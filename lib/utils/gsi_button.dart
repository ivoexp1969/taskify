// Платформено-зависим Google Sign-In бутон.
//
// На web връща официалния GIS „Sign in with Google" бутон (renderButton),
// защото google_sign_in 7.x НЕ поддържа authenticate() на web. На mobile не
// се ползва (там Connect върви през authenticate()).
export 'gsi_button_stub.dart' if (dart.library.html) 'gsi_button_web.dart';
