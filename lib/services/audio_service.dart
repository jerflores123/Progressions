import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';

// dart:io is not available on web – guard the import.
import 'audio_service_io.dart' if (dart.library.html) 'audio_service_web.dart'
    as platform_io;

import '../models/progression.dart';
import 'music_theory_service.dart';

/// Generates chord WAV files on the fly and manages playback of progressions.
class AudioService {
  AudioService._internal();
  static final AudioService instance = AudioService._internal();

  // One AudioPlayer per unique chord name – reused across plays.
  final Map<String, AudioPlayer> _players = {};

  // Cache directory where generated WAV files live (native only).
  String? _cacheDir;

  // In-memory WAV cache for web.
  final Map<String, Uint8List> _wavCache = {};

  bool _playing = false;
  bool get isPlaying => _playing;

  // Metronome click
  bool _metronomeEnabled = false;
  bool get metronomeEnabled => _metronomeEnabled;
  set metronomeEnabled(bool v) => _metronomeEnabled = v;

  // Pool of click players to avoid re-loading on web.
  static const int _clickPoolSize = 4;
  final List<AudioPlayer> _clickPool = [];
  int _clickPoolIdx = 0;
  String? _clickSource;

  // Callback invoked when the currently-sounding chord changes (index into
  // the expanded measure list).
  void Function(int chordIndex, int measureIndex)? onMeasureChange;

  // Callback invoked on every beat (0-3) for UI beat indicator.
  void Function(int beat)? onBeat;

  /// Initialise the cache directory.  Call once at app start.
  Future<void> init() async {
    if (!kIsWeb) {
      _cacheDir = await platform_io.initCacheDir();
    }
    await _prepareClick();
  }

  // ---------------------------------------------------------------
  // WAV generation
  // ---------------------------------------------------------------

  static const int _sampleRate = 44100;

  /// Base frequencies for octave 3 (C3–B3).
  static const List<double> _baseFreqs = [
    130.81, // C3
    138.59, // C#3
    146.83, // D3
    155.56, // D#3
    164.81, // E3
    174.61, // F3
    185.00, // F#3
    196.00, // G3
    207.65, // G#3
    220.00, // A3
    233.08, // A#3
    246.94, // B3
  ];

  /// Returns the frequency of a note at a given octave offset from octave 3.
  static double _freq(int noteIndex, int octaveOffset) =>
      _baseFreqs[noteIndex % 12] * pow(2, octaveOffset).toDouble();

  /// Build the list of frequencies for a chord (guitar-like voicing).
  static List<double> _chordFrequencies(String chordName) {
    final parsed = MusicTheoryService.parseChord(chordName);
    final rootIdx = MusicTheoryService.noteIndex(parsed.rootNote);
    final intervals = MusicTheoryService.chordIntervals(parsed.quality);

    // Voicing: root oct3, then root/3rd/5th at oct4
    return [
      _freq(rootIdx + intervals[0], 0), // root oct3
      _freq(rootIdx + intervals[0], 1), // root oct4
      _freq(rootIdx + intervals[1], 1), // 3rd oct4
      _freq(rootIdx + intervals[2], 1), // 5th oct4
    ];
  }

  // ---------------------------------------------------------------
  // Metronome click generation
  // ---------------------------------------------------------------

