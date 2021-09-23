part of 'package:web3dart/web3dart.dart';

/// Signature for a function that opens a socket on which json-rpc operations
/// can be performed.
///
/// Typically, this would be a websocket. The `web_socket_channel` package on
/// pub is suitable to create websockets. An implementation using that library
/// could look like this:
/// ```dart
/// import "package:web3dart/web3dart.dart";
/// import "package:web_socket_channel/io.dart";
///
/// final client = Web3Client(rpcUrl, Client(), socketConnector: () {
///    return IOWebSocketChannel.connect(wsUrl).cast<String>();
/// });
/// ```
typedef SocketConnector = StreamChannel<String> Function();

/// Class for sending requests over an HTTP JSON-RPC API endpoint to Ethereum
/// clients. This library won't use the accounts feature of clients to use them
/// to create transactions, you will instead have to obtain private keys of
/// accounts yourself.
class Web3Client {
  /// Starts a client that connects to a JSON rpc API, available at [url]. The
  /// Am isolate will be used to perform expensive operations, such as signing
  /// transactions or computing private keys.
  Web3Client(String network) : _network = network {
    _operations = _ExpensiveOperations();
  }

  static const BlockNum _defaultBlock = BlockNum.current();

  // maybe null
  Credentials? _prvKey;

  final String _network;
  late String _nodeAddress;
  Peer? _client;

  late _ExpensiveOperations _operations;
//  late _FilterEngine _filters;

  ///Whether errors, handled or not, should be printed to the console.
  bool printErrors = false;

  /// connect to JsonRPC and get service status.
  Future<void> init() async {
    // crypto

    // if (!LyraCrypto.isPrivateKeyValid(prvKey)) {
    //   throw ('Not valid private key.');
    // }
    // accountId = LyraCrypto.prvToPub(prvKey);
    _nodeAddress = 'wss://$_network.lyra.live/api/v1/socket';

    // websocket
    final ws = WebSocketChannel.connect(Uri.parse(_nodeAddress));
    _client = Peer(ws.cast<String>());

    // The client won't subscribe to the input stream until you call `listen`.
    // The returned Future won't complete until the connection is closed.
    unawaited(_client!.listen());

    _client!.registerMethod('Notify', (Parameters news) {
      print('Got news from Lyra: ${news.asList[1]}');
    });

    _client!.registerMethod('Sign', (Parameters req) {
      print('Got signning callback.');

      print('Signing ${req.asList[1]}');
      try {
        final signature = _prvKey!.signLyra(req.asList[1].toString());
        print('signature is: $signature');
        return ['p1393', signature];
      } on Exception catch (e) {
        return ['error', e.toString()];
      }
    });

    try {
      final status =
          await _client!.sendRequest('Status', ['2.3.0.0', _network]);
      print(status.toString());
    } on RpcException catch (error) {
      print('RPC error ${error.code}: ${error.message}');
    }
  }

  Future<T> _makeRPCCall<T>(String function, [List<dynamic>? params]) async {
    try {
      if (_client == null || _client!.isClosed) {
        await init();
      }

      print(params);
      final data = await _client!.sendRequest(function, params);
      // ignore: only_throw_errors
      if (data is Error || data is Exception) throw data as Object;

      print(json.encode(data));
      return data as T;
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      if (printErrors) print(e);

      rethrow;
    }
  }

  String _getBlockParam(BlockNum? block) {
    return (block ?? _defaultBlock).toBlockParam();
  }

  /// Constructs a new [Credentials] with the provided [privateKey] by using
  /// an [LyraPrivateKey].
  Future<LyraPrivateKey> credentialsFromPrivateKey(String privateKey) {
    return _operations.privateKeyFromHex(privateKey);
  }

  /// Returns the version of the client we're sending requests to.
  Future<String> getClientVersion() {
    return _makeRPCCall('web3_clientVersion');
  }

  /// Returns the id of the network the client is currently connected to.
  ///
  /// In a non-private network, the network ids usually correspond to the
  /// following networks:
  /// 1: Ethereum Mainnet
  /// 2: Morden Testnet (deprecated)
  /// 3: Ropsten Testnet
  /// 4: Rinkeby Testnet
  /// 42: Kovan Testnet
  Future<int> getNetworkId() {
    return _makeRPCCall<String>('net_version').then(int.parse);
  }

  /// Returns true if the node is actively listening for network connections.
  Future<bool> isListeningForNetwork() {
    return _makeRPCCall('net_listening');
  }

