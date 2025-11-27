import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/views/pages/home.dart';
import 'package:app_location_alarm_reconecta/views/pages/settings.dart';
import 'package:app_location_alarm_reconecta/views/widgets/circle.dart';
import 'package:app_location_alarm_reconecta/views/widgets/swipe_down.dart';
import 'package:flutter/material.dart';

class SimpleviewPage extends StatelessWidget {
  const SimpleviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
              onPressed: () {
                Navigator.push(context, _createRoute());
              },
              icon: Icon(Icons.settings)),
        ],
      ),
      body: Column(
        children: [
          Text('On way to the destination', style: KTextStyles.buttonTextStyle),
          SizedBox(height: 120),
          Center(child: Circle()),
          SizedBox(height: 100),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                color: Colors.red.shade200,
                icon: Icon(
                  Icons.pause,
                  size: 40,
                ),
                onPressed: () {},
              ),
              SizedBox(
                width: 20,
              ),
              IconButton(
                icon: Icon(Icons.play_arrow, size: 40),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const Settings(),
      transitionDuration: const Duration(milliseconds: 1000),
      reverseTransitionDuration: const Duration(microseconds: 1000),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.bounceOut;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }
}
