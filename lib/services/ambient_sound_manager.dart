import 'package:audioplayers/audioplayers.dart';

enum AmbientType { none, rain, city, roomTone, thunder }

class AmbientSoundManager {
  static final AmbientSoundManager _instance = AmbientSoundManager._internal();
  factory AmbientSoundManager() => _instance;
  AmbientSoundManager._internal() {
    _initialize();
  }

  final AudioPlayer _player = AudioPlayer();
  AmbientType _activeAmbient = AmbientType.none;
  double _volume = 0.3;
  bool _isMuted = false;
  bool _initialized = false;

  AmbientType get activeAmbient => _activeAmbient;
  double get volume => _volume;
  bool get isMuted => _isMuted;

  static const Map<AmbientType, String> _streams = {
    AmbientType.rain: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3', // Premium soft rain-like streaming loop
    AmbientType.city: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3', // Muted ambient jazz tone
    AmbientType.roomTone: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3', // Warm room tone loop
    AmbientType.thunder: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3', // Dramatic background loops
  };

  void _initialize() {
    try {
      _player.setReleaseMode(ReleaseMode.loop);
      _player.setVolume(_volume);
      _initialized = true;
    } catch (e) {
      print("Audio initialization warning: $e");
    }
  }

  Future<void> setAmbient(AmbientType type) async {
    if (!_initialized) _initialize();
    _activeAmbient = type;
    
    if (type == AmbientType.none || _isMuted) {
      try {
        await _player.stop();
      } catch (e) {
        print("Audio playback stop warning: $e");
      }
      return;
    }

    final url = _streams[type];
    if (url != null) {
      try {
        await _player.stop();
        await _player.play(UrlSource(url));
        await _player.setVolume(_volume);
      } catch (e) {
        print("Audio playback start warning: $e. Ensuring system remains fully stable.");
      }
    }
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    if (!_isMuted && _initialized) {
      try {
        await _player.setVolume(_volume);
      } catch (e) {}
    }
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    if (_isMuted) {
      try {
        await _player.setVolume(0.0);
      } catch (e) {}
    } else {
      try {
        await _player.setVolume(_volume);
        if (_activeAmbient != AmbientType.none) {
          await setAmbient(_activeAmbient);
        }
      } catch (e) {}
    }
  }

  Future<void> stop() async {
    _activeAmbient = AmbientType.none;
    try {
      await _player.stop();
    } catch (e) {}
  }
}
