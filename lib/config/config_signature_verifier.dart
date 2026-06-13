import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

import 'config_errors.dart';
import 'config_models.dart';

class ConfigSignatureVerifier {
  final String publicKeyPem;

  const ConfigSignatureVerifier(this.publicKeyPem);

  bool verify(RemoteConfigDocument document) {
    try {
      final publicKey = _parsePublicKey(publicKeyPem);
      final signer = PSSSigner(RSAEngine(), SHA256Digest(), SHA256Digest());
      signer.init(
        false,
        ParametersWithSaltConfiguration(
          PublicKeyParameter<RSAPublicKey>(publicKey),
          _secureRandomForVerification(),
          32,
        ),
      );
      final signature = PSSSignature(base64Decode(document.signature));
      final payload = Uint8List.fromList(utf8.encode(document.canonicalPayload()));
      return signer.verifySignature(payload, signature);
    } catch (_) {
      return false;
    }
  }

  void verifyOrThrow(RemoteConfigDocument document) {
    if (!verify(document)) {
      throw const RemoteConfigException(
        RemoteConfigErrorCode.invalidSignature,
        'Remote config signature verification failed',
      );
    }
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

  SecureRandom _secureRandomForVerification() {
    final random = FortunaRandom();
    random.seed(KeyParameter(Uint8List(32)));
    return random;
  }
}
