import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class BackupEncryptionException implements Exception {
  final String message;

  const BackupEncryptionException(this.message);

  @override
  String toString() => 'BackupEncryptionException: $message';
}

class BackupEncryptionService {
  static const int version = 1;
  static const int iterations = 210000;
  static const String fileExtension = '.monolog';
  static const String _magic = 'MONOLOG_ENCRYPTED_BACKUP\n';
  static final List<int> _magicBytes = ascii.encode(_magic);

  final AesGcm _cipher = AesGcm.with256bits();
  final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  final Random _random = Random.secure();

  static bool isEncryptedBackup(List<int> bytes) {
    if (bytes.length < _magicBytes.length + 4) return false;
    for (var i = 0; i < _magicBytes.length; i++) {
      if (bytes[i] != _magicBytes[i]) return false;
    }
    return true;
  }

  Future<Uint8List> encryptZipBytes(
    List<int> zipBytes, {
    required String password,
  }) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final secretKey = await _deriveKey(password, salt);
    final secretBox = await _cipher.encrypt(
      zipBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final header = <String, dynamic>{
      'format': 'monolog_encrypted_backup',
      'version': version,
      'payload': 'zip',
      'cipher': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
    };

    final headerBytes = utf8.encode(jsonEncode(header));
    final headerLengthBytes = ByteData(4)..setUint32(0, headerBytes.length);

    return Uint8List.fromList([
      ..._magicBytes,
      ...headerLengthBytes.buffer.asUint8List(),
      ...headerBytes,
      ...secretBox.cipherText,
    ]);
  }

  Future<Uint8List> decryptZipBytes(
    List<int> encryptedBytes, {
    required String password,
  }) async {
    try {
      if (!isEncryptedBackup(encryptedBytes)) {
        throw const BackupEncryptionException('Unsupported backup format');
      }

      final headerStart = _magicBytes.length + 4;
      final headerLength = ByteData.sublistView(
        Uint8List.fromList(encryptedBytes),
        _magicBytes.length,
        headerStart,
      ).getUint32(0);
      final headerEnd = headerStart + headerLength;
      if (headerEnd > encryptedBytes.length) {
        throw const BackupEncryptionException('Invalid backup header');
      }

      final headerJson = utf8.decode(
        encryptedBytes.sublist(headerStart, headerEnd),
      );
      final header = jsonDecode(headerJson) as Map<String, dynamic>;
      _validateHeader(header);

      final salt = base64Decode(header['salt'] as String);
      final nonce = base64Decode(header['nonce'] as String);
      final mac = base64Decode(header['mac'] as String);
      final cipherText = encryptedBytes.sublist(headerEnd);
      final secretKey = await _deriveKey(password, salt);
      final decrypted = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: secretKey,
      );

      return Uint8List.fromList(decrypted);
    } on BackupEncryptionException {
      rethrow;
    } catch (_) {
      throw const BackupEncryptionException(
        'Could not decrypt backup. The password may be incorrect.',
      );
    }
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) {
    return _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  void _validateHeader(Map<String, dynamic> header) {
    if (header['format'] != 'monolog_encrypted_backup' ||
        header['version'] != version ||
        header['payload'] != 'zip' ||
        header['cipher'] != 'AES-256-GCM' ||
        header['kdf'] != 'PBKDF2-HMAC-SHA256' ||
        header['iterations'] != iterations) {
      throw const BackupEncryptionException('Unsupported encrypted backup');
    }
  }
}
