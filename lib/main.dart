import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'screens/homepage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const FoodRescueApp());
}

class FoodRescueApp extends StatelessWidget {
  const FoodRescueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Food Rescue",
      theme: ThemeData(primaryColor: appPrimaryGreen),
      home: const LandingPage(),
    );
  }
}