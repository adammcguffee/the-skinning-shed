import 'package:flutter/foundation.dart';

/// Dev-only feature flags controlled via dart-define at build time.
///
/// To enable dev auth bypass, run with:
/// ```
/// flutter run --dart-define=DEV_BYPASS_AUTH=true
/// ```
///
/// IMPORTANT: These flags are DOUBLE-GATED:
/// 1. Must be explicitly enabled via dart-define
/// 2. Must also be in debug mode (kDebugMode)
///
/// This makes it impossible to accidentally ship with bypass enabled.
class DevFlags {
  DevFlags._();

  /// Raw flag from dart-define. DO NOT use directly; use [isDevBypassAuthEnabled].
  static const bool _devBypassAuthFlag = bool.fromEnvironment(
    'DEV_BYPASS_AUTH',
    defaultValue: false,
  );

  /// Whether dev auth bypass is enabled.
  /// Only true when BOTH:
  /// - kDebugMode is true (debug build)
  /// - DEV_BYPASS_AUTH=true was passed via dart-define
  static bool get isDevBypassAuthEnabled => kDebugMode && _devBypassAuthFlag;
}
