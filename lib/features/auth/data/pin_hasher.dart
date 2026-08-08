import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/scrypt.dart';

/// Scrypt PIN hashing that mirrors the Electron `auth.js` contract exactly, so
/// a PIN set by either app validates against the same Postgres `settings` rows.
///
/// Node's `crypto.scryptSync(pin, salt, 64)` uses the library defaults
/// N=16384, r=8, p=1 with a 64-byte output; the salt is the raw bytes of the
/// stored hex string. This class reproduces those parameters.
class PinHasher {
  const PinHasher();

  static const int _n = 16384; // CPU/memory cost (Node default)
  static const int _r = 8;
  static const int _p = 1;
  static const int _keyLen = 64;
  static const int _saltBytes = 16;

  /// Generates a fresh salt as a hex string (parity with
  /// `crypto.randomBytes(16).toString("hex")`).
  String newSaltHex() {
    final rng = Random.secure();
    final bytes =
        Uint8List.fromList(List.generate(_saltBytes, (_) => rng.nextInt(256)));
    return _toHex(bytes);
  }

  /// Derives the hex-encoded scrypt hash of [pin] using [saltHex].
  String hash(String pin, String saltHex) {
    final salt = _fromHex(saltHex);
    final derivator = Scrypt()
      ..init(ScryptParameters(_n, _r, _p, _keyLen, salt));
    final out = derivator.process(
      Uint8List.fromList(utf8.encode(pin)),
    );
    return _toHex(out);
  }

  /// Constant-time comparison of the derived hash against [expectedHashHex]
  /// (parity with `crypto.timingSafeEqual`).
  bool verify(String pin, String saltHex, String expectedHashHex) {
    final candidate = _fromHex(hash(pin, saltHex));
    final expected = _fromHex(expectedHashHex);
    if (candidate.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < candidate.length; i++) {
      diff |= candidate[i] ^ expected[i];
    }
    return diff == 0;
  }

  static String _toHex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static Uint8List _fromHex(String hex) {
    final clean = hex.length.isOdd ? '0$hex' : hex;
    final out = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}
