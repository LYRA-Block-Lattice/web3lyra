import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:lyra/lyra.dart';
import 'package:meta/meta.dart';

import '../crypto/formatting.dart';
import '../crypto/keccak.dart';

/// Represents an Ethereum address.
@immutable
class LyraAddress {
  static final RegExp _basicAddress =
      RegExp(r'^(0x)?[0-9a-f]{40}', caseSensitive: false);

  /// The length of an ethereum address, in bytes.
  static const addressByteLength = 20;

  final Uint8List addressBytes;

  /// An ethereum address from the raw address bytes.
  const LyraAddress(this.addressBytes);
  //    : assert(addressBytes.length == addressByteLength);

  /// Constructs an Ethereum address from a public key. The address is formed by
  /// the last 20 bytes of the keccak hash of the public key.
  factory LyraAddress.fromPublicKey(Uint8List publicKey) {
    return LyraAddress(publicKey);
  }

  factory LyraAddress.fromAccountId(String accountId) {
    final publicKey = LyraCrypto.lyraDecAccountId(accountId);
    return LyraAddress(hexToBytes(publicKey));
  }

  /// Parses an Ethereum address from the hexadecimal representation. The
  /// representation must have a length of 20 bytes (or 40 hexadecimal chars),
  /// and can optionally be prefixed with "0x".
  ///
  /// If [enforceEip55] is true or the address has both uppercase and lowercase
  /// chars, the address must be valid according to [EIP 55](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-55.md).
  factory LyraAddress.fromHex(String hex, {bool enforceEip55 = false}) {
    if (!_basicAddress.hasMatch(hex)) {
      throw ArgumentError.value(hex, 'address',
          'Must be a hex string with a length of 40, optionally prefixed with "0x"');
    }

    if (!enforceEip55 &&
        (hex.toUpperCase() == hex || hex.toLowerCase() == hex)) {
      return LyraAddress(hexToBytes(hex));
    }

    // Validates as of EIP 55, https://ethereum.stackexchange.com/a/1379
    final address = strip0x(hex);
    final hash = bytesToHex(keccakAscii(address.toLowerCase()));
    for (var i = 0; i < 40; i++) {
      // the nth letter should be uppercase if the nth digit of casemap is 1
      final hashedPos = int.parse(hash[i], radix: 16);
      if ((hashedPos > 7 && address[i].toUpperCase() != address[i]) ||
          (hashedPos <= 7 && address[i].toLowerCase() != address[i])) {
        throw ArgumentError('Address has invalid case-characters and is'
            'thus not EIP-55 conformant, rejecting. Address was: $hex');
      }
    }

    return LyraAddress(hexToBytes(hex));
  }

  /// A hexadecimal representation of this address, padded to a length of 40
  /// characters or 20 bytes, and prefixed with "0x".
  String get hex =>
      bytesToHex(addressBytes, include0x: true, forcePadLength: 40);

  /// A hexadecimal representation of this address, padded to a length of 40
  /// characters or 20 bytes, but not prefixed with "0x".
  String get hexNo0x =>
      bytesToHex(addressBytes, include0x: false, forcePadLength: 40);

  /// Returns this address in a hexadecimal representation, like with [hex].
  /// The hexadecimal characters A-F in the address will be in lower- or
  /// uppercase depending on [EIP 55](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-55.md).
  String get hexEip55 {
    // https://eips.ethereum.org/EIPS/eip-55#implementation
    final hex = hexNo0x.toLowerCase();
    final hash = bytesToHex(keccakAscii(hexNo0x));

    final eip55 = StringBuffer('0x');
    for (var i = 0; i < hex.length; i++) {
      if (int.parse(hash[i], radix: 16) >= 8) {
        eip55.write(hex[i].toUpperCase());
      } else {
        eip55.write(hex[i]);
      }
    }

    return eip55.toString();
  }

  @override
  String toString() => LyraCrypto.lyraEncPub(addressBytes);

  @override
  bool operator ==(other) {
    return identical(this, other) ||
        (other is LyraAddress &&
            const ListEquality().equals(addressBytes, other.addressBytes));
  }

  @override
  int get hashCode {
    return hex.hashCode;
  }
}
