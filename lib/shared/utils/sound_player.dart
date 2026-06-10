import 'package:audioplayers/audioplayers.dart';

class SoundPlayer {
  static final SoundPlayer _instance = SoundPlayer._();
  static SoundPlayer get instance => _instance;
  SoundPlayer._();

  Future<void> playScan() => _play('sounds/scan.mp3');
  Future<void> playSuccess() => _play('sounds/success.mp3');
  Future<void> playError() => _play('sounds/error.mp3');

  Future<void> _play(String assetPath) async {
    try {
      await AudioPlayer().play(AssetSource(assetPath));
    } catch (_) {}
  }
}
