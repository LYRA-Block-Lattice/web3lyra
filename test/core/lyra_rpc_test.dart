//import 'package:web3dart/crypto.dart';
import 'package:test/test.dart';
import 'package:web3dart/web3dart.dart';

void main() {
  test('get balance', () async {
    // const privateKey =
    //     '3249c9f5976518da19a67048552603e8cf8e54c7b2ee520489656e164134d06d';
    // const pvtKeyLyra = 'P9YeD3uNs8puVFyrm9CJN2cBv4Nzg99UK2Ku6xDiXr2QmdUBc';
    // const pubAddr = 'LUaFA7PZsTPkb6TBfinHYaoGXbecPnLDKtV7vVnkyujnJQgoJytAdfcAH7W3SQETJ4VGKGDxNzNnjNX49WqEH8nPQZ7fA6';

    const pvt2 = '2UR1yvqpS2b4rTFRBCX9Pn7hMRcxz5rjGFg2QPTNddCXxQGQSs';
    const pub2 =
        'LZr7SSwo6hvdg41WMwH5fUqD3KRmFfQwaJi9WWMZR1JjgwHQgQSESoHZoPrhqqAR957a7Uig8vzmyBSMKa8gXr6FhceQ8y';

    final credentials = LyraPrivateKey.fromString(pvt2);

    final accountId = (await credentials.extractAddress()).toString();
    expect(accountId, pub2);

    final addr = LyraAddress.fromAccountId(accountId);
    expect(addr.toString(), pub2);

    final client = Web3Client('testnet');
    final balance = await client.getBalance(addr);

    expect(balance['LYR'], 1000);
  });
}
