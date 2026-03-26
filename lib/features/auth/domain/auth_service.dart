import 'package:local_auth/local_auth.dart';
import 'package:my_card_wallet/core/storage/secure_storage_service.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

const _pinKey = 'auth_pin_hash_v1';
const _biometricEnabledKey = 'auth_biometric_enabled';
const _firstLaunchKey = 'auth_first_launch_done';

enum AuthResult { success, failed, notSetup, biometricUnavailable }

class AuthService {
  final LocalAuthentication _localAuth;
  final SecureStorageService _storage;

  AuthService(this._localAuth, this._storage);

  // ── Setup ──────────────────────────────────────────────────────────────────

  Future<bool> isFirstLaunch() async {
    final done = await _storage.read(_firstLaunchKey);
    return done == null;
  }

  Future<void> completeFirstLaunch() async {
    await _storage.write(_firstLaunchKey, 'true');
  }

  Future<bool> isPINSet() async {
    return _storage.containsKey(_pinKey);
  }

  Future<void> setPIN(String pin) async {
    final hash = _hashPIN(pin);
    await _storage.write(_pinKey, hash);
  }

  Future<bool> verifyPIN(String pin) async {
    final stored = await _storage.read(_pinKey);
    if (stored == null) return false;
    return stored == _hashPIN(pin);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(_biometricEnabledKey, enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(_biometricEnabledKey);
    return val == 'true';
  }

  // ── Authentication ─────────────────────────────────────────────────────────

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    return _localAuth.getAvailableBiometrics();
  }

  Future<AuthResult> authenticateWithBiometrics({
    String reason = 'Authenticate to access your wallet',
  }) async {
    final enabled = await isBiometricEnabled();
    if (!enabled) return AuthResult.notSetup;

    final available = await isBiometricAvailable();
    if (!available) return AuthResult.biometricUnavailable;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
      return authenticated ? AuthResult.success : AuthResult.failed;
    } catch (_) {
      return AuthResult.failed;
    }
  }

  Future<AuthResult> authenticateForSensitiveAction({
    String reason = 'Authenticate to reveal card details',
  }) async {
    // 1. Try biometrics if enabled
    final bioEnabled = await isBiometricEnabled();
    final bioAvailable = await isBiometricAvailable();
    if (bioEnabled && bioAvailable) {
      final result = await authenticateWithBiometrics(reason: reason);
      if (result == AuthResult.success) return AuthResult.success;
    }

    // 2. PIN fallback is handled by the UI (e.g. showing a PIN dialog)
    // Here we return notSetup or failed to signal the UI to prompt for PIN
    return AuthResult.failed;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _hashPIN(String pin) {
    final bytes = utf8.encode(pin + 'scw_salt_v1');
    return sha256.convert(bytes).toString();
  }
}
