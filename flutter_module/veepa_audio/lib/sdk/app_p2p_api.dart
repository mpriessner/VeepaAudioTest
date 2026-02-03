import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:async';

/// P2P connection state enum
enum ClientConnectState {
  CONNECT_STATUS_INVALID_CLIENT,
  /* client is no create*/
  CONNECT_STATUS_CONNECTING,
  /* connecting */
  CONNECT_STATUS_INITIALING,
  /* initialing */
  CONNECT_STATUS_ONLINE,
  /* on line */
  CONNECT_STATUS_CONNECT_FAILED,
  /* connect failed */
  CONNECT_STATUS_DISCONNECT,
  /*connect is off*/
  CONNECT_STATUS_INVALID_ID,
  /* invalid id */
  CONNECT_STATUS_OFFLINE,
  /* off line */
  CONNECT_STATUS_CONNECT_TIMEOUT,
  /* connect timeout */
  CONNECT_STATUS_MAX_SESSION,
  /* connect max session */
  CONNECT_STATUS_MAX,
  /*connect is -12*/
  CONNECT_STATUS_REMOVE_CLOSE
}

/// P2P connection mode
enum ClientConnectMode {
  CONNECT_MODE_NONE, // Unknown mode
  CONNECT_MODE_P2P, // Direct P2P tunnel
  CONNECT_MODE_RELAY, // Cloud relay
  CONNECT_MODE_SOCK // Socket mode
}

/// Channel types for P2P communication
class ClientChannelType {
  // Command channel
  static ClientChannelType P2P_CMD_CHANNEL = ClientChannelType(0);

  // Video channel
  static ClientChannelType P2P_VIDEO_CHANNEL = ClientChannelType(1);

  // Audio receive channel
  static ClientChannelType P2P_AUDIO_CHANNEL = ClientChannelType(2);

  // Audio send channel
  static ClientChannelType P2P_TALKCHANNEL = ClientChannelType(3);

  // Playback channel
  static ClientChannelType P2P_PLAYBACK = ClientChannelType(4);

  // Alarm channel
  static ClientChannelType P2P_SENSORALARM = ClientChannelType(5);

  // Socket command channel
  static ClientChannelType SOCK_CMD_CHANNEL = ClientChannelType(0);

  // Socket media channel
  static ClientChannelType SOCK_MEDIA_CHANNEL = ClientChannelType(1);

  // Socket data channel
  static ClientChannelType SOCK_DATA_CHANNEL = ClientChannelType(2);

  ClientChannelType(this.index);

  final int index;
}

class ClientCheckBufferResult {
  ClientCheckBufferResult(this.result, this.writeLen, this.readLen);

  /// 0 – P2P_SUCCESSFUL
  /// -5 - P2P_INVALID_PARAMETER
  /// -1 – P2P_NOT_INITIALIZED
  /// -11 – P2P_INVALIED_SESSION_HANDLE
  /// -12 – P2P_SESSION_CLOSED_REMOTE
  /// -13 – P2P_SESSION_CLOSED_TIMEOUT
  int result;
  int writeLen;
  int readLen;
}

class ClientCheckModeResult {
  ClientCheckModeResult(this.result, this.mode);

  bool result;
  ClientConnectMode mode;
}

class ClientReadResult {
  ClientReadResult(this.result, this.buffer);

  /// > 0 Read success, return value is read length
  /// -1 Client not connected
  /// -3 Receive timeout
  /// -5 Invalid parameter
  /// -11 Connection invalid
  /// -12 Remote closed connection
  /// -13 Connection timeout closed
  int result;

  Uint8List buffer;
}

class ClientCommandResult {
  late int cmd;
  late Uint8List data;
}

typedef void ConnectListener(ClientConnectState state);
typedef void CommandListener(int cmd, Uint8List data);

/// P2P API for Veepa camera connection
///
/// This class provides the interface to the native P2P SDK via platform channels.
/// Based on VeepaCameraPOC: sdk/app_p2p_api.dart
class AppP2PApi {
  /// Singleton instance
  static AppP2PApi? _instance;

  /// Track if streams are initialized
  bool _streamsInitialized = false;

  /// Stream subscriptions for cleanup
  StreamSubscription? _connectSubscription;
  StreamSubscription? _commandSubscription;

  /// Singleton constructor
  factory AppP2PApi() => getInstance();

  /// Get singleton instance
  static AppP2PApi getInstance() {
    if (_instance == null) {
      _instance = AppP2PApi._internal();
    }
    return _instance!;
  }