  /// Returns the amount of Ethereum nodes currently connected to the client.
  Future<int> getPeerCount() async {
    final hex = await _makeRPCCall<String>('net_peerCount');
    return hexToInt(hex).toInt();
  }

  /// Returns the version of the Ethereum-protocol the client is using.
  Future<int> getEtherProtocolVersion() async {
    final hex = await _makeRPCCall<String>('eth_protocolVersion');
    return hexToInt(hex).toInt();
  }

  /// Returns an object indicating whether the node is currently synchronising
  /// with its network.
  ///
  /// If so, progress information is returned via [SyncInformation].
  Future<SyncInformation> getSyncStatus() async {
    final data = await _makeRPCCall<dynamic>('eth_syncing');

    if (data is Map) {
      final startingBlock = hexToInt(data['startingBlock'] as String).toInt();
      final currentBlock = hexToInt(data['currentBlock'] as String).toInt();
      final highestBlock = hexToInt(data['highestBlock'] as String).toInt();

      return SyncInformation(startingBlock, currentBlock, highestBlock);
    } else {
      return SyncInformation(null, null, null);
    }
  }

  Future<LyraAddress> coinbaseAddress() async {
    final hex = await _makeRPCCall<String>('eth_coinbase');
    return LyraAddress.fromHex(hex);
  }

  /// Returns true if the connected client is currently mining, false if not.
  Future<bool> isMining() {
    return _makeRPCCall('eth_mining');
  }

  /// Returns the amount of hashes per second the connected node is mining with.
  Future<int> getMiningHashrate() {
    return _makeRPCCall<String>('eth_hashrate')
        .then((s) => hexToInt(s).toInt());
  }

  /// Returns the amount of Ether typically needed to pay for one unit of gas.
  ///
  /// Although not strictly defined, this value will typically be a sensible
  /// amount to use.
  Future<EtherAmount> getGasPrice() async {
    final data = await _makeRPCCall<String>('eth_gasPrice');

    return EtherAmount.fromUnitAndValue(EtherUnit.wei, hexToInt(data));
  }

  /// Returns the number of the most recent block on the chain.
  Future<int> getBlockNumber() {
    return _makeRPCCall<String>('eth_blockNumber')
        .then((s) => hexToInt(s).toInt());
  }

  /// Gets the balance of the account with the specified address.
  ///
  /// This function allows specifying a custom block mined in the past to get
  /// historical data. By default, [BlockNum.current] will be used.
  Future<Map<String, double>> getBalance(LyraAddress address,
      {BlockNum? atBlock}) {
    return _makeRPCCall<Map<String, dynamic>>('Balance', [address.toString()])
        .then((data) {
      if (data['height'] as int == 0) {
        return <String, double>{};
      } else {
        final bls =
            Map<String, double>.from(data['balance'] as Map<dynamic, dynamic>);
        return bls;
      }
    });
  }

  /// Gets an element from the storage of the contract with the specified
  /// [address] at the specified [position].
  /// See https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getstorageat for
  /// more details.
  /// This function allows specifying a custom block mined in the past to get
  /// historical data. By default, [BlockNum.current] will be used.
  Future<Uint8List> getStorage(LyraAddress address, BigInt position,
      {BlockNum? atBlock}) {
    final blockParam = _getBlockParam(atBlock);

    return _makeRPCCall<String>('eth_getStorageAt', [
      address.hex,
      '0x${position.toRadixString(16)}',
      blockParam
    ]).then(hexToBytes);
  }

  /// Gets the amount of transactions issued by the specified [address].
  ///
  /// This function allows specifying a custom block mined in the past to get
  /// historical data. By default, [BlockNum.current] will be used.
  Future<int> getTransactionCount(LyraAddress address, {BlockNum? atBlock}) {
    final blockParam = _getBlockParam(atBlock);

    return _makeRPCCall<String>(
            'eth_getTransactionCount', [address.hex, blockParam])
        .then((hex) => hexToInt(hex).toInt());
  }

  /// Returns the information about a transaction requested by transaction hash
  /// [transactionHash].
  Future<TransactionInformation> getTransactionByHash(String transactionHash) {
    return _makeRPCCall<Map<String, dynamic>>(
            'eth_getTransactionByHash', [transactionHash])
        .then((s) => TransactionInformation.fromMap(s));
  }

