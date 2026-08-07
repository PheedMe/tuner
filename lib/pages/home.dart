import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff131936),
      appBar: appBar(),


      body: Padding(
        padding: const EdgeInsets.only(top: 35, left: 25, right: 25),
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
            const SizedBox(height: 70),
            Center(
              child: SvgPicture.asset('assets/icons/in-tune-arrow.svg'),
            ),
            const SizedBox(height: 10),
            Center(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  SvgPicture.asset('assets/icons/measurement.svg'),
                  Transform.rotate(
                    angle: 0.0,
                    alignment: Alignment.center,
                    child: SvgPicture.asset('assets/icons/needle.svg')
                  )
                ]
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 36),
              child: Transform.translate(
                offset: Offset(0, -140),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('B4',
                    style: TextStyle(color: Color(0xff7B9BF5))),
                    Text('0 cents',
                    style: TextStyle(color: Color(0xff7B9BF5))),
                    Text('C#4',
                    style: TextStyle(color: Color(0xff7B9BF5))),
                  ],
                )
              )
            ),
            Transform.translate(
              offset: Offset(0, -140),
              child: Text('C',
              style: TextStyle(fontSize: 150),) 
            ),
            Text('Hello')
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
