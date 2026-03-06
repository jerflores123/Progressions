import 'package:flutter/material.dart';

import '../models/progression.dart';
import '../services/music_theory_service.dart';
import '../widgets/chord_button.dart';
import '../widgets/progression_tile.dart';
import 'playback_screen.dart';

class ProgressionBuilderScreen extends StatefulWidget {
  final String keyRoot;
  final String mode;
  final List<ChordEntry>? initialChords;

  const ProgressionBuilderScreen({
    super.key,
    required this.keyRoot,
    required this.mode,
    this.initialChords,
  });

  @override
  State<ProgressionBuilderScreen> createState() =>
      _ProgressionBuilderScreenState();
}

class _ProgressionBuilderScreenState extends State<ProgressionBuilderScreen> {
  late List<String> _diatonicChords;
  late List<String> _romanNumerals;
  late List<ChordEntry> _progression;

  @override
  void initState() {
    super.initState();
    _diatonicChords =
        MusicTheoryService.getDiatonicChords(widget.keyRoot, widget.mode);
    _romanNumerals = MusicTheoryService.getRomanNumerals(widget.mode);
    _progression = widget.initialChords != null
        ? List.of(widget.initialChords!)
        : [];
  }

  void _addChord(String chord) {
    setState(() {
      _progression.add(ChordEntry(name: chord));
    });
  }

  void _removeChord(int index) {
    setState(() {
      _progression.removeAt(index);
    });
  }

  void _updateMeasures(int index, int measures) {
    setState(() {
      _progression[index] =
          _progression[index].copyWith(measures: measures);
    });
  }

  void _goToPlayback() {
    if (_progression.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one chord.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaybackScreen(
          keyRoot: widget.keyRoot,
          mode: widget.mode,
          progression: List.of(_progression),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.keyRoot} ${widget.mode}'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Available chords ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: colorScheme.surfaceContainerLow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Chords',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(_diatonicChords.length, (i) {
                      return ChordButton(
                        label: _diatonicChords[i],
                        romanNumeral: _romanNumerals[i],
                        onTap: () => _addChord(_diatonicChords[i]),
                      );
                    }),
                  ),
                ],
              ),
            ),

            // ── Progression list ──
            Expanded(
              child: _progression.isEmpty
                  ? Center(
                      child: Text(
                        'Tap a chord above to add it\nto your progression.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      buildDefaultDragHandles: false,
                      itemCount: _progression.length,
                      onReorder: (oldIdx, newIdx) {
                        setState(() {
                          if (newIdx > oldIdx) newIdx--;
                          final item = _progression.removeAt(oldIdx);
                          _progression.insert(newIdx, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        return ProgressionTile(
                          key: ValueKey('${_progression[index].name}_$index'),
                          entry: _progression[index],
                          index: index,
                          showDragHandle: true,
                          onMeasuresChanged: (m) =>
                              _updateMeasures(index, m),
                          onRemove: () => _removeChord(index),
                        );
                      },
                    ),
            ),

            // ── Bottom bar ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _progression.isEmpty
                          ? null
                          : () => setState(() => _progression.clear()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text(
                        'Continue to Playback',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _goToPlayback,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
