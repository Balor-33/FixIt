import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryConfig {
  // Secure credential loading
  static String get cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get apiKey => dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  static String get apiSecret => dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

  // Upload configuration (unchanged)
  static const String uploadFolder = 'fixit_issues';
  static const int maxImageQuality = 85;
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1080;
}
