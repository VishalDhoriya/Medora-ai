import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // Hugging Face token from environment file
  static String get huggingFaceToken => dotenv.env['HF_TOKEN'] ?? '';
  
  // Other app constants can be added here
  static String get appName => dotenv.env['APP_NAME'] ?? 'GameOn Medical AI';
}
