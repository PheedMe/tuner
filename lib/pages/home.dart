import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/pitch_service.dart';

import '../audio/note_utils.dart';
import '../audio/tuner_smoother.dart';

import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pitchService = PitchService();
  final _tunerSmoother = TunerSmoother(centsWindowSize: 5);
  NoteResult? _displayNote;

  bool _isRecording = false;
  String? _error;

  static const double _maxAngleRad = 1.55;
  static const double _maxCents = 50;

  Timer? _inTuneHoldTimer;
  Timer? _silenceTimer;
  bool _wasInRange = false;
  bool _isConfirmedInTune = false;

  @override
  void initState() {
    super.initState();
    _pitchService.hzStream.listen(_onHz);
    _startRecording();
  }

  Future<void> _startRecording() async {
    final started = await _pitchService.start();
    if (!started) {
      setState(() => _error = 'Microphone permission denied.');
      return;
    }
    setState(() {
      _isRecording = true;
      _error = null;
    });
  }

  void _onHz(double hz) {
  final smoothedNote = _tunerSmoother.addReading(hz);
  if (!mounted) return;

  // Only overwrite the displayed note when the smoother actually
  // returns one — a transient null (e.g. right as the note-lock
  // switches) won't blank a note that's still being played, and
  // once you stop entirely, the last note just stays on screen.
  if (smoothedNote != null) {
    setState(() => _displayNote = smoothedNote);
  }
  _upDateInTuneState(smoothedNote);
}

@override
void dispose() {
  _inTuneHoldTimer?.cancel();
  _pitchService.dispose();
  super.dispose();
}

  double get _targetAngle {
    final cents = _displayNote?.cents ?? 0;
    final clamped = cents.clamp(-_maxCents, _maxCents);
    return (clamped / _maxCents) * _maxAngleRad;
  }

  void _upDateInTuneState(NoteResult? note) {
    final inRange = note != null && note.cents >= -10 && note.cents <= 10;

    if (inRange && !_wasInRange) {
      _inTuneHoldTimer?.cancel();
      _inTuneHoldTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => _isConfirmedInTune = true);
      });
    } else if (!inRange && _wasInRange) {
      _inTuneHoldTimer?.cancel();
      if (_isConfirmedInTune) {
        setState(() => _isConfirmedInTune = false);
      }
    }
    _wasInRange = inRange;
  }


  @override
  Widget build(BuildContext context) {
    final note = _displayNote;

    return Scaffold(
      backgroundColor: Color(0xff131936),
      appBar: appBar(),


      body: Padding(
        padding: const EdgeInsets.only(top: 5, left: 25, right: 25),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('A4 = 440 Hz'),
                Container(
                  margin: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xff131936)
                  ),
                  child: SvgPicture.asset('assets/icons/settings-gear.svg')
                )
              ]
            ),
            const SizedBox(height: 90),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: SvgPicture.asset(
                  _isConfirmedInTune
                    ? 'assets/icons/in-tune-arrow.svg' : 'assets/icons/out-tune-arrow.svg',
                  key: ValueKey(_isConfirmedInTune),
                )
              ),
            ),

            SizedBox(
              height: 170,
              child: FittedBox(
                fit: BoxFit.none,
                alignment: Alignment.topCenter,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset('assets/icons/measurement.png'),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: _targetAngle), 
                      duration: const Duration(milliseconds: 180),
                      builder: (context, angle, child) {
                        return Transform.rotate(
                          angle: angle,
                          child: child,
                        );
                      },
                      child: SvgPicture.asset('assets/icons/needle.svg'),
                    ),
                  ]
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 43),
              child: Row(
                  children: [
                    Expanded(
                      child: Text('b', 
                      textAlign: TextAlign.left,
                      style: TextStyle(color: Color(0xff7B9BF5))
                      ),
                    ),
                    if (note != null)
                      Expanded(
                        child: Text('${note.cents >= 0 ? '+' : ''}${note.cents.toStringAsFixed(1)}¢', 
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xff7B9BF5),),
                        ),
                      ),
                    Expanded(
                      child: Text('#', 
                      textAlign: TextAlign.right,
                      style: TextStyle(color: Color(0xff7B9BF5))
                      ),
                    ),
                  ],
                )
              ),
              SizedBox(
                height: 200,
                child: Center(
                  child: note != null
                    ? Text(note.note, style: TextStyle(fontSize: 200, fontWeight: FontWeight.w900, height: 1.0))
                    : Text(
                      _isRecording ? 'Listening...' : 'Loading...',
                      style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.w700,)
                    ),
                ),
              ),
            const SizedBox(height: 35),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff3483C8),
                    foregroundColor: Colors.white
                  ),
                  onPressed: () {
                  },
                  child: Text('Tuning Drone')
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff3483C8),
                    foregroundColor: Colors.white
                  ),
                  onPressed: () {
                  },
                  child: Text('Metronome')
                )
              ]
            )
          ]
        )
      ), 

    );
  }
}


// Top App Bar
AppBar appBar() {
  return AppBar(
    backgroundColor: Color(0xff131936),
        title: Text(
          'Tuner',
          style: TextStyle(
            fontFamily: 'PottaOne',
            fontSize: 28,
            color: Color(0xffF5F5F5)
          ),
        ),
        centerTitle: true,
      );
}
