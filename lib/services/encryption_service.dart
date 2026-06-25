import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_service.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  /// Resolves the user's AES-256 encryption key.
  /// First checks for a password-derived key. If not present (e.g. Google Sign-In),
  /// fetches or generates a local device key.
  Future<enc.Key> _resolveKey(String userId) async {
    final password = AuthService.userPassword;
    if (password != null && password.isNotEmpty) {
      // Deterministic key derivation via SHA-256 of user password
      final bytes = utf8.encode(password);
      final digest = sha256.convert(bytes);
      return enc.Key(Uint8List.fromList(digest.bytes));
    }

    // Fallback: local key stored in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final keyPrefName = 'chatrix_enc_key_$userId';
    String? localKeyBase64 = prefs.getString(keyPrefName);

    if (localKeyBase64 == null) {
      // Generate secure random 256-bit key
      final secureKey = enc.Key.fromSecureRandom(32);
      localKeyBase64 = secureKey.base64;
      await prefs.setString(keyPrefName, localKeyBase64);
    }

    return enc.Key.fromBase64(localKeyBase64);
  }

  /// Encrypts a plaintext string to an IV-prepended base64 string
  Future<String> encrypt(String plaintext, String userId) async {
    if (plaintext.isEmpty) return plaintext;
    try {
      final key = await _resolveKey(userId);
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(plaintext, iv: iv);
      // Store IV and ciphertext separated by a colon
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      print('Encryption error: $e');
      return plaintext; // Safe fallback to plaintext to prevent app crash
    }
  }

  /// Decrypts an IV-prepended base64 string back to plaintext
  Future<String> decrypt(String ciphertext, String userId) async {
    if (ciphertext.isEmpty || !ciphertext.contains(':')) {
      // Returns plaintext if it is not formatted as cipher
      return ciphertext;
    }
    try {
      final key = await _resolveKey(userId);
      final parts = ciphertext.split(':');
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypted = enc.Encrypted.fromBase64(parts[1]);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      print('Decryption error: $e');
      return ciphertext; // Fallback to raw value (e.g. if key doesn't match or not encrypted)
    }
  }
}
