import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'app_exception.dart';

/// Routes uncaught errors somewhere a developer will actually see them.
///
/// Until this existed, nothing recorded a field failure: no `FlutterError.onError`,
/// no zone guard, no reporter. A crash on a rep's phone reached the team only
/// when the rep thought to describe it — which, for an app used all day under
/// time pressure, means most of them never did.
///
/// Three entry points have to be covered, and each drops errors the others
/// catch:
///
///  * [FlutterError.onError] — errors thrown inside the widget/rendering layer.
///  * [PlatformDispatcher.instance.onError] — uncaught async errors that escape
///    to the platform, which is where a forgotten `await` ends up.
///  * A guarded zone around `runApp` — everything raised outside a Flutter
///    callback, including during bootstrap.
abstract final class CrashReporting {
  static bool _active = false;

  /// True when reports are actually being delivered. False in debug, and in any
  /// build without Firebase configuration.
  static bool get isActive => _active;

  /// Installs the handlers, then runs [body] inside a guarded zone.
  ///
  /// [body] runs whether or not reporting could be started: a build without
  /// Firebase credentials — a fresh clone, or CI without secrets — must still
  /// open. That mirrors how push initialisation already behaves.
  static Future<void> runGuarded(Future<void> Function() body) async {
    try {
      // Debug builds report to the console instead. Sending them would bury the
      // real field crashes under every exception raised while developing.
      _active = !kDebugMode;
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        _active,
      );

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _record(details.exception, details.stack, fatal: false);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        _record(error, stack, fatal: true);
        return true;
      };
    } catch (error, stackTrace) {
      // No Firebase configuration, or it failed to initialise. Keep the app
      // usable and say so once, rather than crashing at launch over telemetry.
      _active = false;
      debugPrint('Crash reporting unavailable: $error\n$stackTrace');
    }

    await runZonedGuarded(body, (error, stack) {
      _record(error, stack, fatal: true);
    });
  }

  /// Records a handled error — something the app recovered from but that still
  /// should not have happened.
  static void recordHandled(Object error, StackTrace? stack, {String? reason}) {
    _record(error, stack, fatal: false, reason: reason);
  }

  /// Attaches the signed-in user to subsequent reports.
  ///
  /// Only the id and tenant: enough to tell "one rep's device is broken" from
  /// "the whole tenant is", without putting a customer's name or a message body
  /// into a third-party service.
  static Future<void> identify({String? userId, String? tenantId}) async {
    if (!_active) return;
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setUserIdentifier(userId ?? '');
      await crashlytics.setCustomKey('tenant_id', tenantId ?? '');
    } catch (_) {
      // Telemetry must never break a login.
    }
  }

  static void _record(
    Object error,
    StackTrace? stack, {
    required bool fatal,
    String? reason,
  }) {
    // An AppException is the API saying "no" — a 403, a validation error, an
    // offline device. Those are outcomes the app already shows the user, not
    // defects, and reporting them would drown the real crashes.
    if (error is AppException) return;

    if (!_active) {
      debugPrint('Unreported error (${reason ?? 'uncaught'}): $error\n$stack');
      return;
    }

    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (_) {
      // Never let the reporter become the thing that crashes.
    }
  }
}
