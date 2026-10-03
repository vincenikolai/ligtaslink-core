import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'merkle_engine.dart';

/// Loads (or creates on first launch) the worker's Ed25519 seed from the platform
/// keystore: Android Keystore, iOS Keychain, Windows Credential Manager, or
/// WebCrypto-encrypted storage on the web.
class WorkerKeyStore {
  WorkerKeyStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _seedKey(String workerId) => 'ligtaslink.ed25519.seed.$workerId';

  Future<RootSigner> loadOrCreate(String workerId) async {
    var seedHex = await _storage.read(key: _seedKey(workerId));
    if (seedHex == null) {
      final random = Random.secure();
      seedHex = toHex0x(List<int>.generate(32, (_) => random.nextInt(256)));
      await _storage.write(key: _seedKey(workerId), value: seedHex);
    }
    return RootSigner.fromSeed(fromHex0x(seedHex));
  }
}
