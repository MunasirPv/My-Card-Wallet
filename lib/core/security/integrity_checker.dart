import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';

enum IntegrityStatus { clean, jailbroken, debuggerAttached, unknown }

class IntegrityChecker {
  Future<IntegrityStatus> check() async {
    if (kDebugMode) return IntegrityStatus.clean; // skip in dev

    try {
      final isJailbroken = await SafeDevice.isJailBroken;
      if (isJailbroken) return IntegrityStatus.jailbroken;

      final isDeveloperMode = await SafeDevice.isDevelopmentModeEnable;
      if (isDeveloperMode) return IntegrityStatus.debuggerAttached;

      return IntegrityStatus.clean;
    } catch (_) {
      return IntegrityStatus.unknown;
    }
  }
}
