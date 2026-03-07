import 'package:flutter/material.dart';

import '../models/progression.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../widgets/progression_tile.dart';

class PlaybackScreen extends StatefulWidget {
  final String keyRoot;
  final String mode;
  final List<ChordEntry> progression;

  const PlaybackScreen({
    super.key,
    required this.keyRoot,
    required this.mode,
    required this.progression,
  });

  @override
  State<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends State<PlaybackScreen> {
  final AudioService _audio = AudioService.instance;
  final StorageService _storage = StorageService.instance;

  late List<ChordEntry> _progression;
  int _bpm = 120;
  bool _isPlaying = false;
  int _activeChordIndex = -1;
  bool _preparing = false;
  bool _metronomeOn = false;
  int _currentBeat = -1;

  @override
  void initState() {
    super.initState();
    _progression = List.of(widget.progression);
    _audio.metronomeEnabled = false;
  }

  @override
  void dispose() {
    _audio.stop();
    super.dispose();
  }

  // ── Playback controls ──

  Future<void> _play() async {
    if (_isPlaying || _progression.isEmpty) return;

    setState(() {
      _preparing = true;
    });

    // Pre-generate audio for all chords (may take a moment the first time)
    await _audio
        .prepareChords(_progression.map((e) => e.name).toList());

    setState(() {
      _preparing = false;
      _isPlaying = true;
    });

    _audio.onMeasureChange = (chordIdx, measureIdx) {
      if (mounted) {
        setState(() => _activeChordIndex = chordIdx);
      }
    };

    _audio.onBeat = (beat) {
      if (mounted) {
        setState(() => _currentBeat = beat);
      }
    };

    await _audio.play(_progression, _bpm);

    // When play completes (stopped externally)
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _activeChordIndex = -1;
      });
    }
  }

  void _stop() {
    _audio.stop();
    setState(() {
      _isPlaying = false;
      _activeChordIndex = -1;
      _currentBeat = -1;
    });
  }

  void _clear() {
    _stop();
    setState(() => _progression.clear());
  }

  // ── Save / Load ──

  Future<void> _showSaveDialog() async {
    final slots = await _storage.loadAll();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => _SaveLoadSheet(
        slots: slots,
        onSave: (slot) async {
          final prog = SavedProgression(
            keyRoot: widget.keyRoot,
            mode: widget.mode,
            chords: _progression,
            bpm: _bpm,
            slotName: 'Slot ${slot + 1}',
          );
          await _storage.save(slot, prog);
          if (mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Saved to Slot ${slot + 1}')),
            );
          }
        },
        onLoad: (slot) async {
          final prog = await _storage.load(slot);
          if (prog == null) return;
          _stop();
          setState(() {
            _progression
              ..clear()
              ..addAll(prog.chords);
            _bpm = prog.bpm;
          });
          if (mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Loaded from Slot ${slot + 1}')),
            );
          }
        },
        onDelete: (slot) async {
          await _storage.delete(slot);
          if (mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Slot ${slot + 1} cleared')),
            );
          }
        },
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.keyRoot} ${widget.mode} – Playback'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save / Load',
            onPressed: _showSaveDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Progression list ──
            Expanded(
              child: _progression.isEmpty
                  ? Center(
                      child: Text(
                        'No chords in progression.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: _progression.length,
                      itemBuilder: (context, index) {
                        return ProgressionTile(
                          key: ValueKey(
                              '${_progression[index].name}_$index'),
                          entry: _progression[index],
                          index: index,
                          isActive: index == _activeChordIndex,
                          onMeasuresChanged: (m) {
                            setState(() {
                              _progression[index] =
                                  _progression[index]
                                      .copyWith(measures: m);
                            });
                          },
                          onRemove: () {
                            setState(() {
                              _progression.removeAt(index);
                            });
                          },
                        );
                      },
                    ),
            ),

            // ── BPM Slider ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.speed, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'BPM',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Expanded(
                    child: Slider(
                      value: _bpm.toDouble(),
                      min: 60,
                      max: 180,
                      divisions: 120,
                      label: '$_bpm',
                      onChanged: _isPlaying
                          ? null
                          : (v) => setState(() => _bpm = v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '$_bpm',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Metronome toggle + beat indicator ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _metronomeOn
                          ? Icons.music_note
                          : Icons.music_off,
                      size: 22,
                    ),
                    tooltip: _metronomeOn
                        ? 'Metronome On'
                        : 'Metronome Off',
                    onPressed: () {
                      setState(() {
                        _metronomeOn = !_metronomeOn;
                        _audio.metronomeEnabled = _metronomeOn;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Metronome',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  // Beat indicator dots  1  2  3  4
                  // TODO: Uncomment later to show beat indicator
                  // ...List.generate(4, (i) {
                  //   final isActive = _isPlaying && _currentBeat == i;
                  //   return Padding(
                  //     padding: const EdgeInsets.symmetric(horizontal: 4),
                  //     child: AnimatedContainer(
                  //       duration: const Duration(milliseconds: 80),
                  //       width: isActive ? 20 : 14,
                  //       height: isActive ? 20 : 14,
                  //       decoration: BoxDecoration(
                  //         shape: BoxShape.circle,
                  //         color: isActive
                  //             ? (i == 0
                  //                 ? colorScheme.primary
                  //                 : colorScheme.tertiary)
                  //             : colorScheme.surfaceContainerHighest,
                  //         border: Border.all(
                  //           color: i == 0
                  //               ? colorScheme.primary
                  //               : colorScheme.tertiary,
                  //           width: 1.5,
                  //         ),
                  //       ),
                  //       child: Center(
                  //         child: Text(
                  //           '${i + 1}',
                  //           style: TextStyle(
                  //             fontSize: isActive ? 11 : 9,
                  //             fontWeight: FontWeight.bold,
                  //             color: isActive
                  //                 ? (i == 0
                  //                     ? colorScheme.onPrimary
                  //                     : colorScheme.onTertiary)
                  //                 : colorScheme.onSurfaceVariant,
                  //           ),
                  //         ),
                  //       ),
                  //     ),
                  //   );
                  // }),
                ],
              ),
            ),

            // ── Playback Buttons ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Row(
                children: [
                  // Clear
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed:
                          _isPlaying || _progression.isEmpty ? null : _clear,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Play / Stop
                  Expanded(
                    flex: 2,
                    child: _preparing
                        ? const Center(
                            child: SizedBox(
                              height: 50,
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          )
                        : FilledButton.icon(
                            icon: Icon(
                                _isPlaying ? Icons.stop : Icons.play_arrow),
                            label: Text(
                              _isPlaying ? 'Stop' : 'Play',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              backgroundColor: _isPlaying
                                  ? colorScheme.error
                                  : colorScheme.primary,
                              foregroundColor: _isPlaying
                                  ? colorScheme.onError
                                  : colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isPlaying ? _stop : _play,
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

// ──────────────────────────────────────────────────────────────────────────────
// Save / Load bottom sheet
// ──────────────────────────────────────────────────────────────────────────────

class _SaveLoadSheet extends StatelessWidget {
  final List<SavedProgression?> slots;
  final Future<void> Function(int slot) onSave;
  final Future<void> Function(int slot) onLoad;
  final Future<void> Function(int slot) onDelete;

  const _SaveLoadSheet({
    required this.slots,
    required this.onSave,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Save / Load Progression',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...List.generate(StorageService.maxSlots, (i) {
              final saved = slots[i];
              final isEmpty = saved == null;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    isEmpty ? 'Empty Slot' : saved.displayLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: isEmpty
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Save / Overwrite
                      IconButton(
                        icon: const Icon(Icons.save_alt),
                        tooltip: isEmpty ? 'Save here' : 'Overwrite',
                        onPressed: () => onSave(i),
                      ),
                      // Load
                      if (!isEmpty)
                        IconButton(
                          icon: const Icon(Icons.file_upload_outlined),
                          tooltip: 'Load',
                          onPressed: () => onLoad(i),
                        ),
                      // Delete
                      if (!isEmpty)
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: colorScheme.error),
                          tooltip: 'Delete',
                          onPressed: () => onDelete(i),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
