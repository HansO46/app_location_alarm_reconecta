import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/views/pages/destination_page.dart';
import 'package:flutter/material.dart';

class CategorySelectionPage extends StatelessWidget {
  const CategorySelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'A donde deseas llegar?',
              style: KTextStyles.messageStyle,
            ),
            SizedBox(height: 50),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                FilledButton.tonal(
                  style: KButtonStyles.squareButtonStyle,
                  onPressed: () {},
                  child: Column(
                    children: [
                      Icon(Icons.home),
                      Text('Home', style: KTextStyles.buttonTextStyle),
                    ],
                  ),
                ),
                FilledButton(
                  style: KButtonStyles.squareButtonStyle,
                  onPressed: () {},
                  child: Column(
                    children: [
                      Icon(Icons.work),
                      Text('Work', style: KTextStyles.buttonTextStyle),
                    ],
                  ),
                ),
                FilledButton(
                  style: KButtonStyles.squareButtonStyle,
                  onPressed: () {},
                  child: Column(
                    children: [
                      Icon(Icons.train),
                      Text('Train', style: KTextStyles.buttonTextStyle),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  style: KButtonStyles.squareButtonStyle,
                  onPressed: () {},
                  child: Column(
                    children: [
                      Icon(Icons.location_city),
                      Text('Other', style: KTextStyles.buttonTextStyle),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) {
                      return DestinationPage();
                    },
                  ));
                },
                child: Text('En otro momento'))
          ],
        ),
      ),
    );
  }
}
