import 'dart:collection';

import 'note_utils.dart';

class TunerSmoother {
  TunerSmoother({this.windowSize = 5});

  final int windowSize;
  final Queue<double> _centsWindow = Queue<double>();
  String? _currentNote;
  int? _currentOctave;

  NoteResult? addReading(double hz) {
    final result = hzToNote(hz);
    if (result == null) return null;

    if (result.note != _currentNote) {
      _centsWindow.clear();
      _currentNote = result.note;
    }
    

    _currentOctave = result.octave;

    _centsWindow.add(result.cents);
    if (_centsWindow.length > windowSize) {
      _centsWindow.removeFirst();
    }

    final smoothedCents = 
        _centsWindow.reduce((a, b) => a + b) / _centsWindow.length;


    return NoteResult(
      note: _currentNote!,
      octave: _currentOctave!,
      cents: smoothedCents,
    );
  }

  void reset() {
    _centsWindow.clear();
    _currentNote = null;
    _currentOctave = null;
  }
}