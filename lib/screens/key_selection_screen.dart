import 'package:flutter/material.dart';

import '../models/progression.dart';
import '../services/music_theory_service.dart';
import 'progression_builder_screen.dart';

class KeySelectionScreen extends StatefulWidget {
  const KeySelectionScreen({super.key});

  @override
  State<KeySelectionScreen> createState() => _KeySelectionScreenState();
}

class _KeySelectionScreenState extends State<KeySelectionScreen> {
  String _selectedRoot = 'C';
  String _selectedMode = 'Major';
  String? _selectedPreset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progression Session'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Key Root ──
              Text(
                'Key Root',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MusicTheoryService.noteNames.map((note) {
                  final selected = note == _selectedRoot;
                  return ChoiceChip(
                    label: Text(note),
                    selected: selected,
                    selectedColor: colorScheme.primary,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                    onSelected: (_) =>
                        setState(() => _selectedRoot = note),
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              // ── Mode ──
              Text('Mode', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Major', label: Text('Major')),
                  ButtonSegment(value: 'Minor', label: Text('Minor')),
                ],
                selected: {_selectedMode},
                onSelectionChanged: (v) =>
                    setState(() => _selectedMode = v.first),
              ),

              const SizedBox(height: 28),

              // ── Presets ──
              Text(
                'Preset Progressions (optional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // "None" option
                  ChoiceChip(
                    label: const Text('None'),
                    selected: _selectedPreset == null,
                    selectedColor: colorScheme.primary,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _selectedPreset == null
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                    onSelected: (_) =>
                        setState(() => _selectedPreset = null),
                  ),
                  ...MusicTheoryService.presetProgressions.keys.map((key) {
                    final selected = _selectedPreset == key;
                    return ChoiceChip(
                      label: Text(key),
                      selected: selected,
                      selectedColor: colorScheme.primary,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedPreset = key),
                    );
                  }),
                ],
              ),

              const SizedBox(height: 36),

              // ── Generate ──
              FilledButton.icon(
                icon: const Icon(Icons.music_note),
                label: const Text(
                  'Generate Chords',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _onGenerate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onGenerate() {
    // Build initial chord entries from preset if one is selected.
    List<ChordEntry>? presetChords;
    if (_selectedPreset != null) {
      final romans =
          MusicTheoryService.presetProgressions[_selectedPreset]!;
      final chordNames = MusicTheoryService.romanNumeralsToChords(
          romans, _selectedRoot, _selectedMode);
      presetChords = chordNames.map((n) => ChordEntry(name: n)).toList();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProgressionBuilderScreen(
          keyRoot: _selectedRoot,
          mode: _selectedMode,
          initialChords: presetChords,
        ),
      ),
    );
  }
}
