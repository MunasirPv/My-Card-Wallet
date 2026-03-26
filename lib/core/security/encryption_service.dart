import 'dart:convert';
import 'dart:math';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:my_card_wallet/core/storage/secure_storage_service.dart';
import 'package:pointycastle/export.dart' as pc;

const _masterKeyStorageKey = 'secure_master_key_v1';

class EncryptionService {
  final SecureStorageService _storage;

  EncryptionService(this._storage);

  // ── Master key management ──────────────────────────────────────────────────

  Future<enc.Key> _getMasterKey() async {
    String? stored = await _storage.read(_masterKeyStorageKey);
    if (stored == null) {
      // Generate 256-bit random master key on first run
      final random = Random.secure();
      final keyBytes = Uint8List.fromList(
        List.generate(32, (_) => random.nextInt(256)),
      );
      stored = base64.encode(keyBytes);
      await _storage.write(_masterKeyStorageKey, stored);
    }
    return enc.Key(base64.decode(stored));
  }

  /// Derive a card-specific key using HKDF from the master key + cardId as info.
  Future<enc.Key> _deriveKey(String cardId) async {
    final masterKey = await _getMasterKey();
    final derived = _hkdfSha256(
      ikm: masterKey.bytes,
      info: utf8.encode(cardId),
      length: 32,
    );
    return enc.Key(derived);
  }

  Uint8List _hkdfSha256({
    required Uint8List ikm,
    required Uint8List info,
    int length = 32,
    Uint8List? salt,
  }) {
    final effectiveSalt = salt ?? Uint8List(32);
    final hmac = pc.HMac(pc.SHA256Digest(), 64);

    // Extract
    hmac.init(pc.KeyParameter(effectiveSalt));
    hmac.update(ikm, 0, ikm.length);
    final prk = Uint8List(hmac.macSize);
    hmac.doFinal(prk, 0);

    // Expand
    final okm = Uint8List(length);
    var t = Uint8List(0);
    var offset = 0;
    var counter = 1;
    while (offset < length) {
      hmac.init(pc.KeyParameter(prk));
      hmac.update(t, 0, t.length);
      hmac.update(info, 0, info.length);
      hmac.updateByte(counter++);
      t = Uint8List(hmac.macSize);
      hmac.doFinal(t, 0);
      final copyLen = min(length - offset, t.length);
      okm.setRange(offset, offset + copyLen, t);
      offset += copyLen;
    }
    return okm;
  }

  // ── Encrypt / Decrypt ──────────────────────────────────────────────────────

  /// Encrypt [plaintext] tied to [cardId]. Returns "base64iv:base64cipher".
  Future<String> encrypt(String plaintext, String cardId) async {
    final key = await _deriveKey(cardId);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  Future<String> decrypt(String ciphertext, String cardId) async {
    final parts = ciphertext.split(':');
    if (parts.length != 2) throw const FormatException('Invalid ciphertext');
    final key = await _deriveKey(cardId);
    final iv = enc.IV.fromBase64(parts[0]);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(parts[1], iv: iv);
  }

  /// Run encryption on an isolate to avoid blocking UI thread.
  Future<String> encryptIsolate(String plaintext, String cardId) async {
    return compute(_encryptWrapper, _EncryptParams(plaintext, cardId, this));
  }

  Future<String> decryptIsolate(String ciphertext, String cardId) async {
    return compute(_decryptWrapper, _DecryptParams(ciphertext, cardId, this));
  }
}

// Isolate helpers (top-level for compute())
class _EncryptParams {
  final String plaintext, cardId;
  final EncryptionService svc;
  _EncryptParams(this.plaintext, this.cardId, this.svc);
}

class _DecryptParams {
  final String ciphertext, cardId;
  final EncryptionService svc;
  _DecryptParams(this.ciphertext, this.cardId, this.svc);
}

Future<String> _encryptWrapper(_EncryptParams p) => p.svc.encrypt(p.plaintext, p.cardId);
Future<String> _decryptWrapper(_DecryptParams p) => p.svc.decrypt(p.ciphertext, p.cardId);
