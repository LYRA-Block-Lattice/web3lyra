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
}
