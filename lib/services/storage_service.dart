import 'package:shared_preferences/shared_preferences.dart';

import '../models/progression.dart';

/// Manages saving and loading up to 3 chord progressions via SharedPreferences.
class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  static const int maxSlots = 3;
  static const String _prefix = 'saved_progression_';

  /// Save a progression to the given slot (0-based, 0..2).
  Future<void> save(int slot, SavedProgression progression) async {
    assert(slot >= 0 && slot < maxSlots);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$slot', progression.toJsonString());
  }

  /// Load a progression from a slot.  Returns null if slot is empty.
  Future<SavedProgression?> load(int slot) async {
    assert(slot >= 0 && slot < maxSlots);
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('$_prefix$slot');
    if (json == null || json.isEmpty) return null;
    try {
      return SavedProgression.fromJsonString(json);
    } catch (_) {
      return null;
    }
  }

  /// Returns a list of length [maxSlots].  Each entry is the saved progression
  /// or null for an empty slot.
  Future<List<SavedProgression?>> loadAll() async {
    final result = <SavedProgression?>[];
    for (int i = 0; i < maxSlots; i++) {
      result.add(await load(i));
    }
    return result;
  }

  /// Delete a saved progression in a slot.
  Future<void> delete(int slot) async {
    assert(slot >= 0 && slot < maxSlots);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$slot');
  }
}
