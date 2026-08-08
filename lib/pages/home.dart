import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/pitch_service.dart';

import '../audio/note_utils.dart';
import '../audio/tuner_smoother.dart';

class HomePage extends StatefulWidget {
  const HomePage ({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}


class _HomePageState extends State<HomePage> {
  final _pitchService = PitchService();
  
  final _tunerSmoother = TunerSmoother(windowSize: 5);
  NoteResult? _displayNote;

  bool _isRecording = false;
  String? _error;

  static const double _maxAngleRad = 1.55;
  static const double _maxCents = 50;


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
    setState(() => _displayNote = smoothedNote);
  }

  @override
  void dispose() {
    _pitchService.dispose();
    super.dispose();
  }

  double get _targetAngle{
    final cents = _displayNote?.cents ?? 0;
    final clamped = cents.clamp(-_maxCents, _maxCents);
    return (clamped / _maxCents) * _maxAngleRad;
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
              child: SvgPicture.asset('assets/icons/out-tune-arrow.svg'),
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
                    SvgPicture.asset('assets/icons/measurement.svg'),
                    // Transform.rotate(
                    //   angle: 0.0, //angle should be between -1.55 and 1.55
                    //   alignment: Alignment.center,
                    //   child: SvgPicture.asset('assets/icons/needle.svg')
                    // )
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
