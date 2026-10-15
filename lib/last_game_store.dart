import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LastGameStore {
  static const _key = 'sudoku_last_game_v1';
  static const _elapsedKey = 'sudoku_last_game_elapsed_seconds_v1';

  Future<Map<String, dynamic>?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null) return null;
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic> ||
        decoded['seed'] is! int ||
        decoded['difficulty'] is! String ||
        decoded['board'] is! List ||
        decoded['notes'] is! List ||
        decoded['elapsedSeconds'] is! int ||
        decoded['undoHistory'] is! List) {
      throw const FormatException('Invalid saved game.');
    }
    final elapsed = preferences.getInt(_elapsedKey);
    if (elapsed != null && elapsed > (decoded['elapsedSeconds'] as int)) {
      decoded['elapsedSeconds'] = elapsed;
    }
    return decoded;
  }

  Future<void> save(Map<String, Object> progress) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_key, jsonEncode(progress));
    if (!saved) throw StateError('Could not save the current game.');
    final elapsedSaved = await preferences.setInt(
      _elapsedKey,
      progress['elapsedSeconds'] as int,
    );
    if (!elapsedSaved) throw StateError('Could not save the game timer.');
  }

  Future<void> saveElapsedSeconds(int seconds) async {
    if (seconds < 0) {
      throw ArgumentError.value(seconds, 'seconds', 'Must not be negative.');
    }
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setInt(_elapsedKey, seconds);
    if (!saved) throw StateError('Could not save the game timer.');
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
    await preferences.remove(_elapsedKey);
  }
}
