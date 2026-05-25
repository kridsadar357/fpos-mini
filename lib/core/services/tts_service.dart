import 'package:flutter_tts/flutter_tts.dart';
import '../../data/repositories/settings_repository.dart';

/// Text-to-Speech service. Used everywhere the UI needs audible feedback
/// (amount entered, change to give, errors). Replaces keyboard popups with
/// spoken confirmations — a commercial accessibility win.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _enabled = true;
  String _language = 'en-US';

  Future<void> init() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);

      final repo = SettingsRepository();
      _enabled = (await repo.get('tts_enabled', defaultValue: 'true')) == 'true';
      _language = await repo.get('tts_language', defaultValue: 'th-TH');
      await _tts.setLanguage(_language);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> reload() async {
    final repo = SettingsRepository();
    _enabled = (await repo.get('tts_enabled', defaultValue: 'true')) == 'true';
    _language = await repo.get('tts_language', defaultValue: 'en-US');
    try {
      await _tts.setLanguage(_language);
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    if (!_ready || !_enabled || text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> announceDigit(String digit) async {
    if (!_enabled) return;
    speak(digit);
  }

  Future<void> announceAmount(double amount, {String? prefix}) async {
    final money = amount.toStringAsFixed(2);
    speak('${prefix ?? ''} $money');
  }

  Future<void> stop() async => _tts.stop();

  bool get isEnabled => _enabled;
  String get language => _language;
}