  /// Reset the singleton instance (call when app restarts or on fatal errors)
  static void resetInstance() {
    if (_instance != null) {
      _instance!._cleanup();
      _instance = null;
    }
    print('AppP2PApi: Instance reset');
  }

  /// Cleanup internal state
  void _cleanup() {
    _connectSubscription?.cancel();
    _commandSubscription?.cancel();
    _connectSubscription = null;
    _commandSubscription = null;
    _connectListeners.clear();
    _commandListeners.clear();
    _streamsInitialized = false;
  }

  bool _isNullOrZero(int value) {
    return value == 0;
  }

  late MethodChannel _channel;
  late EventChannel _connectChannel;
  late EventChannel _commandChannel;
  Stream? _connectStream;
  Stream? _commandStream;
  HashMap<int, ConnectListener> _connectListeners = HashMap();
  HashMap<int, CommandListener> _commandListeners = HashMap();

  AppP2PApi._internal() {
    _channel = MethodChannel("app_p2p_api_channel");
    _connectChannel = EventChannel("app_p2p_api_event_channel/connect");
    _commandChannel = EventChannel("app_p2p_api_event_channel/command");
    _initStreams();
  }

  void _initStreams() {
    if (_streamsInitialized) {
      print('AppP2PApi: Streams already initialized, skipping');
      return;
    }

    try {
      _connectStream = _connectChannel.receiveBroadcastStream("connect");
      _commandStream = _commandChannel.receiveBroadcastStream("command");
      _connectSubscription = _connectStream?.listen(
        _onConnectListener,
        onError: (error) {
          print('AppP2PApi: Connect stream error: $error');
          _streamsInitialized = false;
        },
        cancelOnError: false,
      );
      _commandSubscription = _commandStream?.listen(
        _onCommandListener,
        onError: (error) {
          print('AppP2PApi: Command stream error: $error');
          _streamsInitialized = false;
        },
        cancelOnError: false,
      );
      _streamsInitialized = true;
      print('AppP2PApi: Streams initialized successfully');
    } catch (e) {
      print('AppP2PApi: Failed to initialize streams: $e');
      _streamsInitialized = false;
    }
  }

  /// Reinitialize streams if they failed
  void ensureStreamsInitialized() {
    if (!_streamsInitialized) {
      print('AppP2PApi: Reinitializing streams...');
      _initStreams();
    }
  }

  void _onConnectListener(dynamic data) {
    try {
      if (data == null || data is! List || data.length < 2) {
        print('AppP2PApi: Invalid connect data: $data');
        return;
      }
      int clientPtr = data[0];
      int state = data[1];
      if (state < 0 || state >= ClientConnectState.values.length) {
        print('AppP2PApi: Invalid connect state: $state');
        return;
      }
      var listener = _connectListeners[clientPtr];
      if (listener != null) {
        listener(ClientConnectState.values[state]);
      }
    } catch (e) {
      print('AppP2PApi: Error in connect listener: $e');
    }
  }

  void _onCommandListener(dynamic data) {
    try {
      if (data == null || data is! List || data.length < 3) {
        print('AppP2PApi: Invalid command data: $data');
        return;
      }
      int clientPtr = data[0];
      int cmd = data[1];
      Uint8List buffer = data[2];
      var list = Uint8List.fromList(buffer.toList());
      var listener = _commandListeners[clientPtr];
      if (listener != null) {
        listener(cmd, list);
      }
    } catch (e) {
      print('AppP2PApi: Error in command listener: $e');
    }
  }

  /// Add connection state listener
  void setConnectListener(int clientPtr, ConnectListener listener) {
    if (_isNullOrZero(clientPtr)) return;
    _connectListeners[clientPtr] = listener;
  }

  /// Add device command listener
  void setCommandListener(int clientPtr, CommandListener listener) {
    if (_isNullOrZero(clientPtr)) return;
    _commandListeners[clientPtr] = listener;
  }

  /// Remove connection state listener
  void removeConnectListener(int clientPtr) {
    if (_isNullOrZero(clientPtr)) return;
    _connectListeners.remove(clientPtr);
  }

  /// Remove device command listener
  void removeCommandListener(int clientPtr) {
    if (_isNullOrZero(clientPtr)) return;
    _commandListeners.remove(clientPtr);
  }

  /// Create P2P client
  /// @param [did] Device ID (the REAL clientId from cloud, not virtual UID)
  /// @return Client pointer (handle)
  Future<int?> clientCreate(String? did, {String? did2}) async {
    if (did == null) return 0;
    var result = await _channel.invokeMethod<int>("client_create", [did, did2]);
    return result;
  }

