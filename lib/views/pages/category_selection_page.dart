import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/views/pages/destination_page.dart';
import 'package:app_location_alarm_reconecta/data/models/alarm_model.dart';
import 'package:flutter/material.dart';

class CategorySelectionPage extends StatelessWidget {
  final Alarm? alarmToEdit; // Alarma a editar (opcional)

  const CategorySelectionPage({super.key, this.alarmToEdit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              SizedBox(height: 20),
              if (alarmToEdit != null)
                Row(mainAxisAlignment: MainAxisAlignment.start, children: [BackButton()]),
              SizedBox(height: 20),
              Column(
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
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DestinationPage(
                                category: 'home',
                                alarmToEdit: alarmToEdit,
                              ),
                            ),
                          );
                          if (result == true && alarmToEdit != null) {
                            Navigator.pop(context, true);
                          }
                        },
                        child: Column(
                          children: [
                            Icon(Icons.home),
                            Text('Home', style: KTextStyles.buttonTextStyle),
                          ],
                        ),
                      ),
                      FilledButton(
                        style: KButtonStyles.squareButtonStyle,
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DestinationPage(
                                category: 'work',
                                alarmToEdit: alarmToEdit,
                              ),
                            ),
                          );
                          if (result == true && alarmToEdit != null) {
                            Navigator.pop(context, true);
                          }
                        },
                        child: Column(
                          children: [
                            Icon(Icons.work),
                            Text('Work', style: KTextStyles.buttonTextStyle),
                          ],
                        ),
                      ),
                      FilledButton(
                        style: KButtonStyles.squareButtonStyle,
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DestinationPage(
                                category: 'train',
                                alarmToEdit: alarmToEdit,
                              ),
                            ),
                          );
                          if (result == true && alarmToEdit != null) {
                            Navigator.pop(context, true);
                          }
                        },
                        child: Column(
                          children: [
                            Icon(Icons.train),
                            Text('Train', style: KTextStyles.buttonTextStyle),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        style: KButtonStyles.squareButtonStyle,
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DestinationPage(
                                category: 'other',
                                alarmToEdit: alarmToEdit,
                              ),
                            ),
                          );
                          if (result == true && alarmToEdit != null) {
                            Navigator.pop(context, true);
                          }
                        },
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
                      onPressed: () async {
                        final result = await Navigator.push(context, MaterialPageRoute(
                          builder: (context) {
                            return DestinationPage(alarmToEdit: alarmToEdit);
                          },
                        ));
                        if (result == true && alarmToEdit != null) {
                          Navigator.pop(context, true);
                        }
                      },
                      child: Text('En otro momento'))
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
