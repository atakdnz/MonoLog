import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monolog/services/backup_encryption_service.dart';

void main() {
  group('BackupEncryptionService', () {
    test('encryptZipBytes -> decryptZipBytes returns original bytes', () async {
      final service = BackupEncryptionService();
      final originalBytes = utf8.encode('fake zip bytes');

      final encrypted = await service.encryptZipBytes(
        originalBytes,
        password: 'correct horse battery staple',
      );
      final decrypted = await service.decryptZipBytes(
        encrypted,
        password: 'correct horse battery staple',
      );

      expect(decrypted, originalBytes);
      expect(BackupEncryptionService.isEncryptedBackup(encrypted), isTrue);
    });

    test('decryptZipBytes fails with wrong password', () async {
      final service = BackupEncryptionService();
      final encrypted = await service.encryptZipBytes(
        utf8.encode('fake zip bytes'),
        password: 'right-password',
      );

      expect(
        () => service.decryptZipBytes(encrypted, password: 'wrong-password'),
        throwsA(isA<BackupEncryptionException>()),
      );
    });

    test('decryptZipBytes fails when ciphertext is tampered', () async {
      final service = BackupEncryptionService();
      final encrypted = await service.encryptZipBytes(
        utf8.encode('fake zip bytes'),
        password: 'password',
      );
      final tampered = List<int>.from(encrypted);
      tampered[tampered.length - 1] = tampered.last ^ 1;

      expect(
        () => service.decryptZipBytes(tampered, password: 'password'),
        throwsA(isA<BackupEncryptionException>()),
      );
    });

    test('decryptZipBytes fails for unsupported version', () async {
      final service = BackupEncryptionService();
      final encrypted = await service.encryptZipBytes(
        utf8.encode('fake zip bytes'),
        password: 'password',
      );
      final headerLengthStart = 'MONOLOG_ENCRYPTED_BACKUP\n'.length;
      final headerLength = encrypted
          .sublist(headerLengthStart, headerLengthStart + 4)
          .fold<int>(0, (value, byte) => (value << 8) | byte);
      final headerStart = headerLengthStart + 4;
      final headerEnd = headerStart + headerLength;
      final header =
          jsonDecode(utf8.decode(encrypted.sublist(headerStart, headerEnd)))
              as Map<String, dynamic>;
      header['version'] = 999;
      final replacementHeader = utf8.encode(jsonEncode(header));
      final replacementLength = [
        (replacementHeader.length >> 24) & 0xff,
        (replacementHeader.length >> 16) & 0xff,
        (replacementHeader.length >> 8) & 0xff,
        replacementHeader.length & 0xff,
      ];
      final unsupported = [
        ...encrypted.sublist(0, headerLengthStart),
        ...replacementLength,
        ...replacementHeader,
        ...encrypted.sublist(headerEnd),
      ];

      expect(
        () => service.decryptZipBytes(unsupported, password: 'password'),
        throwsA(isA<BackupEncryptionException>()),
      );
    });
  });
}