  /// Change P2P client ID
  /// @param [did] Device ID
  /// @return Success
  Future<bool> clientChangeId(int clientPtr, String did) async {
    if (_isNullOrZero(clientPtr)) return false;
    var result =
        await _channel.invokeMethod<bool>("client_change_id", [clientPtr, did]);
    return result ?? false;
  }

  /// Connect client
  /// @param [clientPtr] Client pointer
  /// @param [lanScan] Whether to scan local network
  /// @param [serverParam] Server connection parameter (serviceParam from cloud)
  /// @param [connectType] 63 = LAN Direct, 126 = Cloud Relay
  /// @return Connection state
  Future<ClientConnectState> clientConnect(
      int clientPtr, bool lanScan, String serverParam,
      {required int connectType, int p2pType = 0}) async {
    if (_isNullOrZero(clientPtr))
      return ClientConnectState.CONNECT_STATUS_INVALID_CLIENT;
    int? result = await _channel.invokeMethod<int>("client_connect",
        [clientPtr, lanScan, serverParam, connectType, p2pType]);
    return ClientConnectState.values[result ?? 0];
  }

  /// Check client connection timeout
  Future<int> clientCheckTimeout(
      int clientPtr, bool lanScan, String? serverParam,
      {required int connectType}) async {
    if (_isNullOrZero(clientPtr)) return 0;
    int? result = await _channel.invokeMethod<int>(
        "client_connect", [clientPtr, lanScan, serverParam, connectType]);
    return result ?? 0;
  }

  /// Check client connection mode
  /// @return [ClientCheckModeResult]
  Future<ClientCheckModeResult> clientCheckMode(int clientPtr) async {
    if (_isNullOrZero(clientPtr))
      return ClientCheckModeResult(false, ClientConnectMode.CONNECT_MODE_NONE);
    List result = await _channel.invokeMethod("client_check_mode", [clientPtr]);
    return ClientCheckModeResult(
        result[0], ClientConnectMode.values[result[1]]);
  }

  /// Check client buffer
  Future<ClientCheckBufferResult> clientCheckBuffer(
      int clientPtr, ClientChannelType channelType) async {
    if (_isNullOrZero(clientPtr))
      return ClientCheckBufferResult(-5, 0, 0);
    List result = await _channel
        .invokeMethod("client_check_buffer", [clientPtr, channelType.index]);

    return ClientCheckBufferResult(result[0], result[1], result[2]);
  }

  /// User login
  /// @param [clientPtr] Client pointer
  /// @param [username] Username (usually "admin")
  /// @param [password] User password
  /// @return true if successful
  Future<bool> clientLogin(
      int clientPtr, String username, String password) async {
    if (_isNullOrZero(clientPtr) ||
        username.isEmpty) {
      return false;
    }
    var result = await _channel
        .invokeMethod("client_login", [clientPtr, username, password]);
    return result;
  }

  /// Send CGI command
  /// @param [clientPtr] Client pointer
  /// @param [cgi] CGI command string (e.g., "livestream.cgi?streamid=10&substream=4&")
  /// @param [timeout] Timeout in seconds
  /// @return true if successful
  Future<bool> clientWriteCgi(int clientPtr, String cgi,
      {int timeout = 5}) async {
    if (_isNullOrZero(clientPtr) || cgi.isEmpty)
      return false;
    var result = await _channel
        .invokeMethod("client_write_cig", [clientPtr, cgi, timeout]);
    return result;
  }

  /// Send buffer
  Future<int> clientWrite(int clientPtr, ClientChannelType channelType,
      Uint8List buffer, int timeout) async {
    if (_isNullOrZero(clientPtr))
      return -5;
    var result = await _channel.invokeMethod(
        "client_write", [clientPtr, channelType.index, buffer, timeout]);
    return result;
  }

  /// Disconnect P2P client
  Future<bool> clientDisconnect(int clientPtr) async {
    if (_isNullOrZero(clientPtr)) return false;
    var result = await _channel.invokeMethod("client_disconnect", [clientPtr]);
    return result;
  }

  /// Destroy P2P client
  Future<void> clientDestroy(int clientPtr) async {
    if (_isNullOrZero(clientPtr)) return;
    _connectListeners.remove(clientPtr);
    _commandListeners.remove(clientPtr);
    await _channel.invokeMethod("client_destroy", [clientPtr]);
    return;
  }

  /// Break P2P client connection
  Future<void> clientConnectBreak(int clientPtr) async {
    if (_isNullOrZero(clientPtr)) return;
    await _channel.invokeMethod("client_connect_break", [clientPtr]);
    return;
  }
}
