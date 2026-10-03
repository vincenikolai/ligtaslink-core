import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ligtaslink_mobile/crypto/merkle_engine.dart';
import 'package:ligtaslink_mobile/models/distribution_log.dart';

/// Mirrors the generator in test_vectors/merkle_vectors.json (shared with Node and Python).
DistributionLog vectorTx(int i) => DistributionLog(
      transactionId: 'tx-${i.toString().padLeft(4, '0')}',
      householdId: 'b33d-hh-${(i % 500 + 1).toString().padLeft(3, '0')}',
      itemsReceived: 1 + i % 3,
      timestamp: '2026-10-03T08:${(i % 60).toString().padLeft(2, '0')}:00.000Z',
      workerId: 'W-01',
      syncedStatus: 0,
    );

const expectedRoots = {
  1: '0xa9df0a25b1025062344d402e1c837ab0f5ae313b8cfc1a6291b84398a6d52905',
  2: '0x6c08908cbb31fb480a939508cdb77efd58a2ed4517cce90b82a909218ba1eeaf',
  3: '0xe65b77ca934f79b0d56298301ae84541a4710b791546e2b337a0f5367c16f785',
  4: '0x29d40f5b70434e007de94d83ebe2f27a130a1e8f7f075596e7775be599f2a453',
  5: '0x01e2d912b2a1f2bb328bbcd245d7fabce4850de04e5e767e0969138fcb40918d',
  7: '0xae99985fae94f9139157e1bb96137bf35923a3f32ddc8f283a1ff53818ddab63',
  8: '0xaf7f4994fbab67b4c253458a6d327ec1ecb0f245f6e7add6235a58f9ba412e60',
  16: '0x30cd2b2b56a3e850b21dd3e2d270a8a520d4c6d1d436f0d9d4fa9b3680e18eda',
  33: '0xd267bd78317be08c411b0103dc65accf1714f32139a7ea1db0860f63c36f40a6',
};

void main() {
  test('canonical string concatenates the five leaf fields', () {
    expect(MerkleEngine.canonicalString(vectorTx(0)), 'tx-0000b33d-hh-00112026-10-03T08:00:00.000ZW-01');
  });

  test('Merkle roots match the Node.js daemon and Python simulation', () {
    expectedRoots.forEach((size, root) {
      final logs = List.generate(size, vectorTx);
      expect(toHex0x(MerkleEngine.merkleRoot(logs)), root, reason: 'batch size $size');
    });
  });

  test('modifying any single record changes the root', () {
    final logs = List.generate(16, vectorTx);
    final original = toHex0x(MerkleEngine.merkleRoot(logs));
    for (var i = 0; i < logs.length; i++) {
      final tampered = List.of(logs);
      final t = logs[i];
      tampered[i] = DistributionLog(
        transactionId: t.transactionId,
        householdId: t.householdId,
        itemsReceived: t.itemsReceived + 1,
        timestamp: t.timestamp,
        workerId: t.workerId,
        syncedStatus: 0,
      );
      expect(toHex0x(MerkleEngine.merkleRoot(tampered)), isNot(original), reason: 'record $i');
    }
  });

  test('empty batch is rejected', () {
    expect(() => MerkleEngine.rootFromLeaves(const []), throwsArgumentError);
  });

  test('tree height', () {
    expect([0, 1, 2, 3, 4, 5, 8, 9].map(MerkleEngine.treeHeight), [0, 0, 1, 2, 2, 3, 3, 4]);
  });

  test('Ed25519 signature over R_offline verifies and rejects a different root', () async {
    final signer = await RootSigner.fromSeed(List<int>.generate(32, (i) => i));
    final root = MerkleEngine.merkleRoot(List.generate(7, vectorTx));
    final signature = await signer.sign(root);
    expect(signature.length, 64);
    expect(await RootSigner.verify(root, signature, signer.publicKey), isTrue);
    final other = Uint8List.fromList(utf8.encode('x' * 32));
    expect(await RootSigner.verify(other, signature, signer.publicKey), isFalse);
  });
}
