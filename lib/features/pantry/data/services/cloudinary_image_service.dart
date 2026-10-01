import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'cloudinary_config.dart';
import 'pantry_firestore_service.dart';

/// Successful unsigned Cloudinary upload.
class PantryImageUploadResult {
  const PantryImageUploadResult({
    required this.secureUrl,
    required this.publicId,
    this.width,
    this.height,
    this.format,
  });

  final String secureUrl;
  final String publicId;
  final int? width;
  final int? height;
  final String? format;
}

/// Upload failed after the file was accepted. The form can offer a retry.
class PantryImageUploadException extends PantryFirestoreException {
  const PantryImageUploadException([
    super.message = kPantryImageUploadFailedMessage,
  ]);
}

/// Missing Cloudinary settings in the .env file. This does not crash the app.
class PantryImageConfigurationException extends PantryFirestoreException {
  const PantryImageConfigurationException([
    super.message = kPantryImageConfigMessage,
  ]);
}

/// Uploads a pantry photo with an unsigned Cloudinary preset.
///
/// The client never receives an API secret. Deleting an uploaded asset needs
/// a signed server-side request and is intentionally not implemented here.
class CloudinaryImageService {
  CloudinaryImageService({
    http.Client? httpClient,
    CloudinaryConfig? config,
    this.maxBytes = kPantryImageMaxBytes,
  }) : _client = httpClient ?? http.Client(),
       _ownsClient = httpClient == null,
       _config = config ?? CloudinaryConfig.fromEnvironment();

  final http.Client _client;
  final bool _ownsClient;
  final CloudinaryConfig _config;
  final int maxBytes;

  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  static const Set<String> _allowedMimes = {
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
  };

  /// Closes the HTTP client only when this service created it.
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<PantryImageUploadResult> uploadPantryImage({
    required String userId,
    required XFile photo,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) {
      throw const PantryFirestoreException(kPantrySignInRequiredMessage);
    }

    _assertSupportedPhoto(photo);
    final bytes = await photo.readAsBytes();
    if (bytes.length > maxBytes) {
      throw const PantryFirestoreException(kPantryImageTooLargeMessage);
    }
    if (!_config.isConfigured) {
      throw const PantryImageConfigurationException();
    }

    final cloudName = _config.cloudName.trim();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
    );
    request.fields['upload_preset'] = _config.uploadPreset.trim();
    request.fields['folder'] = 'freshtrack/pantry/$uid';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: _fileName(photo)),
    );

    try {
      final streamed = await _client.send(request);
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        debugPrint(
          'Pantry Cloudinary upload failed with status ${streamed.statusCode}',
        );
        throw const PantryImageUploadException();
      }
      return _parseUploadBody(body);
    } on PantryFirestoreException {
      rethrow;
    } catch (error) {
      debugPrint('Pantry Cloudinary upload failed: $error');
      throw const PantryImageUploadException();
    }
  }

  PantryImageUploadResult _parseUploadBody(String body) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (error) {
      debugPrint('Pantry Cloudinary response was not JSON');
      throw const PantryImageUploadException();
    }
    if (decoded is! Map) {
      throw const PantryImageUploadException();
    }

    final secureUrl = decoded['secure_url'];
    final publicId = decoded['public_id'];
    final uri = secureUrl is String ? Uri.tryParse(secureUrl.trim()) : null;
    final id = publicId is String ? publicId.trim() : '';
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        id.isEmpty) {
      debugPrint('Pantry Cloudinary response was missing a secure URL or id');
      throw const PantryImageUploadException();
    }

    return PantryImageUploadResult(
      secureUrl: uri.toString(),
      publicId: id,
      width: _optionalInt(decoded['width']),
      height: _optionalInt(decoded['height']),
      format: decoded['format'] is String ? decoded['format'] as String : null,
    );
  }

  void _assertSupportedPhoto(XFile photo) {
    final mime = photo.mimeType?.toLowerCase().trim() ?? '';
    final extension = _extensionOf(
      photo.name.trim().isNotEmpty ? photo.name : photo.path,
    );

    if (extension != null && !_allowedExtensions.contains(extension)) {
      throw const PantryFirestoreException(kPantryImageTypeMessage);
    }
    if (mime.isNotEmpty && !_allowedMimes.contains(mime)) {
      throw const PantryFirestoreException(kPantryImageTypeMessage);
    }
    if (extension == null && !_allowedMimes.contains(mime)) {
      throw const PantryFirestoreException(kPantryImageTypeMessage);
    }
  }

  String _fileName(XFile photo) {
    final name = photo.name.trim();
    if (name.isNotEmpty) return name;
    switch (_extensionOf(photo.path)) {
      case 'png':
        return 'photo.png';
      case 'webp':
        return 'photo.webp';
      default:
        return 'photo.jpg';
    }
  }

  String? _extensionOf(String value) {
    final dot = value.lastIndexOf('.');
    if (dot < 0 || dot == value.length - 1) return null;
    return value.substring(dot + 1).toLowerCase();
  }

  int? _optionalInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
