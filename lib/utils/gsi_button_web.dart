import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Официалният GIS „Sign in with Google" бутон за web. При клик GIS
/// автентикира потребителя и emit-ва GoogleSignInAuthenticationEventSignIn,
/// което GoogleCalendarService прихваща и иска календарните scopes.
Widget googleSignInButton() => web.renderButton(
      configuration: web.GSIButtonConfiguration(
        size: web.GSIButtonSize.large,
        theme: web.GSIButtonTheme.outline,
        text: web.GSIButtonText.continueWith,
        shape: web.GSIButtonShape.rectangular,
      ),
    );
