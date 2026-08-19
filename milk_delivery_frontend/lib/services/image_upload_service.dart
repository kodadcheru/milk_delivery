import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/app_config.dart';
import 'api_service.dart';

class ImageUploadService {
  static String get _uploadUrl => '${ApiService.baseUrl}/upload/image/';

  /// Upload raw image bytes using multipart/form-data
  static Future<String?> uploadImageBytes({
    required Uint8List bytes,
    required String filename,
    String folder = 'proofs',
    Map<String, String>? extraFields,
  }) async {
    try {
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

      final streamedResponse = await request.send().timeout(AppConfig.requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Upload base64 encoded image string as JSON payload
  static Future<String?> uploadImageBase64({
    required String base64Image,
    required String filename,
    String folder = 'proofs',
  }) async {
    try {
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
      ).timeout(AppConfig.requestTimeout);

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['url'] as String?;
      }
    } catch (_) {}
    return null;
  }
}
