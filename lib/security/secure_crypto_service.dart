import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

import 'secure_http_errors.dart';

class EncryptedPayload {
  final Uint8List key;
  final String encryptedKey;
  final String iv;
  final String ciphertext;

  const EncryptedPayload({
    required this.key,
    required this.encryptedKey,
    required this.iv,
    required this.ciphertext,
  });
}

class SecureCryptoService {
  final Random _random;

  SecureCryptoService({Random? random}) : _random = random ?? Random.secure();

  EncryptedPayload encryptRequest({
    required Map<String, dynamic> payload,
    required String publicKeyPem,
  }) {
    try {
      final key = _randomBytes(32);
      final iv = _randomBytes(12);
      final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
      final ciphertext = _aesGcmCrypt(
        key: key,
        iv: iv,
        input: plaintext,
        forEncryption: true,
      );
      final encryptedKey = _rsaOaepSha256Encrypt(
        key,
        _parsePublicKey(publicKeyPem),
      );
      return EncryptedPayload(
        key: key,
        encryptedKey: base64Encode(encryptedKey),
        iv: base64Encode(iv),
        ciphertext: base64Encode(ciphertext),
      );
    } catch (error) {
      throw SecureHttpException(
        code: SecureHttpErrorCode.encryptionFailed,
        message: 'Secure request encryption failed',
        safeDebugMessage: error.runtimeType.toString(),
      );
    }
  }

  Map<String, dynamic> decryptResponse({
    required String iv,
    required String ciphertext,
    required Uint8List key,
  }) {
    try {
      final plaintext = _aesGcmCrypt(
        key: key,
        iv: base64Decode(iv),
        input: base64Decode(ciphertext),
        forEncryption: false,
      );
      final decoded = jsonDecode(utf8.decode(plaintext));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('secure response body is not an object');
      }
      return decoded;
    } catch (error) {
      throw SecureHttpException(
        code: SecureHttpErrorCode.decryptionFailed,
        message: 'Secure response decryption failed',
        safeDebugMessage: error.runtimeType.toString(),
      );
    }
  }

  Uint8List _aesGcmCrypt({
    required Uint8List key,
    required Uint8List iv,
    required Uint8List input,
    required bool forEncryption,
  }) {
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      forEncryption,
      AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)),
    );
    return cipher.process(input);
  }

  Uint8List _rsaOaepSha256Encrypt(Uint8List input, RSAPublicKey publicKey) {
    final cipher = OAEPEncoding.withSHA256(RSAEngine());
    cipher.init(
      true,
      ParametersWithRandom(
        PublicKeyParameter<RSAPublicKey>(publicKey),
        _secureRandom(),
      ),
    );
    return cipher.process(input);
  }

  RSAPublicKey _parsePublicKey(String pem) {
    final bytes = _decodePem(pem);
    final parser = ASN1Parser(bytes);
    final topLevel = parser.nextObject() as ASN1Sequence;

    ASN1Sequence rsaSequence;
    if (topLevel.elements?.length == 2 &&
        topLevel.elements![1] is ASN1BitString) {
      final publicKeyBitString = topLevel.elements![1] as ASN1BitString;
      final publicKeyBytes = Uint8List.fromList(
        publicKeyBitString.stringValues ?? const [],
      );
      rsaSequence = ASN1Parser(publicKeyBytes).nextObject() as ASN1Sequence;
    } else {
      rsaSequence = topLevel;
    }

    final modulus = (rsaSequence.elements![0] as ASN1Integer).integer!;
    final exponent = (rsaSequence.elements![1] as ASN1Integer).integer!;
    return RSAPublicKey(modulus, exponent);
  }

  Uint8List _decodePem(String pem) {
    final body = pem
        .replaceAll(RegExp('-----BEGIN [^-]+-----'), '')
        .replaceAll(RegExp('-----END [^-]+-----'), '')
        .replaceAll(RegExp(r'\s'), '');
    return Uint8List.fromList(base64Decode(body));
  }

  Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
  }

  SecureRandom _secureRandom() {
    final secureRandom = FortunaRandom();
    secureRandom.seed(KeyParameter(_randomBytes(32)));
    return secureRandom;
  }
}
