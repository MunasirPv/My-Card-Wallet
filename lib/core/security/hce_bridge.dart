import 'dart:io';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';

class HceBridge {
  static const _channel = MethodChannel('com.securewallet.my_card_wallet/hce');

  /// Checks if NFC HCE is available on this device.
  static Future<bool> isHceSupported() async {
    if (!Platform.isAndroid) return false;
    final availability = await NfcManager.instance.checkAvailability();
    return availability == NfcAvailability.enabled;
  }

  /// Activates a card for NFC payment emulation.
  /// 
  /// [number] Card PAN (unmasked)
  /// [expiry] MM/YY format
  /// [name] Holder name
  static Future<bool> activateCard({
    required String number,
    required String expiry,
    required String name,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod('activateCard', {
        'number': number,
        'expiry': expiry,
        'name': name,
      }) ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Clears the active card from HCE memory.
  static Future<bool> deactivateCard() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod('deactivateCard') ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
