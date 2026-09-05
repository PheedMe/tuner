import 'dart:collection';

import 'note_utils.dart';

/// Smooths incoming pitch readings for stable tuner-style display.
///
/// This does two separate things, both keyed on note identity rather than
/// raw Hz (since Hz can jump an octave without changing the note or cents):
///
/// 1. **Note-lock (hysteresis)**: the displayed note only changes when a
///    new note wins a majority vote across the last [noteVoteWindowSize]
///    readings — a single noisy/outlier frame (e.g. C briefly misread as
///    C#) won't flip the display. This mirrors how most tuner apps avoid
///    flickering on sustained tones.
/// 2. **Cents smoothing**: cents readings are averaged, but ONLY across
///    frames that agree with the currently-locked note — this avoids
///    blending cents across an octave jump or across the ±50¢ wraparound
///    boundary between adjacent notes. On top of the windowed average, an
///    exponential moving average (EMA) is applied for extra smoothness —
///    see [emaSmoothingFactor].
class TunerSmoother {
  TunerSmoother({
    this.centsWindowSize = 5,
    this.noteVoteWindowSize = 3,
    this.emaSmoothingFactor = 0.2,
  }) : assert(emaSmoothingFactor > 0 && emaSmoothingFactor <= 1);

  /// How many recent cents readings (of the current locked note) to
  /// average for the displayed cents value.
  final int centsWindowSize;

  /// How many recent raw note readings to vote across before allowing
  /// the displayed note to change. Higher = more stable but slower to
  /// respond to a genuine new note; lower = more responsive but more
  /// prone to flicker.
  final int noteVoteWindowSize;

  /// Weight given to each new windowed-average reading when folding it
  /// into the displayed (EMA) cents value. Range (0, 1].
  ///
  /// - Closer to 1.0: barely any extra smoothing beyond the window
  ///   average — reacts almost immediately to new readings.
  /// - Closer to 0.0: very smooth/gradual motion, but slower to catch up
  ///   to genuine pitch changes (more visual "lag").
  ///
  /// 0.15-0.3 is a reasonable range for a calm-feeling tuner display.
  final double emaSmoothingFactor;

  final Queue<double> _centsWindow = Queue<double>();
  final Queue<String> _noteVotes = Queue<String>();

  String? _currentNote;
  int? _currentOctave;
  double? _emaCents;

  /// Feed a new raw Hz reading in. Returns the smoothed [NoteResult] to
  /// display, or `null` if [hz] didn't map to a valid note, or if we
  /// don't yet have any cents data for the currently-locked note.
  NoteResult? addReading(double hz) {
    final result = hzToNote(hz);
    if (result == null) return null;

    // Record this frame's raw note as a vote.
    _noteVotes.add(result.note);
    if (_noteVotes.length > noteVoteWindowSize) {
      _noteVotes.removeFirst();
    }

    final majorityNote = _majorityVote(_noteVotes);

    // Only switch the locked note when the majority actually disagrees
    // with what's currently displayed. A single outlier frame won't win
    // a majority against several consistent frames, so the display holds
    // steady through brief misreads.
    if (majorityNote != _currentNote) {
      _currentNote = majorityNote;
      _centsWindow.clear();
      _emaCents = null; // don't drag the old note's smoothed value into the new one
    }

    // Only fold this frame's cents into the average if it agrees with
    // the currently-locked note — an outlier frame's cents value (which
    // may be wildly off, e.g. near +/-50) shouldn't pollute the average
    // for the note we're actually displaying.
    if (result.note == _currentNote) {
      _currentOctave = result.octave;
      _centsWindow.add(result.cents);
      if (_centsWindow.length > centsWindowSize) {
        _centsWindow.removeFirst();
      }
    }

    if (_centsWindow.isEmpty) return null;

    final windowedAverage =
        _centsWindow.reduce((a, b) => a + b) / _centsWindow.length;

    // Exponential moving average: blend the new windowed-average reading
    // into the running EMA value. This is what actually produces the
    // "smoother, less jumpy in the small digits" feel — the window
    // average alone still lets each new frame swing the result somewhat;
    // the EMA further damps frame-to-frame movement without needing an
    // even bigger (and thus slower-reacting) window.
    if (_emaCents == null) {
      _emaCents = windowedAverage; // first reading for this note — no lag-in needed
    } else {
      _emaCents = emaSmoothingFactor * windowedAverage +
          (1 - emaSmoothingFactor) * _emaCents!;
    }

    return NoteResult(
      note: _currentNote!,
      octave: _currentOctave ?? result.octave,
      cents: _emaCents!,
    );
  }

  /// Returns the most frequent note name in [votes]. Ties broken by
  /// whichever appeared first in this pass (order doesn't matter much in
  /// practice since a true tie means the signal is genuinely ambiguous).
  String _majorityVote(Queue<String> votes) {
    final counts = <String, int>{};
    for (final v in votes) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    String best = votes.first;
    int bestCount = 0;
    counts.forEach((note, count) {
      if (count > bestCount) {
        bestCount = count;
        best = note;
      }
    });
    return best;
  }

  /// Call this when recording stops or after a period of silence, so the
  /// next note starts with a fresh window instead of blending into
  /// whatever was last held.
  void reset() {
    _centsWindow.clear();
    _noteVotes.clear();
    _currentNote = null;
    _currentOctave = null;
    _emaCents = null;
  }
}

