import 'dart:convert';

/// Represents a single chord in a progression with its measure count.
class ChordEntry {
  final String name;
  int measures;

  ChordEntry({required this.name, this.measures = 1});

  Map<String, dynamic> toJson() => {
        'name': name,
        'measures': measures,
      };

  factory ChordEntry.fromJson(Map<String, dynamic> json) => ChordEntry(
        name: json['name'] as String,
        measures: json['measures'] as int,
      );

  ChordEntry copyWith({String? name, int? measures}) => ChordEntry(
        name: name ?? this.name,
        measures: measures ?? this.measures,
      );
}

/// A complete saved progression with all settings.
class SavedProgression {
  final String keyRoot;
  final String mode; // 'Major' or 'Minor'
  final List<ChordEntry> chords;
  final int bpm;
  final String slotName;

  SavedProgression({
    required this.keyRoot,
    required this.mode,
    required this.chords,
    required this.bpm,
    this.slotName = '',
  });

  Map<String, dynamic> toJson() => {
        'keyRoot': keyRoot,
        'mode': mode,
        'chords': chords.map((c) => c.toJson()).toList(),
        'bpm': bpm,
        'slotName': slotName,
      };

  factory SavedProgression.fromJson(Map<String, dynamic> json) =>
      SavedProgression(
        keyRoot: json['keyRoot'] as String,
        mode: json['mode'] as String,
        chords: (json['chords'] as List)
            .map((c) => ChordEntry.fromJson(c as Map<String, dynamic>))
            .toList(),
        bpm: json['bpm'] as int,
        slotName: json['slotName'] as String? ?? '',
      );

  String toJsonString() => jsonEncode(toJson());

  factory SavedProgression.fromJsonString(String s) =>
      SavedProgression.fromJson(jsonDecode(s) as Map<String, dynamic>);

  String get displayLabel {
    final chordNames = chords.map((c) => c.name).join(' → ');
    return '$keyRoot $mode | $chordNames | ${bpm} BPM';
  }
}
