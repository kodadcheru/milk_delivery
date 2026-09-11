import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'api_service.dart';

class ImageUploadService {
  static String get _uploadUrl => '${ApiService.baseUrl}/upload/image/';

  /// Upload raw image bytes using multipart/form-data with auto-token refresh
  static Future<String?> uploadImageBytes({
    required Uint8List bytes,
    required String filename,
    String folder = 'proofs',
    Map<String, String>? extraFields,
    bool isRetry = false,
  }) async {
    try {
      if (ApiService.authToken == null) {
        await ApiService.initAuthToken();
      }

      final uri = Uri.parse(_uploadUrl);
      final request = http.MultipartRequest('POST', uri);

      if (ApiService.authToken != null) {
        request.headers['Authorization'] = 'Bearer ${ApiService.authToken}';
      }

      // Determine mime type based on extension
      String mimeType = 'image/jpeg';
      if (filename.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else if (filename.toLowerCase().endsWith('.webp')) {
        mimeType = 'image/webp';
      }

      final parts = mimeType.split('/');
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: filename,
        contentType: MediaType(parts[0], parts[1]),
      );

      request.files.add(multipartFile);
      request.fields['folder'] = folder;

      if (extraFields != null) {
        request.fields.addAll(extraFields);
      }

      final streamedResponse = await request.send().timeout(AppConfig.imageUploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      // Auto-refresh token on 401
      if (response.statusCode == 401 && !isRetry) {
        final refreshed = await ApiService.refreshAuthToken();
        if (refreshed) {
          return await uploadImageBytes(
            bytes: bytes,
            filename: filename,
            folder: folder,
            extraFields: extraFields,
            isRetry: true,
          );
        }
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawUrl = data['url'] as String?;
        return AppConfig.normalizeImageUrl(rawUrl);
      } else {
        throw Exception('Upload failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[ImageUploadService] uploadImageBytes error: $e');
      rethrow;
    }
  }

  /// Upload base64 encoded image string as JSON payload with auto-token refresh
  static Future<String?> uploadImageBase64({
    required String base64Image,
    required String filename,
    String folder = 'proofs',
    bool isRetry = false,
  }) async {
    try {
      if (ApiService.authToken == null) {
        await ApiService.initAuthToken();
      }

      final res = await http.post(
        Uri.parse(_uploadUrl),
        headers: {
          'Content-Type': 'application/json',
          if (ApiService.authToken != null) 'Authorization': 'Bearer ${ApiService.authToken}',
        },
        body: jsonEncode({
          'base64_image': base64Image,
          'filename': filename,
          'folder': folder,
        }),
      ).timeout(AppConfig.imageUploadTimeout);

      // Auto-refresh token on 401
      if (res.statusCode == 401 && !isRetry) {
        final refreshed = await ApiService.refreshAuthToken();
        if (refreshed) {
          return await uploadImageBase64(
            base64Image: base64Image,
            filename: filename,
            folder: folder,
            isRetry: true,
          );
        }
      }

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawUrl = data['url'] as String?;
        return AppConfig.normalizeImageUrl(rawUrl);
      } else {
        throw Exception('Upload failed with status ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('[ImageUploadService] uploadImageBase64 error: $e');
      rethrow;
    }
  }
}
