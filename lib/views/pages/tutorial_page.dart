import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: IntroductionScreen(
        pages: [
          PageViewModel(
            title: "Title of introduction page",
            body: "Welcome to the app! This is a description of how it works.",
            image: const Center(
              child: Icon(Icons.waving_hand, size: 50.0),
            ),
          ),
          PageViewModel(
            title: "Title of blue page",
            body: "Welcome to the app! This is a description on a page with a blue background.",
            image: Center(),
            decoration: const PageDecoration(
              pageColor: Colors.blue,
            ),
          ),
          PageViewModel(
            title: "Title of orange text and bold page",
            body: "This is a description on a page with an orange title and bold, big body.",
            image: const Center(
              child: Text("👋", style: TextStyle(fontSize: 100.0)),
            ),
            decoration: const PageDecoration(
              titleTextStyle: TextStyle(color: Colors.orange),
              bodyTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 20.0),
            ),
          ),
          PageViewModel(
            title: "Title of custom button page",
            body: "This is a description on a page with a custom button below.",
            image: Image.asset("assets/images/logo.png", height: 175.0),
            footer: ElevatedButton(
              onPressed: () {
                // On button pressed
              },
              child: const Text("Let's Go!"),
            ),
          ),
          PageViewModel(
            title: "Title of custom body page",
            bodyWidget: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text("Click on "),
                Icon(Icons.edit),
                Text(" to edit a post"),
              ],
            ),
            image: const Center(child: Icon(Icons.android)),
          )
        ],
        showNextButton: false,
        done: const Text("Done"),
        onDone: () {
          // On button pressed
        },
      ),
    );
  }
}
