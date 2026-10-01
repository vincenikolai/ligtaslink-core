import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class MerkleEngine {
  static String hashTransaction(Map<String, dynamic> transaction) =>
      sha256.convert(utf8.encode(jsonEncode(transaction))).toString();

  static List<List<String>> buildMerkleTree(
    List<Map<String, dynamic>> transactions,
  ) {
    if (transactions.isEmpty) return <List<String>>[<String>[]];
    final levels = <List<String>>[
      transactions.map(hashTransaction).toList(growable: false),
    ];
    while (levels.last.length > 1) {
      final current = levels.last;
      final next = <String>[];
      for (var i = 0; i < current.length; i += 2) {
        final right = i + 1 < current.length ? current[i + 1] : current[i];
        next.add(sha256.convert(utf8.encode(current[i] + right)).toString());
      }
      levels.add(next);
    }
    return levels;
  }

  static String generateMerkleRoot(List<Map<String, dynamic>> transactions) =>
      buildMerkleTree(transactions).last.firstOrNull ??
      sha256.convert(utf8.encode('')).toString();

  static Future<String> signRootEd25519(
    String root,
    List<int> privateKey,
  ) async {
    if (privateKey.length != 32) {
      throw ArgumentError.value(
        privateKey.length,
        'privateKey',
        'must be a 32-byte Ed25519 seed',
      );
    }
    final algorithm = Ed25519();
    final keyPair =
        await algorithm.newKeyPairFromSeed(Uint8List.fromList(privateKey));
    final signature =
        await algorithm.sign(utf8.encode(root), keyPair: keyPair);
    return base64UrlEncode(signature.bytes);
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
