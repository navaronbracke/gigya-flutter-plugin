import 'dart:js_interop';

/// The extension type for the Certification object.
@JS()
extension type Certification._(JSObject _) implements JSObject {
  /// The certification authority.
  external String? get authority;

  /// The date that the certification expired.
  external String? get endDate;

  /// The name of the certification.
  external String? get name;

  /// The certification number.
  external String? get number;

  /// The date that the certification was issued.
  external String? get startDate;

  /// Convert this certification to a [Map].
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'authority': authority,
      'endDate': endDate,
      'name': name,
      'number': number,
      'startDate': startDate,
    };
  }
}
