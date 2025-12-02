import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/views/pages/onboarding_page.dart';
import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return OnboardingPage();
            },
          ),
        );
      },
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(flex: 1, child: SizedBox()), // Espacio arriba
              Image.asset('assets/images/logo.png', width: 250, height: 250),
              Text(
                'Reconnecta',
                style: KTextStyles.titleStyle,
              ),
              Text(
                'Alarm for travelers',
                style: KTextStyles.sloganStyle,
              ),
              Spacer(),
              Expanded(flex: 1, child: SizedBox()), // Espacio en medio

              Padding(
                padding: EdgeInsets.only(bottom: 100),
                child: Text(
                  'Enjoy your journey as you desire',
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      letterSpacing: 4,
                      color: KColors.mainColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
