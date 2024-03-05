import 'dart:js_interop';

/// The extension type for the session info object.
@JS()
extension type SessionInfo._(JSObject _) implements JSObject {
  /// The name of the session cookie.
  external String? get cookieName;

  /// The value of the session cookie.
  external String? get cookieValue;

  /// Convert this session info into a [Map].
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cookieName': cookieName,
      'cookieValue': cookieValue,
    };
  }
}