// ADAPTED FROM: SciSymbioLens app_player.dart
// Changes: Removed video rendering, frame capture, player UI controls
//          Kept: Audio control methods (startVoice, stopVoice, setMute)
//
import 'dart:async';

import 'app_p2p_api.dart';

/// Simplified audio player for Veepa P2P SDK
///
/// This class wraps the P2P SDK's audio streaming functions.
/// Unlike the full app_player.dart, this only handles audio (no video).
class AudioPlayer {
  final AppP2PApi _api = AppP2PApi();

  /// Client pointer from P2P SDK (must be set after connection)
  int? _clientPtr;

  /// Whether audio is currently playing
  bool _isAudioPlaying = false;

  /// Whether audio is muted
  bool _isMuted = false;

  // Getters
  bool get isAudioPlaying => _isAudioPlaying;
  bool get isMuted => _isMuted;

  /// Set the client pointer (called after P2P connection established)
  void setClientPtr(int clientPtr) {
    _clientPtr = clientPtr;
    print('[AudioPlayer] Client pointer set: $clientPtr');
  }

  /// Start audio streaming
  ///
  /// This is where error -50 may occur if AVAudioSession not configured properly.
  /// Note: App_SetStartVoice() will be implemented in later sub-stories via platform channels
  Future<bool> startVoice() async {
    if (_clientPtr == null) {
      print('[AudioPlayer] ❌ Cannot start voice - no client pointer');
      return false;
    }

    if (_isAudioPlaying) {
      print('[AudioPlayer] Audio already playing');
      return true;
    }

    try {
      print('[AudioPlayer] Starting voice...');
      print('[AudioPlayer] Calling App_SetStartVoice(clientPtr: $_clientPtr)');

      // TODO: Implement App_SetStartVoice platform channel call in Story 2
      // final result = await _api.App_SetStartVoice(_clientPtr!);

      // For now, return success stub
      final result = 0;

      if (result == 0) {
        _isAudioPlaying = true;
        print('[AudioPlayer] ✅ Voice started successfully');
        return true;
      } else {
        print('[AudioPlayer] ❌ App_SetStartVoice failed with error: $result');
        return false;
      }
    } catch (e) {
      print('[AudioPlayer] ❌ Exception in startVoice: $e');
      return false;
    }
  }

  /// Stop audio streaming
  ///
  /// Note: App_SetStopVoice() will be implemented in later sub-stories via platform channels
  Future<bool> stopVoice() async {
    if (_clientPtr == null) {
      print('[AudioPlayer] ❌ Cannot stop voice - no client pointer');
      return false;
    }

    if (!_isAudioPlaying) {
      print('[AudioPlayer] Audio not playing');
      return true;
    }

    try {
      print('[AudioPlayer] Stopping voice...');
      print('[AudioPlayer] Calling App_SetStopVoice(clientPtr: $_clientPtr)');

      // TODO: Implement App_SetStopVoice platform channel call in Story 2
      // final result = await _api.App_SetStopVoice(_clientPtr!);

      // For now, return success stub
      final result = 0;

      if (result == 0) {
        _isAudioPlaying = false;
        print('[AudioPlayer] ✅ Voice stopped successfully');
        return true;
      } else {
        print('[AudioPlayer] ❌ App_SetStopVoice failed with error: $result');
        return false;
      }
    } catch (e) {
      print('[AudioPlayer] ❌ Exception in stopVoice: $e');
      return false;
    }
  }

  /// Set mute state
  ///
  /// Note: App_SetMute() will be implemented in later sub-stories via platform channels
  Future<bool> setMute(bool muted) async {
    if (_clientPtr == null) {
      print('[AudioPlayer] ❌ Cannot set mute - no client pointer');
      return false;
    }

    try {
      print('[AudioPlayer] Setting mute: $muted');
      print('[AudioPlayer] Calling App_SetMute(clientPtr: $_clientPtr, muted: ${muted ? 1 : 0})');

      // TODO: Implement App_SetMute platform channel call in Story 2
      // final result = await _api.App_SetMute(_clientPtr!, muted ? 1 : 0);

      // For now, return success stub
      final result = 0;

      if (result == 0) {
        _isMuted = muted;
        print('[AudioPlayer] ✅ Mute set to: $muted');
        return true;
      } else {
        print('[AudioPlayer] ❌ App_SetMute failed with error: $result');
        return false;
      }
    } catch (e) {
      print('[AudioPlayer] ❌ Exception in setMute: $e');
      return false;
    }
  }

  /// Cleanup (called when disconnecting)
  Future<void> dispose() async {
    if (_isAudioPlaying) {
      await stopVoice();
    }
    _clientPtr = null;
    print('[AudioPlayer] Disposed');
  }
}
