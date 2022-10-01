//Homepage function
//Flutter SDK
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ppg_tester/homePage.dart';


//Running the app.
void main() => runApp(MyApp());

//Some dependencies.
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      //Title
      title: 'Photoplethysmograph',
      //Interface theme
      theme: ThemeData(
        brightness: Brightness.light,
      ),
      home: HomePage(),
    );
  }
}
