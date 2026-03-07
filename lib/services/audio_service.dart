import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, unawaited;
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

  /// Identifier incremented each time the main playback loop restarts.
  /// Scheduled callbacks capture the value to ignore events from previous
  /// iterations, preventing stray notes or clicks when the progression
  /// wraps around.
  int _loopId = 0;

  // Metronome click
  bool _metronomeEnabled = false;
  bool get metronomeEnabled => _metronomeEnabled;
  set metronomeEnabled(bool v) => _metronomeEnabled = v;

  // Pool of click players to avoid re-loading on web.
  static const int _clickPoolSize = 8;
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
    final env = exp(-40.0 * t); // slower decay for better audibility
      final sample = env * sin(2 * pi * freq * t) * 3.0; // even louder click
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
      await p.setVolume(1.0); // full volume for clarity
      _clickPool.add(p);
    }
  }

  /// Fire a click immediately using the pool.
  void _fireClick() {
    if (!_metronomeEnabled || _clickPool.isEmpty) return;
    
    // Find an available player (not currently playing)
    AudioPlayer? availablePlayer;
    for (final player in _clickPool) {
      if (player.playing == false) {
        availablePlayer = player;
        break;
      }
    }
    
    // If no available player, use round-robin as fallback
    if (availablePlayer == null) {
      availablePlayer = _clickPool[_clickPoolIdx % _clickPoolSize];
      _clickPoolIdx++;
    }
    
    // stop() resets the player; seek to start and play immediately
    unawaited(availablePlayer.stop()
        .then((_) => availablePlayer!.seek(Duration.zero))
        .then((_) => availablePlayer!.play()));
  }

  /// Synthesise a guitar-strum–like WAV for [chordName].
  Uint8List _generateChordWav(String chordName, {double duration = 3.0}) {
    final freqs = _chordFrequencies(chordName);
    final numSamples = (_sampleRate * duration).toInt();
    final pcm = Int16List(numSamples);

    // Strum delay per voice (ms) – simulates downstroke
    const strumDelayMs = 1;

    for (int i = 0; i < numSamples; i++) {
      double sample = 0;
      final t = i / _sampleRate;

      for (int v = 0; v < freqs.length; v++) {
        // Stagger each voice by strumDelayMs
        final voiceT = t - (v * strumDelayMs / 1000.0);
        if (voiceT < 0) continue;

        final freq = freqs[v];

        // Plucked-string: fundamental + a couple of harmonics with fast decay
        final env = voiceT < 0.005 ? voiceT / 0.005 : exp(-4.5 * voiceT); // sharper attack
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
  // Default pool size – this will be dynamically expanded based on tempo.
  static const int _initialChordPoolSize = 2;
  final Map<String, List<AudioPlayer>> _chordPools = {};
  final Map<String, int> _chordPoolIdx = {};

  // Cache of audio source URIs/paths (avoid regenerating WAVs).
  final Map<String, String> _sourceCache = {};

  /// Ensure [count] players exist for [chordName], creating and loading them
  /// if necessary.  This allows the pool to grow to accommodate overlapping
  /// notes at faster tempos.
  Future<void> _ensurePoolSize(String chordName, int count) async {
    final pool = _chordPools.putIfAbsent(chordName, () => []);
    while (pool.length < count) {
      final player = AudioPlayer();
      if (kIsWeb) {
        await player.setUrl(_sourceCache[chordName]!);
      } else {
        await player.setFilePath(_sourceCache[chordName]!);
      }
      await player.setVolume(1.0);
      pool.add(player);
    }
    _chordPoolIdx[chordName] = _chordPoolIdx[chordName] ?? 0;
  }

  /// Pre-generate and pre-load player pools for every unique chord.
  Future<void> prepareChords(List<String> chordNames) async {
    final unique = chordNames.toSet();
    for (final name in unique) {
      if (!_sourceCache.containsKey(name)) {
        _sourceCache[name] = await _ensureChordSource(name);
      }
      if (!_chordPools.containsKey(name)) {
        // start with a couple of players; additional ones will be added later
        await _ensurePoolSize(name, _initialChordPoolSize);
      }
    }
  }

  /// Get the next player from the chord's round-robin pool.
  AudioPlayer? _nextChordPlayer(String chordName) {
    final pool = _chordPools[chordName];
    if (pool == null || pool.isEmpty) return null;
    // simple round-robin index – we rely on pools being sized sufficiently
    final idx = (_chordPoolIdx[chordName] ?? 0) % pool.length;
    _chordPoolIdx[chordName] = idx + 1;
    return pool[idx];
  }

  // ---------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------

  /// Fire a chord immediately using the pool.  This mirrors the old
  /// logic we used inline – stop/seek/play chained but not awaited.
  void _fireChord(String chordName) {
    final player = _nextChordPlayer(chordName);
    if (player == null) return;
    unawaited(player.stop()
        .then((_) => player.seek(Duration.zero))
        .then((_) => player.play()));
  }

  /// Schedule a chord to play after the given [delay].  If the delay is
  /// effectively zero we invoke synchronously to avoid race conditions where
  /// the future fires after another chord has already reused the same player.
  void _scheduleChord(String chordName, Duration delay) {
    final id = _loopId;
    if (!_playing) return;
    if (delay <= const Duration(microseconds: 100)) {
      if (id == _loopId && _playing) _fireChord(chordName);
      return;
    }
    Future.delayed(delay, () {
      if (!_playing || id != _loopId) return;
      _fireChord(chordName);
    });
  }

  /// Schedule a metronome click after [delay].
  void _scheduleClick(Duration delay) {
    final id = _loopId;
    if (!_playing) return;
    if (delay <= const Duration(microseconds: 100)) {
      if (id == _loopId && _playing) _fireClick();
      return;
    }
    Future.delayed(delay, () {
      if (!_playing || id != _loopId) return;
      _fireClick();
    });
  }

  /// Start looping the given progression at [bpm].
  Future<void> play(List<ChordEntry> progression, int bpm) async {
    if (progression.isEmpty) return;
    _playing = true;

    // Pre-load all chords
    await prepareChords(progression.map((e) => e.name).toList());

    // Determine how many players we need per chord based on tempo.
    // Chord audio is generated with a fixed duration (_chordDurationSec)
    // so compute the number of overlapping measures that fit in that
    // duration and add a small buffer.
    const chordDurSec = 3.0; // must match _generateChordWav default
    final measureUs = (60000000 / bpm).round() * 4;
    final requiredPerChord = (chordDurSec * 1e6 / measureUs).ceil() + 1;
    for (final name in progression.map((e) => e.name).toSet()) {
      await _ensurePoolSize(name, requiredPerChord);
    }

    // Beat duration in microseconds for precise timing
    final beatUs = (60000000 / bpm).round();

    // Single stopwatch used for entire playback; keep it running through
    // loop boundaries to maintain consistent spacing.
    final stopwatch = Stopwatch()..start();
    int nextBeatUs = 0; // when the next beat should fire
    _loopId++; // bump identifier for this playback session

    // state indices for progression
    int ci = 0;
    int m = 0;

    while (_playing) {
      if (progression.isEmpty) break;

      final entry = progression[ci];
      // notify UI when a new measure begins
      onMeasureChange?.call(ci, m);

      // play four beats of the current measure
      for (int beat = 0; beat < 4 && _playing; beat++) {
        final elapsed = stopwatch.elapsedMicroseconds;
        // make sure nextBeatUs always points to a future moment; if the
        // loop took too long we may have fallen behind, so catch up in
        // beat‑sized increments.  This is particularly important when the
        // progression wraps, otherwise the first beat of the new cycle would
        // fire immediately and effectively eat a beat.
        while (nextBeatUs <= elapsed) {
          nextBeatUs += beatUs;
        }
        final rawDelayUs = nextBeatUs - elapsed;
        
        // Chords need lead time to compensate for attack envelope
        var chordDelayUs = rawDelayUs;
        const leadUs = 24000; // 24ms lead time for chords
        chordDelayUs -= leadUs;
        final chordDelay = Duration(microseconds: chordDelayUs > 0 ? chordDelayUs : 0);
        
        // Clicks should fire at exact beat time with no lead time
        final clickDelay = Duration(microseconds: rawDelayUs > 0 ? rawDelayUs : 0);

        onBeat?.call(beat);

        if (beat == 0) {
          _scheduleChord(entry.name, chordDelay);
          if (_metronomeEnabled) _scheduleClick(clickDelay);
        } else if (_metronomeEnabled) {
          _scheduleClick(clickDelay);
        }

        // Wait until the precise scheduled time
        if (rawDelayUs > 1000) {
          await Future.delayed(Duration(microseconds: rawDelayUs - 500));
        }
        while (stopwatch.elapsedMicroseconds < nextBeatUs) {}

        if (!_playing) break;
        nextBeatUs += beatUs;
      }

      // advance measure/chord indices
      m++;
      if (m >= entry.measures) {
        m = 0;
        ci = (ci + 1) % progression.length;
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