  /// Generate a short click/tick sound (woodblock-like).
  Uint8List _generateClickWav({double duration = 0.04}) {
    final numSamples = (_sampleRate * duration).toInt();
    final pcm = Int16List(numSamples);
    const freq = 1200.0; // high pitched tick

    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      // Very fast exponential decay for a sharp click
      final env = exp(-80.0 * t);
      final sample = env * sin(2 * pi * freq * t);
      pcm[i] = (sample.clamp(-0.95, 0.95) * 32767).toInt();
    }
    return _encodePcmToWav(pcm);
  }

  /// Prepare the click audio player pool.
  Future<void> _prepareClick() async {
    final wavBytes = _generateClickWav();
    if (kIsWeb) {
      _clickSource = 'data:audio/wav;base64,${base64Encode(wavBytes)}';
    } else {
      final path = '$_cacheDir/click.wav';
      await platform_io.writeFileIfMissing(path, () => wavBytes);
      _clickSource = path;
    }
    // Create a pool of pre-loaded click players so we never re-load on web.
    for (int i = 0; i < _clickPoolSize; i++) {
      final p = AudioPlayer();
      if (kIsWeb) {
        await p.setUrl(_clickSource!);
      } else {
        await p.setFilePath(_clickSource!);
      }
      await p.setVolume(0.7);
      _clickPool.add(p);
    }
  }

  /// Fire the click sound using a round-robin player pool.
  void _playClick() {
    if (!_metronomeEnabled || _clickPool.isEmpty) return;
    final player = _clickPool[_clickPoolIdx % _clickPoolSize];
    _clickPoolIdx++;
    player.seek(Duration.zero).then((_) => player.play());
  }

  /// Synthesise a guitar-strum–like WAV for [chordName].
  Uint8List _generateChordWav(String chordName, {double duration = 3.0}) {
    final freqs = _chordFrequencies(chordName);
    final numSamples = (_sampleRate * duration).toInt();
    final pcm = Int16List(numSamples);

    // Strum delay per voice (ms) – simulates downstroke
    const strumDelayMs = 12;

    for (int i = 0; i < numSamples; i++) {
      double sample = 0;
      final t = i / _sampleRate;

      for (int v = 0; v < freqs.length; v++) {
        // Stagger each voice by strumDelayMs
        final voiceT = t - (v * strumDelayMs / 1000.0);
        if (voiceT < 0) continue;

        final freq = freqs[v];

        // Plucked-string: fundamental + a couple of harmonics with fast decay
        final env = exp(-3.5 * voiceT); // exponential decay
        sample += env *
            (sin(2 * pi * freq * voiceT) * 0.6 +
                sin(2 * pi * freq * 2 * voiceT) * 0.25 +
                sin(2 * pi * freq * 3 * voiceT) * 0.15);
      }

      // Normalise across voice count
      sample /= freqs.length;

      // Soft clip at +/- 0.95 to avoid harshness
      sample = sample.clamp(-0.95, 0.95);

      pcm[i] = (sample * 32767).toInt();
    }

    return _encodePcmToWav(pcm);
  }

  /// Encodes raw 16-bit mono PCM samples as a RIFF WAV byte buffer.
  Uint8List _encodePcmToWav(Int16List pcm) {
    final dataSize = pcm.length * 2;
    final fileSize = 36 + dataSize;
    final buffer = ByteData(44 + dataSize);

    // RIFF header
    void writeStr(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        buffer.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    buffer.setUint32(4, fileSize, Endian.little);
    writeStr(8, 'WAVE');

    // fmt sub-chunk
    writeStr(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little); // sub-chunk size
    buffer.setUint16(20, 1, Endian.little); // PCM
    buffer.setUint16(22, 1, Endian.little); // mono
    buffer.setUint32(24, _sampleRate, Endian.little);
    buffer.setUint32(28, _sampleRate * 2, Endian.little); // byte rate
    buffer.setUint16(32, 2, Endian.little); // block align
    buffer.setUint16(34, 16, Endian.little); // bits per sample

    // data sub-chunk
    writeStr(36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    // PCM data
    for (int i = 0; i < pcm.length; i++) {
      buffer.setInt16(44 + i * 2, pcm[i], Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  // ---------------------------------------------------------------
  // Chord file caching
  // ---------------------------------------------------------------

  /// Ensures the WAV data for [chordName] is generated and cached.
  /// On native, writes to a file and returns the path.
  /// On web, caches in memory and returns a data URI.
  Future<String> _ensureChordSource(String chordName) async {
    final safeName = chordName.replaceAll('#', 'sharp');

    if (kIsWeb) {
      if (!_wavCache.containsKey(safeName)) {
        _wavCache[safeName] = _generateChordWav(chordName);
      }
      final b64 = base64Encode(_wavCache[safeName]!);
      return 'data:audio/wav;base64,$b64';
    } else {
      final path = '$_cacheDir/chord_$safeName.wav';
      await platform_io.writeFileIfMissing(path, () => _generateChordWav(chordName));
      return path;
    }
  }

  // Pool of chord players per chord name — avoids re-loading source on web.
  static const int _chordPoolSize = 2;
  final Map<String, List<AudioPlayer>> _chordPools = {};
  final Map<String, int> _chordPoolIdx = {};

  // Cache of audio source URIs/paths (avoid regenerating WAVs).
  final Map<String, String> _sourceCache = {};

  /// Pre-generate and pre-load player pools for every unique chord.
  Future<void> prepareChords(List<String> chordNames) async {
    final unique = chordNames.toSet();
    for (final name in unique) {
      if (!_sourceCache.containsKey(name)) {
        _sourceCache[name] = await _ensureChordSource(name);
      }
      if (!_chordPools.containsKey(name)) {
        final pool = <AudioPlayer>[];
        for (int i = 0; i < _chordPoolSize; i++) {
          final player = AudioPlayer();
          if (kIsWeb) {
            await player.setUrl(_sourceCache[name]!);
          } else {
            await player.setFilePath(_sourceCache[name]!);
          }
          await player.setVolume(1.0);
          pool.add(player);
        }
        _chordPools[name] = pool;
        _chordPoolIdx[name] = 0;
      }
    }
  }

  /// Get the next player from the chord's round-robin pool.
  AudioPlayer? _nextChordPlayer(String chordName) {
    final pool = _chordPools[chordName];
    if (pool == null || pool.isEmpty) return null;
    final idx = (_chordPoolIdx[chordName] ?? 0) % pool.length;
    _chordPoolIdx[chordName] = idx + 1;
    return pool[idx];
  }

  // ---------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------

  /// Start looping the given progression at [bpm].
  Future<void> play(List<ChordEntry> progression, int bpm) async {
    if (progression.isEmpty) return;
    _playing = true;

    // Pre-load all chords
    await prepareChords(progression.map((e) => e.name).toList());

    // Beat duration in microseconds for precise timing
    final beatUs = (60000000 / bpm).round();

    final stopwatch = Stopwatch()..start();
    int nextBeatUs = 0; // when the next beat should fire

    while (_playing) {
      for (int ci = 0; ci < progression.length && _playing; ci++) {
        final entry = progression[ci];
        for (int m = 0; m < entry.measures && _playing; m++) {
          // Notify UI of chord change
          onMeasureChange?.call(ci, m);

          // 4 beats per measure
          for (int beat = 0; beat < 4 && _playing; beat++) {
            // Wait until the precise beat time
            final waitUs = nextBeatUs - stopwatch.elapsedMicroseconds;
            if (waitUs > 1000) {
              await Future.delayed(Duration(microseconds: waitUs - 500));
            }
            // Spin-wait for the last fraction for precision
            while (stopwatch.elapsedMicroseconds < nextBeatUs) {}

            if (!_playing) break;

            onBeat?.call(beat);

            if (beat == 0) {
              // Beat 1: strum the chord + click
              final player = _nextChordPlayer(entry.name);
              if (player != null) {
                player.seek(Duration.zero).then((_) => player.play());
              }
              _playClick();
            } else {
              // Beats 2-4: click only
              _playClick();
            }

            nextBeatUs += beatUs;
          }
        }
      }
    }

    stopwatch.stop();
  }

  /// Stop playback.
  void stop() {
    _playing = false;
    for (final pool in _chordPools.values) {
      for (final p in pool) {
        p.pause();
      }
    }
    for (final p in _clickPool) {
      p.pause();
    }
    onMeasureChange = null;
    onBeat = null;
  }

  /// Release all players (call on dispose).
  Future<void> dispose() async {
    stop();
    for (final pool in _chordPools.values) {
      for (final p in pool) {
        await p.dispose();
      }
    }
    _chordPools.clear();
    _chordPoolIdx.clear();
    _players.clear();
    for (final p in _clickPool) {
      await p.dispose();
    }
    _clickPool.clear();
  }
}
