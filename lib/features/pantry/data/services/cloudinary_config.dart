import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Unsigned Cloudinary upload settings loaded from the project `.env` file.
///
/// Do not commit a cloud name, upload preset, API key, or API secret.
class CloudinaryConfig {
  const CloudinaryConfig({required this.cloudName, required this.uploadPreset});

  factory CloudinaryConfig.fromEnvironment() {
    const definedCloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
    const definedUploadPreset = String.fromEnvironment(
      'CLOUDINARY_UPLOAD_PRESET',
    );
    return CloudinaryConfig(
      cloudName: definedCloudName.isNotEmpty
          ? definedCloudName
          : dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '',
      uploadPreset: definedUploadPreset.isNotEmpty
          ? definedUploadPreset
          : dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '',
    );
  }

  final String cloudName;
  final String uploadPreset;

  bool get isConfigured {
    final name = cloudName.trim();
    final preset = uploadPreset.trim();
    if (name.isEmpty || preset.isEmpty) return false;
    if (name.contains('/') || name.contains(' ')) return false;
    return true;
  }
}

/// Stored on pantry documents uploaded through Cloudinary.
const String kCloudinaryImageProvider = 'cloudinary';

const int kPantryImageMaxBytes = 5 * 1024 * 1024;

const String kPantryImageTypeMessage =
    'Please select a JPG, PNG, or WebP image.';

const String kPantryImageTooLargeMessage =
    'The selected image is too large. Choose an image smaller than 5 MB.';

const String kPantryImageUploadFailedMessage =
    'We couldn’t upload the photo. Check your connection and try again.';

const String kPantryImageConfigMessage =
    'Cloudinary is not configured. Add CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET to the .env file.';
