import 'package:js/js.dart';

/// The static interop class for the `Conflicting Account` object.
@JS()
@anonymous
@staticInterop
class JsConflictingAccount {}

/// This extension defines the static interop definition
/// for the [JsConflictingAccount] class.
extension ConflictingAccountExtension on JsConflictingAccount {
  /// The username or email address
  /// of the user that has a conflicting account.
  external String? get loginID;

  @JS('loginProviders')
  external List<dynamic>? get _loginProviders;

  /// The login providers for the that has a conflicting account.
  List<String>? get loginProviders => _loginProviders?.cast<String>();
}
