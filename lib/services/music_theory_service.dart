/// Music theory utility for generating diatonic chords and progressions.
class MusicTheoryService {
  MusicTheoryService._();

  static const List<String> noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  // Semitone intervals from root for each scale degree
  static const List<int> majorScaleIntervals = [0, 2, 4, 5, 7, 9, 11];
  static const List<int> minorScaleIntervals = [0, 2, 3, 5, 7, 8, 10];

  // Chord quality for each scale degree
  // 0 = Major, 1 = minor, 2 = diminished
  static const List<int> majorChordQualities = [0, 1, 1, 0, 0, 1, 2];
  static const List<int> minorChordQualities = [1, 2, 0, 1, 1, 0, 0];

  static const List<String> majorRomanNumerals = [
    'I', 'ii', 'iii', 'IV', 'V', 'vi', 'vii°',
  ];
  static const List<String> minorRomanNumerals = [
    'i', 'ii°', 'III', 'iv', 'v', 'VI', 'VII',
  ];

  /// Common preset progressions as Roman numeral lists.
  static const Map<String, List<String>> presetProgressions = {
    'I  V  vi  IV': ['I', 'V', 'vi', 'IV'],
    'I  IV  V': ['I', 'IV', 'V'],
    'ii  V  I': ['ii', 'V', 'I'],
    'vi  IV  I  V': ['vi', 'IV', 'I', 'V'],
  };

  /// Returns the index of a note name in the chromatic scale.
  static int noteIndex(String note) => noteNames.indexOf(note);

  /// Gets the note name at a given chromatic index (wraps around).
  static String noteAt(int index) => noteNames[index % 12];

  /// Generates the 7 diatonic chord names for a given key root and mode.
  static List<String> getDiatonicChords(String root, String mode) {
    final rootIdx = noteIndex(root);
    final intervals =
        mode == 'Major' ? majorScaleIntervals : minorScaleIntervals;
    final qualities =
        mode == 'Major' ? majorChordQualities : minorChordQualities;

    final chords = <String>[];
    for (int i = 0; i < 7; i++) {
      final noteName = noteAt(rootIdx + intervals[i]);
      final suffix = _qualitySuffix(qualities[i]);
      chords.add('$noteName$suffix');
    }
    return chords;
  }

  /// Returns the Roman numeral labels for the given mode.
  static List<String> getRomanNumerals(String mode) =>
      mode == 'Major' ? majorRomanNumerals : minorRomanNumerals;

  /// Converts a Roman numeral (e.g. 'vi') to an actual chord name in the
  /// given key.  Returns null if the numeral is not recognized.
  static String? romanNumeralToChord(
      String roman, String root, String mode) {
    final numerals = getRomanNumerals(mode);
    final idx = numerals.indexOf(roman);
    if (idx == -1) return null;
    final chords = getDiatonicChords(root, mode);
    return chords[idx];
  }

  /// Converts a list of Roman numerals into chord names.
  static List<String> romanNumeralsToChords(
      List<String> romans, String root, String mode) {
    return romans
        .map((r) => romanNumeralToChord(r, root, mode))
        .where((c) => c != null)
        .cast<String>()
        .toList();
  }

  /// Parses a chord name into (rootNote, quality).
  /// quality: 'major', 'minor', or 'dim'
  static ({String rootNote, String quality}) parseChord(String chord) {
    if (chord.endsWith('dim')) {
      return (rootNote: chord.substring(0, chord.length - 3), quality: 'dim');
    } else if (chord.endsWith('m')) {
      return (
        rootNote: chord.substring(0, chord.length - 1),
        quality: 'minor'
      );
    } else {
      return (rootNote: chord, quality: 'major');
    }
  }

  /// Returns the semitone offsets for the chord tones relative to root.
  static List<int> chordIntervals(String quality) {
    switch (quality) {
      case 'major':
        return [0, 4, 7]; // root, major 3rd, perfect 5th
      case 'minor':
        return [0, 3, 7]; // root, minor 3rd, perfect 5th
      case 'dim':
        return [0, 3, 6]; // root, minor 3rd, diminished 5th
      default:
        return [0, 4, 7];
    }
  }

  static String _qualitySuffix(int quality) {
    switch (quality) {
      case 1:
        return 'm';
      case 2:
        return 'dim';
      default:
        return '';
    }
  }
}