  /// Returns an receipt of a transaction based on its hash.
  Future<TransactionReceipt?> getTransactionReceipt(String hash) {
    return _makeRPCCall<Map<String, dynamic>?>(
            'eth_getTransactionReceipt', [hash])
        .then((s) => s != null ? TransactionReceipt.fromMap(s) : null);
  }

  /// Gets the code of a contract at the specified [address]
  ///
  /// This function allows specifying a custom block mined in the past to get
  /// historical data. By default, [BlockNum.current] will be used.
  Future<Uint8List> getCode(LyraAddress address, {BlockNum? atBlock}) {
    return _makeRPCCall<String>(
        'eth_getCode', [address.hex, _getBlockParam(atBlock)]).then(hexToBytes);
  }

  /// Returns all logs matched by the filter in [options].
  ///
  /// See also:
  ///  - [events], which can be used to obtain a stream of log events
  ///  - https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getlogs
  Future<List<FilterEvent>> getLogs(FilterOptions options) {
    final filter = _EventFilter(options);
    return _makeRPCCall<List<dynamic>>(
        'eth_getLogs', [filter._createParamsObject(true)]).then((logs) {
      return logs.map(filter.parseChanges).toList();
    });
  }

  Future<Map<String, double>> receiveTransaction(Credentials cred) async {
    // first save private key
    _prvKey = cred;

    // ignore: literal_only_boolean_expressions
    while (true) {
      final data = await _makeRPCCall<Map<String, dynamic>>(
          'Receive', [(await cred.extractAddress()).toString()]);

      if (data['unreceived'] as bool) {
        continue;
      }

      _prvKey = null;

      final bls =
          Map<String, double>.from(data['balance'] as Map<dynamic, dynamic>);
      return bls;
    }
  }

  /// Signs the given transaction using the keys supplied in the [cred]
  /// object to upload it to the client so that it can be executed.
  ///
  /// Returns a hash of the transaction which, after the transaction has been
  /// included in a mined block, can be used to obtain detailed information
  /// about the transaction.
  Future<dynamic> sendTransaction(Credentials cred, Transaction transaction,
      {int? chainId = 1, bool fetchChainIdFromNetworkId = false}) async {
    // first save private key
    _prvKey = cred;
    return _makeRPCCall<Map<String, dynamic>>('Send', [
      (await cred.extractAddress()).toString(),
      transaction.value!.getValueInUnit(EtherUnit.ether),
      transaction.to!.toString(),
      'LYR'
    ]).then((data) {
      _prvKey = null;
      // final bls =
      //     Map<String, double>.from(data['balance'] as Map<dynamic, dynamic>);
      return data;
    });
  }

  /// Sends a raw, signed transaction.
  ///
  /// To obtain a transaction in a signed form, use [signTransaction].
  ///
  /// Returns a hash of the transaction which, after the transaction has been
  /// included in a mined block, can be used to obtain detailed information
  /// about the transaction.
  Future<String> sendRawTransaction(Uint8List signedTransaction) async {
    return _makeRPCCall('eth_sendRawTransaction', [
      bytesToHex(signedTransaction, include0x: true, padToEvenLength: true)
    ]);
  }

  /// Signs the [transaction] with the credentials [cred]. The transaction will
  /// not be sent.
  ///
  /// See also:
  ///  - [bytesToHex], which can be used to get the more common hexadecimal
  /// representation of the transaction.
  Future<Uint8List> signTransaction(Credentials cred, Transaction transaction,
      {int? chainId = 1, bool fetchChainIdFromNetworkId = false}) async {
    final signingInput = await _fillMissingData(
      credentials: cred,
      transaction: transaction,
      chainId: chainId,
      loadChainIdFromNetwork: fetchChainIdFromNetworkId,
      client: this,
    );

    return _operations.signTransaction(signingInput);
  }

  /// Calls a [function] defined in the smart [contract] and returns it's
  /// result.
  ///
  /// The connected node must be able to calculate the result locally, which
  /// means that the call can't write any data to the blockchain. Doing that
  /// would require a transaction which can be sent via [sendTransaction].
  /// As no data will be written, you can use the [sender] to specify any
  /// Ethereum address that would call that function. To use the address of a
  /// credential, call [Credentials.extractAddress].
  ///
  /// This function allows specifying a custom block mined in the past to get
  /// historical data. By default, [BlockNum.current] will be used.
  Future<List<dynamic>> call({
    LyraAddress? sender,
    required DeployedContract contract,
    required ContractFunction function,
    required List<dynamic> params,
    BlockNum? atBlock,
  }) async {
    final encodedResult = await callRaw(
      sender: sender,
      contract: contract.address,
      data: function.encodeCall(params),
      atBlock: atBlock,
    );

    return function.decodeReturnValues(encodedResult);
  }

