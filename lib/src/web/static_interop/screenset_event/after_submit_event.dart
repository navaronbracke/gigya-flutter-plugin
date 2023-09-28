import 'dart:js_interop';

import '../../../models/screenset_event.dart';
import '../models/profile.dart';

/// The extension type for the after submit event of the `Account.showScreenset` event stream.
///
/// See: https://help.sap.com/docs/SAP_CUSTOMER_DATA_CLOUD/8b8d6fffe113457094a17701f63e3d6a/413a5b7170b21014bbc5a10ce4041860.html?locale=en-US#onaftersubmit-event-data
@JS()
@anonymous
@staticInterop
extension type AfterSubmitEvent(JSObject _) {
  /// An object containing any custom data fields related to the user,
  /// as known after the form submission.
  external JSAny? get data;

  /// The name of the event.
  external String get eventName;

  /// The ID of the form.
  external String get form;

  /// The profile data of the user, after the submission.
  /// This is null if the user is not logged in.
  external Profile? get profile;

  /// The response of the form's submit operation.
  external JSAny? get response;

  /// The name of the screen.
  external String get screen;

  /// The source plugin that generated this event.
  /// The value of this field is the name of the plugin's API method,
  /// e.g., 'showLoginUI', 'showCommentsUI', etc.
  external String get source;

  /// Serialize this event into a [ScreensetEvent].
  ScreensetEvent serialize() {
    return ScreensetEvent(
      eventName,
      <String, dynamic>{
        'data': data.dartify(),
        'form': form,
        'profile': profile?.toMap(),
        'response': response.dartify(),
        'screen': screen,
        'source': source,
      },
    );
  }
}
