import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:js/js_util.dart' show allowInterop;
import 'package:web/web.dart' as web;

import '../models/gigya_error.dart';
import '../models/screenset_event.dart';
import '../platform_interface/gigya_flutter_plugin_platform_interface.dart';
import '../services/interruption_resolver.dart';
import 'enums/web_error_code.dart';
import 'static_interop/gigya_web_sdk.dart';
import 'static_interop/parameters/add_event_handlers_parameters.dart';
import 'static_interop/parameters/basic.dart';
import 'static_interop/parameters/login.dart';
import 'static_interop/parameters/screenset_parameters.dart';
import 'static_interop/response/response.dart';
import 'static_interop/screenset_event/error_event.dart';
import 'static_interop/window.dart';
import 'web_interruption_resolver.dart';

/// An implementation of [GigyaFlutterPluginPlatform] that uses JavaScript static interop.
class GigyaFlutterPluginWeb extends GigyaFlutterPluginPlatform {
  /// Register [GigyaFlutterPluginWeb] as the default implementation for the web plugin.
  ///
  /// This method is used by the `GeneratedPluginRegistrant` class.
  static void registerWith(Registrar registrar) {
    GigyaFlutterPluginPlatform.instance = GigyaFlutterPluginWeb();
  }

  @override
  InterruptionResolverFactory get interruptionResolverFactory {
    return const WebInterruptionResolverFactory();
  }

  @override
  Future<void> initSdk({
    required String apiDomain,
    required String apiKey,
    bool forceLogout = false,
  }) async {
    final Completer<void> onGigyaServiceReadyCompleter = Completer<void>();
    final GigyaWindow domWindow = GigyaWindow(web.window);

    // Set `window.onGigyaServiceReady` before creating the script.
    // That function is called when the SDK has been initialized.
    domWindow.onGigyaServiceReady = allowInterop((JSString? _) {
      if (!onGigyaServiceReadyCompleter.isCompleted) {
        onGigyaServiceReadyCompleter.complete();
      }
    }).toJS;

    // If the Gigya SDK is ready beforehand, complete directly.
    // This is the case when doing a Hot Reload, where the application starts from scratch,
    // even though the Gigya SDK script is still attached to the DOM and ready.
    // See https://docs.flutter.dev/tools/hot-reload#how-to-perform-a-hot-reload
    final bool sdkIsReady = domWindow.gigya != null && GigyaWebSdk.instance.isReady;

    if (sdkIsReady) {
      if (!onGigyaServiceReadyCompleter.isCompleted) {
        onGigyaServiceReadyCompleter.complete();
      }
    } else {
      final Completer<void> scriptLoadCompleter = Completer<void>();

      final web.HTMLScriptElement script = (web.document.createElement('script') as web.HTMLScriptElement)
        ..async = true
        ..defer = false
        ..type = 'text/javascript'
        ..lang = 'javascript'
        ..crossOrigin = 'anonymous'
        ..src = 'https://cdns.$apiDomain/js/gigya.js?apikey=$apiKey'
        ..onload = allowInterop((JSAny _) {
          if (!scriptLoadCompleter.isCompleted) {
            scriptLoadCompleter.complete();
          }
        }).toJS;

      web.document.head!.append(script);

      await scriptLoadCompleter.future;
    }

    // If `onGigyaServiceReady` takes too long to be called
    // (for instance if the network is unavailable, or Gigya does not initialize properly),
    // exit with a timeout error.
    await onGigyaServiceReadyCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw const GigyaTimeoutError(),
    );

