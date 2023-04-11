import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:js/js_util.dart' show allowInterop;
import 'package:web/web.dart' as web;

import '../models/gigya_error.dart';
import '../platform_interface/gigya_flutter_plugin_platform_interface.dart';
import '../services/interruption_resolver.dart';
import 'enums/web_error_code.dart';
import 'static_interop/gigya_web_sdk.dart';
import 'static_interop/models/profile.dart';
import 'static_interop/parameters/basic.dart';
import 'static_interop/parameters/login.dart';
import 'static_interop/parameters/registration.dart';
import 'static_interop/response/registration_response.dart';
import 'static_interop/response/response.dart';
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
              details: response.details,
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
  Future<Map<String, dynamic>> register({
    required String loginId,
    required String password,
    Map<String, dynamic> parameters = const <String, dynamic>{},
  }) async {
    final Completer<String> initRegistrationCompleter = Completer<String>();

    gigyaWebSdk.accounts.initRegistration(
      InitRegistrationParameters(
        isLite: parameters['isLite'] as bool?,
        callback: allowInterop((InitRegistrationResponse response) {
          if (initRegistrationCompleter.isCompleted) {
            return;
          }

          final String regToken = response.regToken ?? '';

          if (response.errorCode == 0 && regToken.isNotEmpty) {
            initRegistrationCompleter.complete(regToken);
          } else {
            // If the registration token is empty, the next step will fail.
            // Abort with an error instead.
            initRegistrationCompleter.completeError(
              GigyaError(
                apiVersion: response.apiVersion,
                callId: response.callId,
                errorCode: response.errorCode,
                errorDetails: response.errorDetails,
                registrationToken: response.regToken,
              ),
            );
          }
        }),
      ),
    );

    final String registrationToken = await initRegistrationCompleter.future;
    final Map<String, dynamic>? profile = parameters['profile'] as Map<String, dynamic>?;

    final Completer<Map<String, dynamic>> registrationCompleter = Completer<Map<String, dynamic>>();

    gigyaWebSdk.accounts.register(
      RegistrationParameters(
        // Explicitly finalize using the register endpoint.
        // This way, calling `finalizeRegistration` is not needed.
        finalizeRegistration: true,
        regToken: registrationToken,
        email: loginId,
        password: password,
        captchaToken: parameters['captchaToken'] as String?,
        include: parameters['include'] as String?,
        lang: parameters['lang'] as String?,
        profile: profile == null ? null : Profile.fromMap(profile),
        regSource: parameters['regSource'] as String?,
        secretAnswer: parameters['secretAnswer'] as String?,
        secretQuestion: parameters['secretQuestion'] as String?,
        sessionExpiration: parameters['sessionExpiration'] as int?,
        siteUID: parameters['siteUID'] as String?,
        callback: allowInterop((LoginResponse response) {
          if (registrationCompleter.isCompleted) {
            return;
          }

          if (response.errorCode == 0) {
            registrationCompleter.complete(response.toMap());
          } else {
            registrationCompleter.completeError(
              GigyaError(
                apiVersion: response.apiVersion,
                callId: response.callId,
                errorCode: response.errorCode,
                errorDetails: response.errorDetails,
                registrationToken: registrationToken,
              ),
            );
          }
        }),
      ),
    );

    return registrationCompleter.future;
  }
}
