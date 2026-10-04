import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show compute;

import '../models/distribution_log.dart';

/// On-device SHA-256 Merkle engine. Must stay byte-for-byte identical to
/// backend_daemon/merkle.js and simulation/run_wilcoxon_test.py:
///   S      = transaction_id + household_id + items_received + timestamp + worker_id
///   leaf   = SHA-256(UTF-8(S))
///   parent = SHA-256(left || right)   (raw 32-byte digests; odd layer duplicates last)
class MerkleEngine {
  MerkleEngine._();

  static String canonicalString(DistributionLog log) =>
      '${log.transactionId}${log.householdId}${log.itemsReceived}${log.timestamp}${log.workerId}';

  static Uint8List leafHash(DistributionLog log) =>
      Uint8List.fromList(sha256.convert(utf8.encode(canonicalString(log))).bytes);

  /// Every layer of the tree, leaves first and the root layer last.
  static List<List<Uint8List>> buildLayers(List<Uint8List> leaves) {
    if (leaves.isEmpty) {
      throw ArgumentError.value(leaves, 'leaves', 'cannot build a Merkle tree from an empty batch');
    }
    final layers = <List<Uint8List>>[leaves];
    while (layers.last.length > 1) {
      final current = layers.last;
      final next = <Uint8List>[];
      for (var i = 0; i < current.length; i += 2) {
        final left = current[i];
        final right = i + 1 < current.length ? current[i + 1] : current[i];
        final joined = Uint8List(left.length + right.length)
          ..setAll(0, left)
          ..setAll(left.length, right);
        next.add(Uint8List.fromList(sha256.convert(joined).bytes));
      }
      layers.add(next);
    }
    return layers;
  }

  static Uint8List rootFromLeaves(List<Uint8List> leaves) => buildLayers(leaves).last.first;

  /// Same result as [rootFromLeaves], computed on a background isolate so the
  /// O(n) layer hashing never blocks a UI frame. On web, compute() falls back
  /// to running inline because isolates are unavailable there.
  static Future<Uint8List> rootFromLeavesAsync(List<Uint8List> leaves) => compute(_rootEntry, List<Uint8List>.of(leaves));

  static Uint8List merkleRoot(List<DistributionLog> logs) => rootFromLeaves(logs.map(leafHash).toList(growable: false));

  static int treeHeight(int leafCount) {
    if (leafCount <= 1) return 0;
    var height = 0;
    for (var n = leafCount; n > 1; n = (n + 1) ~/ 2) {
      height++;
    }
    return height;
  }
}

/// Top-level so compute() can spawn it on another isolate.
Uint8List _rootEntry(List<Uint8List> leaves) => MerkleEngine.rootFromLeaves(leaves);

/// Ed25519 signing of R_offline with the worker's keypair.
class RootSigner {
  RootSigner._(this._keyPair, this.publicKey);

  static final Ed25519 _algorithm = Ed25519();
  final SimpleKeyPair _keyPair;
  final Uint8List publicKey;

  static Future<RootSigner> fromSeed(List<int> seed) async {
    if (seed.length != 32) {
      throw ArgumentError.value(seed.length, 'seed', 'must be a 32-byte Ed25519 seed');
    }
    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    return RootSigner._(keyPair, Uint8List.fromList(publicKey.bytes));
  }

  /// Signs the raw 32-byte Merkle root.
  Future<Uint8List> sign(Uint8List root) async {
    final signature = await _algorithm.sign(root, keyPair: _keyPair);
    return Uint8List.fromList(signature.bytes);
  }

  static Future<bool> verify(Uint8List root, Uint8List signature, Uint8List publicKey) => _algorithm.verify(
        root,
        signature: Signature(signature, publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519)),
      );
}

String toHex0x(List<int> bytes) {
  final buffer = StringBuffer('0x');
  for (final b in bytes) {
    buffer.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

Uint8List fromHex0x(String hex) {
  final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
  if (clean.length.isOdd) throw FormatException('Odd-length hex string', hex);
  return Uint8List.fromList([for (var i = 0; i < clean.length; i += 2) int.parse(clean.substring(i, i + 2), radix: 16)]);
}
