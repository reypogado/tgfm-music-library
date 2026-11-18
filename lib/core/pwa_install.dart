import 'package:flutter/foundation.dart';

import 'pwa_install_stub.dart'
    if (dart.library.js_interop) 'pwa_install_web.dart'
    as impl;

/// Where the web app is running, which decides the manual install steps.
enum PwaPlatform { ios, android, macSafari, firefoxDesktop, desktop }

enum PwaInstallOutcome { accepted, dismissed, unavailable }

/// A snapshot of whether the web app can be, or already is, installed.
///
/// Only meaningful on web; native builds report [supported] as false.
@immutable
class PwaStatus {
  const PwaStatus({
    required this.supported,
    required this.standalone,
    required this.installedHere,
    required this.canPrompt,
    required this.platform,
  });

  static const unsupported = PwaStatus(
    supported: false,
    standalone: false,
    installedHere: false,
    canPrompt: false,
    platform: PwaPlatform.desktop,
  );

  /// The page loaded with the install helper from web/index.html.
  final bool supported;

  /// Running as the installed app rather than in a browser tab.
  final bool standalone;

  /// Installed from this tab during this session (still a tab).
  final bool installedHere;

  /// The browser offered an install prompt we can show on demand
  /// (Chrome, Edge, Samsung Internet).
  final bool canPrompt;

  final PwaPlatform platform;
}

PwaStatus pwaStatus() => impl.pwaStatus();

/// Shows the browser's install dialog, if it offered one.
Future<PwaInstallOutcome> promptPwaInstall() => impl.promptPwaInstall();

/// Calls [onChange] whenever [pwaStatus] may have changed. Returns a function
/// that stops listening.
VoidCallback subscribePwaStatus(VoidCallback onChange) =>
    impl.subscribePwaStatus(onChange);
