import 'package:app_location_alarm_reconecta/data/constants.dart';
import 'package:app_location_alarm_reconecta/data/notifiers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(top: 12, left: 12, right: 12),
              child: Card(
                child: Container(
                  padding: EdgeInsets.all(16),
                  width: double.infinity,
                  child: Column(
                    children: [
                      Text('General', style: KTextStyles.titlesStyle),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('App Theme', style: KTextStyles.settingsTextStyle),
                          ValueListenableBuilder(
                            valueListenable: isDarkModeNotifier,
                            builder: (context, isDarkMode, child) {
                              return IconButton(
                                onPressed: () async {
                                  print('onPressed: ${isDarkModeNotifier.value}');
                                  isDarkModeNotifier.value = !isDarkModeNotifier.value;
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool(
                                      KConstants.themeModeKey, isDarkModeNotifier.value);
                                },
                                icon: isDarkModeNotifier.value
                                    ? Icon(Icons.light_mode)
                                    : Icon(Icons.dark_mode),
                              );
                            },
                          )
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Language', style: KTextStyles.settingsTextStyle),
                          IconButton(onPressed: () {}, icon: Icon(Icons.language))
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Appareance', style: KTextStyles.settingsTextStyle),
                          IconButton(onPressed: () {}, icon: Icon(Icons.color_lens))
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.only(top: 12, left: 12, right: 12),
              child: Card(
                child: Container(
                  padding: EdgeInsets.all(16),
                  width: double.infinity,
                  child: Column(
                    children: [
                      Text('Alarm', style: KTextStyles.titlesStyle),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Sound', style: KTextStyles.settingsTextStyle),
                        PopupMenuButton<String>(
                          onSelected: (value) {},
                          itemBuilder: (context) => [
                            PopupMenuItem(value: '1', child: Text('Opción 1')),
                          ],
                        ),
                      ]),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Vibration', style: KTextStyles.settingsTextStyle),
                        IconButton(onPressed: () {}, icon: Icon(Icons.vibration))
                      ]),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Output sound', style: KTextStyles.settingsTextStyle),
                        IconButton(onPressed: () {}, icon: Icon(Icons.headphones))
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