    if (forceLogout) {
      await logout();
    }
  }

  @override
  Future<bool> isLoggedIn() {
    final Completer<bool> completer = Completer<bool>();
    final BasicParameters parameters = BasicParameters(
      callback: allowInterop((Response response) {
        if (completer.isCompleted) {
          return;
        }

        switch (WebErrorCode.fromErrorCode(response.errorCode)) {
          case WebErrorCode.success:
            completer.complete(true);
            break;
          case WebErrorCode.unauthorizedUser:
            completer.complete(false);
            break;
          default:
            completer.completeError(
              GigyaError(
                apiVersion: response.apiVersion,
                callId: response.callId,
                details: response.details,
                errorCode: response.errorCode,
              ),
            );
            break;
        }
      }).toJS,
    );

    GigyaWebSdk.instance.accounts.session.verify.callAsFunction(
      null,
      parameters,
    );

    return completer.future;
  }

  @override
  Future<Map<String, dynamic>> login({
    required String loginId,
    required String password,
    Map<String, dynamic> parameters = const <String, dynamic>{},
  }) {
    final Completer<Map<String, dynamic>> completer = Completer<Map<String, dynamic>>();

    final LoginParameters loginParameters = LoginParameters(
      loginID: loginId,
      password: password,
      captchaToken: parameters['captchaToken'] as String?,
      include: parameters['include'] as String?,
      loginMode: parameters['loginMode'] as String?,
      redirectURL: parameters['redirectURL'] as String?,
      regToken: parameters['regToken'] as String?,
      sessionExpiration: parameters['sessionExpiration'] as int?,
      callback: allowInterop((LoginResponse response) {
        if (completer.isCompleted) {
          return;
        }

        if (response.baseResponse.errorCode == 0) {
          completer.complete(response.toMap());
        } else {
          completer.completeError(
            GigyaError(
              apiVersion: response.baseResponse.apiVersion,
              callId: response.baseResponse.callId,
              details: response.baseResponse.details,
              errorCode: response.baseResponse.errorCode,
            ),
          );
        }
      }).toJS,
    );

    GigyaWebSdk.instance.accounts.login.callAsFunction(
      null,
      loginParameters,
    );

    return completer.future;
  }

  @override
  Future<void> logout() async {
    if (!await isLoggedIn()) {
      return;
    }

    final Completer<void> completer = Completer<void>();
    final BasicParameters parameters = BasicParameters(
      callback: allowInterop((Response response) {
        if (completer.isCompleted) {
          return;
        }

        if (response.errorCode == 0) {
          completer.complete();
        } else {
          completer.completeError(
            GigyaError(
              apiVersion: response.apiVersion,
              callId: response.callId,
              details: response.details,
              errorCode: response.errorCode,
            ),
          );
        }
      }).toJS,
    );

    GigyaWebSdk.instance.accounts.logout.callAsFunction(
      null,
      parameters,
    );

    return completer.future;
  }

  @override
  Stream<ScreensetEvent> showScreenSet(
    String name, {
    Map<String, dynamic> parameters = const <String, dynamic>{},
  }) {
    late StreamController<ScreensetEvent> controller;

    controller = StreamController<ScreensetEvent>.broadcast(onListen: () {
      // First setup the handlers for the global events.
      GigyaWebSdk.instance.accounts.addEventHandlers(AddEventHandlersParameters(
        onAfterResponse: allowInterop((Object? response) {
          if (response == null || controller.isClosed) {
            return;
          }

          final Map<Object?, Object?> eventData = dartify(response) as Map<Object?, Object?>;

          controller.add(
            ScreensetEvent(
              eventData['eventName'] as String? ?? 'onAfterResponse',
              eventData.cast<String, Object?>(),
            ),
          );
        }),
        onLogin: allowInterop((LoginGlobalEventResponse response) {
          if (controller.isClosed) {
            return;
          }

          controller.add(ScreensetEvent('onLogin', response.toMap()));
        }),
      ));

      GigyaWebSdk.instance.accounts.showScreenSet(
        ShowScreensetParameters(
          authFlow: parameters['authFlow'] as String? ?? 'popup',
          communicationLangByScreenSet: parameters['communicationLangByScreenSet'] as bool? ?? true,
          deviceType: parameters['deviceType'] as String? ?? 'desktop',
          dialogStyle: parameters['dialogStyle'] as String? ?? 'modern',
          enabledProviders: parameters['enabledProviders'] as String?,
          googlePlayAppID: parameters['googlePlayAppID'] as String?,
          lang: parameters['lang'] as String?,
          mobileScreenSet: parameters['mobileScreenSet'] as String?,
          redirectMethod: parameters['redirectMethod'] as String? ?? 'get',
          redirectURL: parameters['redirectURL'] as String?,
          regSource: parameters['regSource'] as String?,
          regToken: parameters['regToken'] as String?,
          screenSet: name,
          sessionExpiration: parameters['sessionExpiration'] as int?,
          startScreen: parameters['startScreen'] as String?,
          // Each event handler is wrapped in `allowInterop` since it is called in Javascript.
          // The `event` of each handler is a static interop type,
          // as it is constructed in Javascript.
          // If `parameters` has a handler function, it is invoked and its result
          // is passed back to Javascript after being converted to a Javascript Object using `jsify`.
          onError: allowInterop((ErrorEvent event) {
            if (controller.isClosed) {
              return;
            }

            final ErrorEventHandler? handler = parameters['onError'] as ErrorEventHandler?;
            final ScreensetEvent screensetEvent = event.serialize();

            controller.add(screensetEvent);

            return jsify(handler?.call(screensetEvent));
          }),
        ),
      );
    }, onCancel: () {
      // Unset the handlers for the global events by setting them to null.
      GigyaWebSdk.instance.accounts.addEventHandlers(AddEventHandlersParameters());

      // Automatically hide the screenset when the last listener
      // of the stream cancels its subscription.
      GigyaWebSdk.instance.accounts.hideScreenSet(HideScreensetParameters(screenSet: name));

      unawaited(controller.close());
    });

    return controller.stream;
  }
}