  /// Estimate the amount of gas that would be necessary if the transaction was
  /// sent via [sendTransaction]. Note that the estimate may be significantly
  /// higher than the amount of gas actually used by the transaction.
  Future<BigInt> estimateGas({
    LyraAddress? sender,
    LyraAddress? to,
    EtherAmount? value,
    BigInt? amountOfGas,
    EtherAmount? gasPrice,
    Uint8List? data,
    @Deprecated('Parameter is ignored') BlockNum? atBlock,
  }) async {
    final amountHex = await _makeRPCCall<String>(
      'eth_estimateGas',
      [
        {
          if (sender != null) 'from': sender.hex,
          if (to != null) 'to': to.hex,
          if (amountOfGas != null) 'gas': '0x${amountOfGas.toRadixString(16)}',
          if (gasPrice != null)
            'gasPrice': '0x${gasPrice.getInWei.toRadixString(16)}',
          if (value != null) 'value': '0x${value.getInWei.toRadixString(16)}',
          if (data != null) 'data': bytesToHex(data, include0x: true),
        },
      ],
    );
    return hexToInt(amountHex);
  }

  /// Sends a raw method call to a smart contract.
  ///
  /// The connected node must be able to calculate the result locally, which
  /// means that the call can't write any data to the blockchain. Doing that
  /// would require a transaction which can be sent via [sendTransaction].
  /// As no data will be written, you can use the [sender] to specify any
  /// Ethereum address that would call that function. To use the address of a
  /// credential, call [Credentials.extractAddress].
  ///
  /// This function allows specifying a custom block mined in the past to get
  /// historical data. By default, [BlockNum.current] will be used.
  ///
  /// See also:
  /// - [call], which automatically encodes function parameters and parses a
  /// response.
  Future<String> callRaw({
    LyraAddress? sender,
    required LyraAddress contract,
    required Uint8List data,
    BlockNum? atBlock,
  }) {
    final call = {
      'to': contract.hex,
      'data': bytesToHex(data, include0x: true, padToEvenLength: true),
      if (sender != null) 'from': sender.hex,
    };

    return _makeRPCCall<String>('eth_call', [call, _getBlockParam(atBlock)]);
  }

  /// Listens for new blocks that are added to the chain. The stream will emit
  /// the hexadecimal hash of the block after it has been added.
  ///
  /// {@template web3dart:filter_streams_behavior}
  /// The stream can only be listened to once. The subscription must be disposed
  /// properly when no longer used. Failing to do so causes a memory leak in
  /// your application and uses unnecessary resources on the connected node.
  /// {@endtemplate}
  /// See also:
  /// - [hexToBytes] and [hexToInt], which can transform hex strings into a byte
  /// or integer representation.
  // Stream<String> addedBlocks() {
  //   //return _filters.addFilter(_NewBlockFilter());
  //   return '';
  // }

  /// Listens for pending transactions as they are received by the connected
  /// node. The stream will emit the hexadecimal hash of the pending
  /// transaction.
  ///
  /// {@macro web3dart:filter_streams_behavior}
  /// See also:
  /// - [hexToBytes] and [hexToInt], which can transform hex strings into a byte
  /// or integer representation.
  // Stream<String> pendingTransactions() {
  //   return _filters.addFilter(_PendingTransactionsFilter());
  // }

  /// Listens for logs emitted from transactions. The [options] can be used to
  /// apply additional filters.
  ///
  /// {@macro web3dart:filter_streams_behavior}
  /// See also:
  /// - https://solidity.readthedocs.io/en/develop/contracts.html#events, which
  /// explains more about how events are encoded.
  // Stream<FilterEvent> events(FilterOptions options) {
  //   if (socketConnector != null) {
  //     // The real-time rpc nodes don't support listening to old data, so handle
  //     // that here.
  //     return Stream.fromFuture(getLogs(options))
  //         .expand((e) => e)
  //         .followedBy(_filters.addFilter(_EventFilter(options)));
  //   }

  //   return _filters.addFilter(_EventFilter(options));
  // }

  /// Closes resources managed by this client, such as the optional background
  /// isolate for calculations and managed streams.
  Future<void> dispose() async {
    // await _filters.dispose();
    // await _streamRpcPeer?.close();
  }
}

// datatypes
