import 'dart:math' as math;

class NoteResult {
  const NoteResult ({
    required this.note,
    required this.octave,
    required this.cents,
  });

  final String note;


  final int octave;


  final double cents;

  String get label => '$note$octave';

  bool get isSharp => cents > 0;
  bool get isFlat => cents < 0;

  bool isInTune({double toleranceCents = 5}) => cents.abs() <= toleranceCents;

  @override
  String toString() =>
    '$label (${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(1)}¢)';
}

const _noteNames = [
  'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'G#', 'A', 'Bb', 'B',
];


NoteResult? hzToNote(double hz, {double referenceHz = 440.0}) {
  if (hz <= 0 || !hz.isFinite) return null;

  final semitonesFromA4 = 12 * (math.log(hz / referenceHz) / math.ln2);

  final roundedSemitones = semitonesFromA4.round();
  final cents = (semitonesFromA4 - roundedSemitones) * 100;

  final midiNumber = 69 + roundedSemitones;

  final noteIndex = midiNumber % 12;
  final normalizedIndex = noteIndex < 0 ? noteIndex + 12 : noteIndex;

  final octave = (midiNumber / 12).floor() - 1;

  return NoteResult(
    note: _noteNames[normalizedIndex],
    octave: octave,
    cents: cents,
  );
}