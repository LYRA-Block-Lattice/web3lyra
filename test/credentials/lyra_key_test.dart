import 'dart:math';

import 'package:test/test.dart';
import 'package:web3dart/web3dart.dart';

final pubKeys = {};

void main() {
  test('generate wallet', () {
    final rnd = Random.secure();
    final prvKey = LyraPrivateKey.createRandom(rnd);
    final pub = prvKey.address;
    expect(pub.toString()[0], 'L');
  });

  test('restore wallet from private key', () async {
    final privateKey =
        '3249c9f5976518da19a67048552603e8cf8e54c7b2ee520489656e164134d06d';
    var pubAddr =
        'LUaFA7PZsTPkb6TBfinHYaoGXbecPnLDKtV7vVnkyujnJQgoJytAdfcAH7W3SQETJ4VGKGDxNzNnjNX49WqEH8nPQZ7fA6';

    final Credentials credentials = LyraPrivateKey.fromHex(privateKey);
    final accountAddress = await credentials.extractAddress();
    final pub = accountAddress.toString();
    expect(pub, pubAddr);
  });
}
