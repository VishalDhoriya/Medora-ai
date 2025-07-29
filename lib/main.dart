import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  Future<bool> _isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('onboard_name');
    final model = prefs.getString('onboard_model');
    final token = prefs.getString('onboard_hf_token');
    return name != null && name.isNotEmpty &&
           model != null && model.isNotEmpty &&
           token != null && token.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isOnboardingComplete(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
            debugShowCheckedModeBanner: false,
          );
        }
        final onboardingDone = snapshot.data ?? false;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            textTheme: GoogleFonts.plusJakartaSansTextTheme(),
          ),
          home: onboardingDone ? const WelcomeScreen() : const OnboardingScreen(),
          routes: {
            '/welcome': (context) => const WelcomeScreen(),
          },
        );
      },
    );
  }
}
