import 'dart:js_interop';

import '../response/login_response.dart';

/// This extension type represents the parameters for the `Accounts.login` method.
@JS()
extension type LoginParameters._(JSObject _) implements JSObject {
  /// Create a new [LoginParameters] instance.
  ///
  /// The [callback] receives a [LoginResponse] as argument,
  /// and has [JSVoid] as return type.
  external factory LoginParameters({
    JSFunction callback,
    String? captchaToken,
    String? include,
    String loginID,
    String? loginMode,
    String password,
    String? redirectURL,
    String? regToken,
    int? sessionExpiration,
  });
}