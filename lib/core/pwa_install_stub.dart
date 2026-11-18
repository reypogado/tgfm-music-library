import 'package:flutter/foundation.dart';

import 'pwa_install.dart';

// Native builds are already installed apps; there is nothing to offer.

PwaStatus pwaStatus() => PwaStatus.unsupported;

Future<PwaInstallOutcome> promptPwaInstall() async =>
    PwaInstallOutcome.unavailable;

VoidCallback subscribePwaStatus(VoidCallback onChange) => () {};
