import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'pwa_install.dart';

/// `window.tgfmPwa`, defined in web/index.html.
@JS('tgfmPwa')
external _TgfmPwa? get _pwa;

extension type _TgfmPwa._(JSObject _) implements JSObject {
  external bool canPrompt();
  external bool wasInstalled();
  external bool isStandalone();
  external String platform();
  external JSPromise<JSString> prompt();
  external JSFunction subscribe(JSFunction callback);
}

PwaStatus pwaStatus() {
  final pwa = _pwa;
  if (pwa == null) return PwaStatus.unsupported;
  return PwaStatus(
    supported: true,
    standalone: pwa.isStandalone(),
    installedHere: pwa.wasInstalled(),
    canPrompt: pwa.canPrompt(),
    platform: switch (pwa.platform()) {
      'ios' => PwaPlatform.ios,
      'android' => PwaPlatform.android,
      'mac-safari' => PwaPlatform.macSafari,
      'firefox-desktop' => PwaPlatform.firefoxDesktop,
      _ => PwaPlatform.desktop,
    },
  );
}

Future<PwaInstallOutcome> promptPwaInstall() async {
  final pwa = _pwa;
  if (pwa == null) return PwaInstallOutcome.unavailable;
  final outcome = (await pwa.prompt().toDart).toDart;
  return switch (outcome) {
    'accepted' => PwaInstallOutcome.accepted,
    'dismissed' => PwaInstallOutcome.dismissed,
    _ => PwaInstallOutcome.unavailable,
  };
}

VoidCallback subscribePwaStatus(VoidCallback onChange) {
  final pwa = _pwa;
  if (pwa == null) return () {};
  final unsubscribe = pwa.subscribe(onChange.toJS);
  return () => unsubscribe.callAsFunction();
}
