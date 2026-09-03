import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import '../models/customer_address_model.dart';
import '../models/product_model.dart';
import '../models/subscription_model.dart';
import '../models/delivery_task_model.dart';
import '../models/wallet_transaction_model.dart';
import '../models/notification_model.dart';
import '../models/live_order_model.dart';
import '../models/bottle_return_model.dart';
import '../models/provider_payout_model.dart';
import '../models/provider_earnings_summary_model.dart';
import '../models/storefront_config_model.dart';
import '../models/category_model.dart';
import 'image_upload_service.dart';

/// Exception type for API errors — screens can catch this to show meaningful messages
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;
  static String? authToken;
  static String? refreshToken;
  static final http.Client _client = http.Client();
  
  /// Last error message from any API call — UI can read this for error display
  static String? lastError;

  static String _extractErrorMsg(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        return (body['detail'] ?? body['error'] ?? body['message'] ?? res.body).toString();
      }
      return res.body;
    } catch (_) {
      return 'Error ${res.statusCode}: ${res.reasonPhrase}';
    }
  }

  static const String _prefTokenKey = 'pamba_auth_token';
  static const String _prefRefreshTokenKey = 'pamba_refresh_token';
  static const String _prefUserKey = 'pamba_user_data';
  // Legacy keys for backwards-compatible migration
  static const String _legacyPrefTokenKey = 'milkdrop_auth_token';
  static const String _legacyPrefRefreshTokenKey = 'milkdrop_refresh_token';
  static const String _legacyPrefUserKey = 'milkdrop_user_data';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  /// Initialize and restore stored tokens from SharedPreferences (with migration)
  static Future<String?> initAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      authToken = prefs.getString(_prefTokenKey) ?? prefs.getString(_legacyPrefTokenKey);
      refreshToken = prefs.getString(_prefRefreshTokenKey) ?? prefs.getString(_legacyPrefRefreshTokenKey);

      // Seamless migration to new pamba keys
      if (authToken != null && !prefs.containsKey(_prefTokenKey)) {
        await prefs.setString(_prefTokenKey, authToken!);
      }
      if (refreshToken != null && !prefs.containsKey(_prefRefreshTokenKey)) {
        await prefs.setString(_prefRefreshTokenKey, refreshToken!);
      }

      return authToken;
    } catch (_) {
      return null;
    }
  }

  /// Save tokens to persistent storage
  static Future<void> saveAuthToken(String token, {String? refresh}) async {
    authToken = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefTokenKey, token);
      if (refresh != null) {
        refreshToken = refresh;
        await prefs.setString(_prefRefreshTokenKey, refresh);
      }
    } catch (e) { lastError = e.toString(); }
  }

  /// Refresh JWT Access Token using Refresh Token
  static Future<bool> refreshAuthToken() async {
    if (refreshToken == null || refreshToken!.isEmpty) return false;
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/auth/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      ).timeout(AppConfig.requestTimeout);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data['access'] != null) {
          authToken = data['access'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefTokenKey, authToken!);
          if (data['refresh'] != null) {
            refreshToken = data['refresh'];
            await prefs.setString(_prefRefreshTokenKey, refreshToken!);
          }
          return true;
        }
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  /// Clear persistent token and user on logout
  static Future<void> clearAuthToken() async {
    authToken = null;
    refreshToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefTokenKey);
      await prefs.remove(_prefRefreshTokenKey);
      await prefs.remove(_prefUserKey);
      await prefs.remove(_legacyPrefTokenKey);
      await prefs.remove(_legacyPrefRefreshTokenKey);
      await prefs.remove(_legacyPrefUserKey);
    } catch (e) { lastError = e.toString(); }
  }

  /// Helper with retry, exponential backoff, and transparent JWT refresh on 401
  static Future<http.Response> _executeWithRetry(Future<http.Response> Function() action) async {
    int attempts = 0;
    bool hasRefreshed = false;

    while (true) {
      try {
        attempts++;
        final response = await action().timeout(AppConfig.requestTimeout);

        // Auto-refresh token if 401 Unauthorized encountered
        if (response.statusCode == 401 && !hasRefreshed && refreshToken != null) {
          hasRefreshed = true;
          final refreshed = await refreshAuthToken();
          if (refreshed) {
            // Re-run action with updated Authorization header
            return await action().timeout(AppConfig.requestTimeout);
          }
        }

        return response;
      } catch (e) {
        if (attempts >= AppConfig.maxRetryAttempts) {
          rethrow;
        }
        await Future.delayed(AppConfig.retryDelay * attempts);
      }
    }
  }

  // ── 1. Phone OTP & Mobile Auth ──
  static Future<Map<String, dynamic>> sendOTP(String phone) async {
    try {
      final res = await _executeWithRetry(() => _client.post(
            Uri.parse('$baseUrl/auth/send-otp/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone}),
          ));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body);
      } else {
        final err = jsonDecode(res.body);
        lastError = _extractErrorMsg(res);
        return {'success': false, 'error': err['detail'] ?? err['message'] ?? 'Failed to send OTP'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network connection error. Please check your connection.'};
    }
  }

  static Future<Map<String, dynamic>> verifyOTP(String phone, String otp) async {
    try {
      final res = await _executeWithRetry(() => _client.post(
            Uri.parse('$baseUrl/auth/verify-otp/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'otp': otp}),
          ));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['access'] != null) {
          await saveAuthToken(data['access'], refresh: data['refresh']);
        }
        return data;
      } else {
        final err = jsonDecode(res.body);
        return {'success': false, 'error': err['message'] ?? err['detail'] ?? 'Invalid OTP code'};
      }
    } catch (_) {
      return {'success': false, 'error': 'Network connection error. Please try again.'};
    }
  }

  static Future<Map<String, dynamic>> registerMobileUser({
    required String phone,
    required String firstName,
    required String email,
    required String gender,
    String address = '',
    String deliveryInstructions = '',
  }) async {
    try {
      final res = await _executeWithRetry(() => _client.post(
            Uri.parse('$baseUrl/auth/register-mobile/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phone,
              'first_name': firstName,
              'email': email,
              'gender': gender,
              'address': address,
              'delivery_instructions': deliveryInstructions,
            }),
          ));

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['access'] != null) {
          await saveAuthToken(data['access'], refresh: data['refresh']);
        }
        return data;
      } else {
        final err = jsonDecode(res.body);
        return {'success': false, 'error': err['detail'] ?? err['message'] ?? 'Registration failed'};
      }
    } catch (_) {
      return {'success': false, 'error': 'Network connection error. Please try again.'};
    }
  }


  // ── 2. Standard Auth & Profile ──
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final res = await _executeWithRetry(() => _client.post(
            Uri.parse('$baseUrl/auth/token/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          ));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        await saveAuthToken(data['access'], refresh: data['refresh']);
        return {'success': true, 'token': data['access']};
      } else {
        lastError = _extractErrorMsg(res);
      }

    } catch (e) { lastError = e.toString(); }

      return {'success': false, 'error': lastError ?? 'Failed to connect to backend'};
  }

  static Future<UserModel?> fetchUserProfile() async {
    if (authToken == null) return null;
    try {
      final res = await _executeWithRetry(() => _client.get(Uri.parse('$baseUrl/auth/me/'), headers: _headers));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return UserModel.fromJson(jsonDecode(res.body));
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return null;
  }

  static Future<UserModel?> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      final res = await _executeWithRetry(() => _client.patch(
            Uri.parse('$baseUrl/auth/me/'),
            headers: _headers,
            body: jsonEncode(updates),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return UserModel.fromJson(jsonDecode(res.body));
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return null;
  }

  static List _extractList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['results'] is List) {
      return decoded['results'] as List;
    }
    return [];
  }

  // ── 3. Notifications ──
  static Future<List<NotificationModel>> fetchNotifications({int? page, int? pageSize}) async {
    try {
      final queryParams = <String, String>{};
      if (page != null) queryParams['page'] = page.toString();
      if (pageSize != null) queryParams['page_size'] = pageSize.toString();

      final uri = Uri.parse('$baseUrl/notifications/').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final res = await _executeWithRetry(() => http.get(uri, headers: _headers));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final list = _extractList(jsonDecode(res.body));
        return list.map((e) => NotificationModel.fromJson(e)).toList();
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return [];
  }

  static Future<bool> markNotificationRead(int id) async {
    try {
      final res = await _executeWithRetry(() => http.post(Uri.parse('$baseUrl/notifications/$id/read/'), headers: _headers));
      return res.statusCode == 200;
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  static Future<bool> markAllNotificationsRead() async {
    try {
      final res = await _executeWithRetry(() => http.post(Uri.parse('$baseUrl/notifications/read-all/'), headers: _headers));
      return res.statusCode == 200;
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  // ── 4. Products & Categories ──
  static Future<List<CategoryModel>> fetchCategories() async {
    try {
      final res = await _executeWithRetry(() => http.get(
            Uri.parse('$baseUrl/categories/'),
            headers: _headers,
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final list = _extractList(jsonDecode(res.body));
        return list.map((e) => CategoryModel.fromJson(e)).toList();
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) {
      lastError = e.toString();
    }
    return [];
  }

  static Future<List<ProductModel>> fetchProducts({
    int? page,
    int? pageSize,
    String? category,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (page != null) queryParams['page'] = page.toString();
      if (pageSize != null) queryParams['page_size'] = pageSize.toString();
      if (category != null && category != 'ALL') queryParams['category'] = category;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/products/').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final res = await _executeWithRetry(() => http.get(uri));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final list = _extractList(jsonDecode(res.body));
        return list.map((e) => ProductModel.fromJson(e)).toList();
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return [];
  }

  static Future<ProductModel?> createProduct(
    String name,
    String description,
    double price,
    String unitQty,
    String imageUrl, {
    String category = 'MILK',
    int? categoryId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name,
        'description': description,
        'category': category,
        'price_per_unit': price.toStringAsFixed(2),
        'unit_quantity': unitQty,
        'image_url': imageUrl,
        'is_available': true,
      };
      if (categoryId != null && categoryId > 0) {
        payload['category_id'] = categoryId;
      }
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/products/'),
            headers: _headers,
            body: jsonEncode(payload),
          ));
      if (res.statusCode == 201) {
        return ProductModel.fromJson(jsonDecode(res.body));
      }
    } catch (e) { lastError = e.toString(); }
    return null;
  }

  static Future<bool> toggleProductStock(int productId) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/admin/products/$productId/toggle-stock/'),
            headers: _headers,
          ));
      return res.statusCode == 200;
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  // ── 5. Subscriptions ──
  static Future<List<SubscriptionModel>> fetchSubscriptions({String? phone, int? customerId, String? hubCode}) async {
    try {
      final queryParams = <String, String>{};
      if (phone != null) queryParams['phone'] = phone;
      if (customerId != null) queryParams['customer_id'] = customerId.toString();
      if (hubCode != null) queryParams['hub_code'] = hubCode;
      
      final uri = Uri.parse('$baseUrl/subscriptions/').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final res = await _executeWithRetry(() => http.get(uri, headers: _headers));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final list = _extractList(jsonDecode(res.body));
        return list.map((e) => SubscriptionModel.fromJson(e)).toList();
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return [];
  }

  static Future<SubscriptionModel?> createSubscription(
    int productId,
    int quantity,
    String scheduleType, {
    int? customerId,
    String? customerPhone,
    String? deliveryAddress,
    String? deliverySlot,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryInstructions,
    String? packSize,
  }) async {
    try {
      final todayStr = DateTime.now().toString().split(' ')[0];
      final Map<String, dynamic> payload = {
        'product': productId,
        'quantity': quantity,
        'schedule_type': scheduleType,
        'start_date': todayStr,
      };
      if (customerId != null) payload['customer_id'] = customerId;
      if (customerPhone != null) payload['customer_phone'] = customerPhone;
      if (deliveryAddress != null) payload['delivery_address'] = deliveryAddress;
      if (deliverySlot != null) payload['delivery_slot'] = deliverySlot;
      if (deliveryLatitude != null) payload['delivery_latitude'] = double.tryParse(deliveryLatitude.toStringAsFixed(6)) ?? deliveryLatitude;
      if (deliveryLongitude != null) payload['delivery_longitude'] = double.tryParse(deliveryLongitude.toStringAsFixed(6)) ?? deliveryLongitude;
      if (deliveryInstructions != null) payload['delivery_instructions'] = deliveryInstructions;
      if (packSize != null) payload['pack_size'] = packSize;

      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/subscriptions/'),
            headers: _headers,
            body: jsonEncode(payload),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return SubscriptionModel.fromJson(jsonDecode(res.body));
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return null;
  }

  static Future<bool> pauseSubscription(int subId, String startDate, String endDate) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/subscriptions/$subId/pause/'),
            headers: _headers,
            body: jsonEncode({'start_date': startDate, 'end_date': endDate, 'reason': 'Vacation Mode'}),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  static Future<bool> resumeSubscription(int subId) async {
    try {
      final res = await _executeWithRetry(() => http.post(Uri.parse('$baseUrl/subscriptions/$subId/resume/'), headers: _headers));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  static Future<bool> cancelSubscription(int subId) async {
    try {
      final res = await _executeWithRetry(() => http.delete(Uri.parse('$baseUrl/subscriptions/$subId/'), headers: _headers));
      if (res.statusCode == 204 || res.statusCode == 200) {
        return true;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  static Future<bool> reactivateSubscription(int subId) async {
    try {
      final res = await _executeWithRetry(() => http.patch(
        Uri.parse('$baseUrl/subscriptions/$subId/'),
        headers: _headers,
        body: jsonEncode({'status': 'ACTIVE'}),
      ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  static Future<bool> updateSubscription(
    int subId, {
    int? quantity,
    String? scheduleType,
    String? deliveryAddress,
    String? deliverySlot,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryInstructions,
    String? packSize,
  }) async {
    try {
      final bodyMap = <String, dynamic>{};
      if (quantity != null) bodyMap['quantity'] = quantity;
      if (scheduleType != null) bodyMap['schedule_type'] = scheduleType;
      if (deliveryAddress != null) bodyMap['delivery_address'] = deliveryAddress;
      if (deliverySlot != null) bodyMap['delivery_slot'] = deliverySlot;
      if (deliveryLatitude != null) bodyMap['delivery_latitude'] = double.tryParse(deliveryLatitude.toStringAsFixed(6)) ?? deliveryLatitude;
      if (deliveryLongitude != null) bodyMap['delivery_longitude'] = double.tryParse(deliveryLongitude.toStringAsFixed(6)) ?? deliveryLongitude;
      if (deliveryInstructions != null) bodyMap['delivery_instructions'] = deliveryInstructions;
      if (packSize != null) bodyMap['pack_size'] = packSize;

      final res = await _executeWithRetry(() => http.patch(
            Uri.parse('$baseUrl/subscriptions/$subId/'),
            headers: _headers,
            body: jsonEncode(bodyMap),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  // ── 6. Wallet & Transactions ──
  static Future<bool> topUpWallet(double amount, String description) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/wallet/topup/'),
            headers: _headers,
            body: jsonEncode({'amount': amount.toStringAsFixed(2), 'description': description}),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  static Future<List<WalletTransactionModel>> fetchWalletTransactions({int? page, int? pageSize}) async {
    try {
      final queryParams = <String, String>{};
      if (page != null) queryParams['page'] = page.toString();
      if (pageSize != null) queryParams['page_size'] = pageSize.toString();

      final uri = Uri.parse('$baseUrl/wallet/transactions/').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final res = await _executeWithRetry(() => http.get(uri, headers: _headers));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final list = _extractList(jsonDecode(res.body));
        return list.map((e) => WalletTransactionModel.fromJson(e)).toList();
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return [];
  }

  // ── 7. Delivery Tasks ──
  static Future<List<DeliveryTaskModel>> fetchDeliveries({int? page, int? pageSize, String? date, String? hubCode}) async {
    try {
      final queryParams = <String, String>{};
      if (page != null) queryParams['page'] = page.toString();
      if (date != null && date.trim().isNotEmpty) {
        queryParams['date'] = date.trim();
      }
      if (hubCode != null && hubCode.isNotEmpty) queryParams['hub_code'] = hubCode;

      final uri = Uri.parse('$baseUrl/deliveries/').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final res = await _executeWithRetry(() => http.get(uri, headers: _headers));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final list = _extractList(jsonDecode(res.body));
        return list.map((e) => DeliveryTaskModel.fromJson(e)).toList();
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return [];
  }

  static Future<bool> completeDelivery(int taskId, String proofUrl) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/deliveries/$taskId/complete/'),
            headers: _headers,
            body: jsonEncode({'proof_image_url': proofUrl}),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  static Future<bool> skipDelivery(int taskId, {String? reason}) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/deliveries/$taskId/skip/'),
            headers: _headers,
            body: jsonEncode({if (reason != null && reason.isNotEmpty) 'reason': reason}),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  // ── 8. Delivery Reassignment & Hub Fleet Balancing ──
  static Future<bool> reassignDeliveryTask(int taskId, int? driverId) async {
    try {
      final res = await _executeWithRetry(() => http.patch(
            Uri.parse('$baseUrl/admin/deliveries/$taskId/reassign/'),
            headers: _headers,
            body: jsonEncode({'driver_id': driverId}),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) {
      lastError = e.toString();
    }
    return false;
  }

  static Future<bool> reassignDeliveryTasksBatch(List<int> taskIds, int? driverId) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/admin/deliveries/reassign/'),
            headers: _headers,
            body: jsonEncode({
              'task_ids': taskIds,
              'driver_id': driverId,
            }),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) {
      lastError = e.toString();
    }
    return false;
  }

  static Future<Map<String, dynamic>?> rebalanceHubDeliveries(String hubCode, {int? driverCount}) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/admin/hubs/$hubCode/rebalance/'),
            headers: _headers,
            body: driverCount != null ? jsonEncode({'driver_count': driverCount}) : null,
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) {
      lastError = e.toString();
    }
    return null;
  }

  // ── 9. Admin Analytics Summary ──
  static Future<Map<String, dynamic>?> fetchDeliverySummary() async {
    try {
      final res = await _executeWithRetry(() => http.get(Uri.parse('$baseUrl/deliveries/summary/'), headers: _headers));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return null;
  }

  // ── 9. Geofenced Service Areas ──
  static Future<List<Map<String, dynamic>>> fetchServiceAreas() async {
    try {
      final res = await _executeWithRetry(() => http.get(Uri.parse('$baseUrl/service-areas/'), headers: _headers));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final List list = jsonDecode(res.body);
        return list.cast<Map<String, dynamic>>();
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return [];
  }

  // ── 10. Location Hubs ──
  static Future<List<Map<String, dynamic>>> fetchHubs() async {
    try {
      final res = await _executeWithRetry(() => http.get(Uri.parse('$baseUrl/admin/hubs/'), headers: _headers));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final List list = jsonDecode(res.body);
        return list.cast<Map<String, dynamic>>();
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return [];
  }

  static Future<bool> adminCreditWallet({int? userId, required double amount, required String description}) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/admin/credit-wallet/'),
            headers: _headers,
            body: jsonEncode({
              'user_id': ?userId,
              'amount': amount,
              'description': description,
            }),
          ));
      return res.statusCode == 200;
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  // ── 11. Salaried Delivery Fleet & Hub Onboarding ──
  static Future<List<Map<String, dynamic>>> fetchFleet({int? hubId}) async {
    try {
      final url = hubId != null ? '$baseUrl/admin/fleet/?hub_id=$hubId' : '$baseUrl/admin/fleet/';
      final res = await _executeWithRetry(() => http.get(Uri.parse(url), headers: _headers));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final List list = jsonDecode(res.body);
        return list.cast<Map<String, dynamic>>();
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return [];
  }


  static Future<Map<String, dynamic>?> createDriver({
    String? firstName,
    String? lastName,
    String? name,
    required String phone,
    String? vehicleNumber,
    int? hubId,
    double monthlySalary = 15000.0,
  }) async {
    try {
      final nameParts = (name ?? '').trim().split(' ');
      final fName = firstName ?? (nameParts.isNotEmpty ? nameParts.first : 'Partner');
      final lName = lastName ?? (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Partner');

      final res = await _executeWithRetry(() => _client.post(
            Uri.parse('$baseUrl/admin/fleet/create-driver/'),
            headers: _headers,
            body: jsonEncode({
              'first_name': fName,
              'last_name': lName,
              'phone': phone,
              if (vehicleNumber != null) 'vehicle_number': vehicleNumber,
              'hub_id': hubId ?? 1,
              'monthly_salary': monthlySalary,
            }),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body);
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return null;
  }

  static Future<bool> updateDriverStatus(int driverId, String driverStatus) async {
    try {
      final res = await _executeWithRetry(() => http.patch(
            Uri.parse('$baseUrl/admin/fleet/$driverId/'),
            headers: _headers,
            body: jsonEncode({'driver_status': driverStatus}),
          ));
      return res.statusCode == 200;
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  static Future<bool> updateDriverLocation({
    required double latitude,
    required double longitude,
    String status = 'ON_DUTY',
  }) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/driver/location/'),
            headers: _headers,
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
              'status': status,
            }),
          ));
      return res.statusCode == 200;
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  static Future<Map<String, dynamic>?> fetchDriverLiveLocation({String? orderId, int? driverId}) async {
    try {
      final target = orderId?.trim().isNotEmpty == true
          ? orderId!.trim()
          : (driverId != null ? driverId.toString() : 'active');
      final res = await _executeWithRetry(() => http.get(
            Uri.parse('$baseUrl/driver/location/$target/'),
            headers: _headers,
          ));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      lastError = e.toString();
    }
    return null;
  }

  static Future<bool> updateHubDetails({
    required String hubCode,
    String? name,
    String? address,
    String? managerName,
    String? managerPhone,
    double? coverageRadiusKm,
    String? bankName,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankAccountHolder,
    String? upiId,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (address != null) body['address'] = address;
      if (managerName != null) body['manager_name'] = managerName;
      if (managerPhone != null) body['manager_phone'] = managerPhone;
      if (coverageRadiusKm != null) body['coverage_radius_km'] = coverageRadiusKm;
      if (bankName != null) body['bank_name'] = bankName;
      if (bankAccountNumber != null) body['bank_account_number'] = bankAccountNumber;
      if (bankIfsc != null) body['bank_ifsc'] = bankIfsc;
      if (bankAccountHolder != null) body['bank_account_holder'] = bankAccountHolder;
      if (upiId != null) body['upi_id'] = upiId;

      final res = await _executeWithRetry(() => http.patch(
            Uri.parse('$baseUrl/admin/hubs/$hubCode/'),
            headers: _headers,
            body: jsonEncode(body),
          ));
      return res.statusCode == 200;
    } catch (e) {
      lastError = e.toString();
    }
    return false;
  }

  static Future<List<Map<String, dynamic>>> fetchSlotAvailability({int? hubId, String? date}) async {
    try {
      final params = <String, String>{};
      if (hubId != null) params['hub_id'] = hubId.toString();
      if (date != null) params['date'] = date;
      final uri = Uri.parse('$baseUrl/slots/availability/').replace(queryParameters: params.isNotEmpty ? params : null);
      final res = await _executeWithRetry(() => http.get(uri, headers: _headers));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final List decoded = jsonDecode(res.body);
        return decoded.cast<Map<String, dynamic>>();
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return [];
  }

  // ── 12. Customer Address Book APIs ──
  static Future<List<CustomerAddressModel>> fetchCustomerAddresses({int? customerId, String? phone}) async {
    try {
      final queryParams = <String, String>{};
      if (customerId != null) queryParams['customer_id'] = customerId.toString();
      if (phone != null && phone.isNotEmpty) queryParams['phone'] = phone;

      final uri = Uri.parse('$baseUrl/accounts/addresses/').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final res = await _executeWithRetry(() => http.get(
            uri,
            headers: _headers,
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final dynamic decoded = jsonDecode(res.body);
        final List list = decoded is Map && decoded.containsKey('results')
            ? (decoded['results'] as List)
            : (decoded as List);
        return list.map((item) => CustomerAddressModel.fromJson(item)).toList();
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return [];
  }

  static Future<CustomerAddressModel?> createCustomerAddress(
    CustomerAddressModel address, {
    String? phone,
    int? customerId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (phone != null && phone.isNotEmpty) queryParams['phone'] = phone;
      if (customerId != null && customerId > 0) queryParams['customer_id'] = customerId.toString();

      final uri = Uri.parse('$baseUrl/accounts/addresses/').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final payload = address.toJson();
      if (address.id <= 0) {
        payload.remove('id');
      }
      final resolvedUid = customerId ?? address.userId;
      if (resolvedUid != null && resolvedUid > 0) {
        payload['user'] = resolvedUid;
        payload['user_id'] = resolvedUid;
        payload['customer_id'] = resolvedUid;
      }

      final res = await _executeWithRetry(() => http.post(
            uri,
            headers: _headers,
            body: jsonEncode(payload),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return CustomerAddressModel.fromJson(jsonDecode(res.body));
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return null;
  }

  static Future<CustomerAddressModel?> updateCustomerAddress(
    CustomerAddressModel address, {
    String? phone,
    int? customerId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (phone != null && phone.isNotEmpty) queryParams['phone'] = phone;
      if (customerId != null && customerId > 0) queryParams['customer_id'] = customerId.toString();

      final uri = Uri.parse('$baseUrl/accounts/addresses/${address.id}/').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final payload = address.toJson();
      final resolvedUid = customerId ?? address.userId;
      if (resolvedUid != null && resolvedUid > 0) {
        payload['user'] = resolvedUid;
        payload['user_id'] = resolvedUid;
        payload['customer_id'] = resolvedUid;
      }

      final res = await _executeWithRetry(() => http.patch(
            uri,
            headers: _headers,
            body: jsonEncode(payload),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return CustomerAddressModel.fromJson(jsonDecode(res.body));
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return null;
  }

  static Future<bool> deleteCustomerAddress(int addressId) async {
    try {
      final res = await _executeWithRetry(() => http.delete(
            Uri.parse('$baseUrl/accounts/addresses/$addressId/'),
            headers: _headers,
          ));
      return res.statusCode == 204 || res.statusCode == 200;
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  static Future<bool> setDefaultCustomerAddress(int addressId) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/accounts/addresses/$addressId/set-default/'),
            headers: _headers,
          ));
      return res.statusCode == 200;
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  // ── 13. Express / Live Orders APIs ──
  static Future<List<LiveOrderModel>> fetchLiveOrders({int? page, int? pageSize, String? status, String? hubCode}) async {
    try {
      final queryParams = <String, String>{};
      if (page != null) queryParams['page'] = page.toString();
      if (pageSize != null) queryParams['page_size'] = pageSize.toString();
      if (status != null) queryParams['status'] = status;
      if (hubCode != null) queryParams['hub_code'] = hubCode;

      final uri = Uri.parse('$baseUrl/orders/express/').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final res = await _executeWithRetry(() => http.get(
            uri,
            headers: _headers,
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final list = _extractList(jsonDecode(res.body));
        return list.map((item) => LiveOrderModel.fromJson(item)).toList();
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return [];
  }

  static Future<LiveOrderModel?> createExpressOrder({
    required List<Map<String, dynamic>> items,
    String? deliveryDate,
    String? deliverySlot,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String deliveryType = 'SCHEDULED',
    String paymentMethod = 'WALLET',
  }) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/orders/express/'),
            headers: _headers,
            body: jsonEncode({
              'items': items,
              'delivery_date': ?deliveryDate,
              'delivery_slot': ?deliverySlot,
              'delivery_address': ?deliveryAddress,
              'delivery_latitude': deliveryLatitude != null ? (double.tryParse(deliveryLatitude.toStringAsFixed(6)) ?? deliveryLatitude) : null,
              'delivery_longitude': deliveryLongitude != null ? (double.tryParse(deliveryLongitude.toStringAsFixed(6)) ?? deliveryLongitude) : null,
              'delivery_type': deliveryType,
              'payment_method': paymentMethod,
            }),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return LiveOrderModel.fromJson(jsonDecode(res.body));
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return null;
  }

  static Future<LiveOrderModel?> updateLiveOrderStatus(String orderId, String newStatus, {String? proofImageUrl, String? deliveryOtp}) async {
    try {
      final body = <String, dynamic>{'status': newStatus};
      if (proofImageUrl != null) body['proof_image_url'] = proofImageUrl;
      if (deliveryOtp != null) body['delivery_otp'] = deliveryOtp;

      final res = await _executeWithRetry(() => http.patch(
            Uri.parse('$baseUrl/orders/express/$orderId/'),
            headers: _headers,
            body: jsonEncode(body),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return LiveOrderModel.fromJson(jsonDecode(res.body));
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return null;
  }

  // ── 14. Admin Operations & Driver Management ──


  static Future<Map<String, dynamic>?> generateTodayTasks({
    String? date,
    String? productName,
    double? fatPercentage,
    double? snfPercentage,
    double? waterPercentage,
    double? pricePerLitre,
    double? totalLitres,
    double? temperatureCelsius,
    String? hubCode,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (date != null) body['date'] = date;
      if (productName != null) body['product_name'] = productName;
      if (fatPercentage != null) body['fat_percentage'] = fatPercentage;
      if (snfPercentage != null) body['snf_percentage'] = snfPercentage;
      if (waterPercentage != null) body['water_percentage'] = waterPercentage;
      if (pricePerLitre != null) body['price_per_litre'] = pricePerLitre;
      if (totalLitres != null) body['total_litres'] = totalLitres;
      if (temperatureCelsius != null) body['temperature_celsius'] = temperatureCelsius;
      if (hubCode != null) body['hub_code'] = hubCode;

      final res = await _executeWithRetry(() => _client.post(
            Uri.parse('$baseUrl/admin/generate-tasks/'),
            headers: _headers,
            body: jsonEncode(body),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return null;
  }

  static Future<bool> sendBroadcastAlert(String title, String message, {String targetRole = 'ALL'}) async {
    try {
      final res = await _executeWithRetry(() => _client.post(
            Uri.parse('$baseUrl/admin/broadcast-notification/'),
            headers: _headers,
            body: jsonEncode({
              'title': title,
              'message': message,
              'target_role': targetRole,
            }),
          ));
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  // ── 15. Media & Image Upload Service ──
  static Future<String?> uploadImage(Uint8List bytes, String filename, {String folder = 'proofs'}) async {
    return ImageUploadService.uploadImageBytes(
      bytes: bytes,
      filename: filename,
      folder: folder,
    );
  }

  // ── Hub Inventory / Capacity ──

  static Future<List<Map<String, dynamic>>> fetchHubInventory() async {
    try {
      final res = await _executeWithRetry(() => http.get(
            Uri.parse('$baseUrl/hub-inventory/'),
            headers: _headers,
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return [];
  }

  static Future<Map<String, dynamic>?> updateHubInventory({
    required int productId,
    required int dailyCapacitySlots,
    bool? isAvailable,
    int? hubId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'product_id': productId,
        'daily_capacity_slots': dailyCapacitySlots,
      };
      if (isAvailable != null) payload['is_available'] = isAvailable;
      if (hubId != null) payload['hub_id'] = hubId;

      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/hub-inventory/'),
            headers: _headers,
            body: jsonEncode(payload),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(res.body));
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return null;
  }

  // ── Hub Daily Milk Batch & Quality Lab Certifications ──

  static Future<List<Map<String, dynamic>>> fetchQualityHistory() async {
    try {
      final res = await _executeWithRetry(() => http.get(
        Uri.parse('$baseUrl/deliveries/quality-history/'),
        headers: _headers,
      ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final List decoded = jsonDecode(res.body);
        return decoded.cast<Map<String, dynamic>>();
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchDailyMilkBatches({String? date, String? productName, String? hubCode}) async {
    try {
      final queryParams = <String, String>{};
      if (date != null) queryParams['date'] = date;
      if (productName != null) queryParams['product'] = productName;
      if (hubCode != null) queryParams['hub_code'] = hubCode;

      final uri = Uri.parse('$baseUrl/deliveries/daily-batches/').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final res = await _executeWithRetry(() => http.get(uri, headers: _headers));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['batches'] is List) {
          return List<Map<String, dynamic>>.from(decoded['batches']);
        } else if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) {
      lastError = e.toString();
    }
    return [];
  }

  static Future<Map<String, dynamic>?> submitDailyMilkBatch({
    required String productName,
    required double fatPercentage,
    required double snfPercentage,
    required double waterPercentage,
    required double pricePerLitre,
    required double totalLitres,
    double temperatureCelsius = 3.8,
    String? batchDate,
    String? hubCode,
    String? batchCode,
    String qualityCertificateNote = 'FSSAI Certified • Passed 24 Purity Checks',
  }) async {
    try {
      final payload = {
        'product_name': productName,
        'fat_percentage': fatPercentage,
        'snf_percentage': snfPercentage,
        'water_percentage': waterPercentage,
        'price_per_litre': pricePerLitre,
        'total_litres': totalLitres,
        'temperature_celsius': temperatureCelsius,
        if (batchDate != null) 'batch_date': batchDate,
        if (hubCode != null) 'hub_code': hubCode,
        if (batchCode != null) 'batch_code': batchCode,
        'quality_certificate_note': qualityCertificateNote,
      };

      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/deliveries/daily-batches/'),
            headers: _headers,
            body: jsonEncode(payload),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(res.body));
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) {
      lastError = e.toString();
    }
    return null;
  }

  // ── Bottle Return Tracking ──

  static Future<List<BottleReturnModel>> fetchBottleReturns() async {
    try {
      final res = await _executeWithRetry(() => http.get(
            Uri.parse('$baseUrl/bottles/'),
            headers: _headers,
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final List list = jsonDecode(res.body);
        return list.map((item) => BottleReturnModel.fromJson(item)).toList();
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return [];
  }

  static Future<BottleReturnModel?> createBottleReturn({
    int? customerId,
    int? productId,
    required int quantity,
    double depositAmount = 0.0,
    String notes = '',
  }) async {
    try {
      final payload = <String, dynamic>{
        'quantity': quantity,
        'deposit_amount': depositAmount,
        'notes': notes,
      };
      if (customerId != null) payload['customer_id'] = customerId;
      if (productId != null) payload['product_id'] = productId;

      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/bottles/'),
            headers: _headers,
            body: jsonEncode(payload),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return BottleReturnModel(
          id: data['id'] ?? 0,
          customerName: 'Customer',
          driverName: 'Driver',
          hubName: '',
          productName: 'Glass Bottle',
          quantity: quantity,
          depositAmount: depositAmount,
          status: data['status'] ?? 'DEPOSITED',
          collectedDate: DateTime.now().toString().split(' ')[0],
          notes: notes,
        );
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return null;
  }

  static Future<bool> updateBottleReturnStatus(int bottleId, String status) async {
    try {
      final res = await _executeWithRetry(() => http.patch(
            Uri.parse('$baseUrl/bottles/$bottleId/'),
            headers: _headers,
            body: jsonEncode({'status': status}),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return false;
  }

  // ── Provider Payouts & Earnings ──

  static Future<List<ProviderPayoutModel>> fetchProviderPayouts() async {
    try {
      final res = await _executeWithRetry(() => http.get(
            Uri.parse('$baseUrl/payouts/'),
            headers: _headers,
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final List list = jsonDecode(res.body);
        return list.map((item) => ProviderPayoutModel.fromJson(item)).toList();
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return [];
  }

  static Future<ProviderEarningsSummaryModel?> fetchProviderEarningsSummary({
    String period = 'TODAY',
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{'period': period};
      if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;

      final uri = Uri.parse('$baseUrl/payouts/summary/').replace(queryParameters: queryParams);
      final res = await _executeWithRetry(() => http.get(uri, headers: _headers));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return ProviderEarningsSummaryModel.fromJson(data);
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) {
      lastError = e.toString();
    }
    return null;
  }

  static Future<ProviderPayoutModel?> requestInstantPayout({double? amount, String? notes}) async {
    try {
      final payload = <String, dynamic>{};
      if (amount != null && amount > 0) payload['amount'] = amount;
      if (notes != null && notes.isNotEmpty) payload['notes'] = notes;

      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/payouts/'),
            headers: _headers,
            body: jsonEncode(payload),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final payoutData = data['payout'] ?? data;
        return ProviderPayoutModel.fromJson(payoutData);
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) { lastError = e.toString(); }
    return null;
  }

  // ── Storefront Configuration & Top Banner ──

  static Future<StorefrontConfigModel> fetchStorefrontConfig() async {
    try {
      final res = await _executeWithRetry(() => http.get(
            Uri.parse('$baseUrl/storefront/config/'),
            headers: _headers,
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return StorefrontConfigModel.fromJson(data);
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) {
      lastError = e.toString();
    }
    return const StorefrontConfigModel();
  }

  static Future<StorefrontConfigModel?> updateStorefrontConfig({
    String? bannerImageUrl,
    String? headline,
    String? subtitle,
    String? dispatchTag,
    String? promoChip,
    String? ctaText,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (bannerImageUrl != null) payload['banner_image_url'] = bannerImageUrl;
      if (headline != null) payload['headline'] = headline;
      if (subtitle != null) payload['subtitle'] = subtitle;
      if (dispatchTag != null) payload['dispatch_tag'] = dispatchTag;
      if (promoChip != null) payload['promo_chip'] = promoChip;
      if (ctaText != null) payload['cta_text'] = ctaText;

      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/storefront/config/'),
            headers: _headers,
            body: jsonEncode(payload),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return StorefrontConfigModel.fromJson(data);
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) {
      lastError = e.toString();
    }
    return null;
  }

  // ── 20. Support Desk & Live Chat ──
  static Future<Map<String, dynamic>?> sendSupportChatMessage({
    required String phone,
    required String text,
    String senderType = 'user',
    String senderName = 'Customer',
    String? orderId,
  }) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/support/chat/send/'),
            headers: _headers,
            body: jsonEncode({
              'phone': phone,
              'sender_type': senderType,
              'sender_name': senderName,
              'text': text,
              if (orderId != null) 'order_id': orderId,
            }),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) {
      lastError = e.toString();
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> fetchSupportChatHistory(String phone) async {
    try {
      final uri = Uri.parse('$baseUrl/support/chat/history/').replace(queryParameters: {'phone': phone});
      final res = await _executeWithRetry(() => http.get(uri, headers: _headers));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['messages'] is List) {
          return (data['messages'] as List).map((m) => m as Map<String, dynamic>).toList();
        }
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) {
      lastError = e.toString();
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchAdminSupportThreads() async {
    try {
      final res = await _executeWithRetry(() => http.get(
            Uri.parse('$baseUrl/admin/support/threads/'),
            headers: _headers,
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['threads'] is List) {
          return (data['threads'] as List).map((t) => t as Map<String, dynamic>).toList();
        }
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) {
      lastError = e.toString();
    }
    return [];
  }

  // ── 21. Driver <-> Customer In-App Delivery Chat ──
  static Future<Map<String, dynamic>?> sendDeliveryChatMessage({
    required String channelKey,
    int? taskId,
    String? orderId,
    required String senderRole,
    required String senderName,
    String senderPhone = '',
    required String text,
  }) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/deliveries/chat/send/'),
            headers: _headers,
            body: jsonEncode({
              'channel_key': channelKey,
              if (taskId != null) 'task_id': taskId,
              if (orderId != null) 'order_id': orderId,
              'sender_role': senderRole,
              'sender_name': senderName,
              'sender_phone': senderPhone,
              'text': text,
            }),
          ));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) {
      lastError = e.toString();
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> fetchDeliveryChatHistory({
    required String channelKey,
    int? taskId,
    String? orderId,
  }) async {
    try {
      final query = <String, String>{'channel': channelKey};
      if (taskId != null) query['task_id'] = taskId.toString();
      if (orderId != null) query['order_id'] = orderId;

      final uri = Uri.parse('$baseUrl/deliveries/chat/history/').replace(queryParameters: query);
      final res = await _executeWithRetry(() => http.get(uri, headers: _headers));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['messages'] is List) {
          return (data['messages'] as List).map((m) => m as Map<String, dynamic>).toList();
        }
      } else {
        lastError = _extractErrorMsg(res);
      }
    } catch (e) {
      lastError = e.toString();
    }
    return [];
  }

  // ── 22. Delivery & Order Rating ──
  static Future<bool> submitDeliveryRating({
    String? orderId,
    int? taskId,
    required int rating,
    String feedback = '',
    List<String> tags = const [],
  }) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/deliveries/rate/'),
            headers: _headers,
            body: jsonEncode({
              if (orderId != null) 'order_id': orderId,
              if (taskId != null) 'task_id': taskId,
              'rating': rating,
              'feedback': feedback,
              'tags': tags,
            }),
          ));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      lastError = e.toString();
    }
    return false;
  }

  // ── 23. Coverage Expansion Request ──
  static Future<bool> submitCoverageRequest({
    String? city,
    String? areaName,
    double? latitude,
    double? longitude,
    String? phone,
  }) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/deliveries/coverage-request/'),
            headers: _headers,
            body: jsonEncode({
              'city': city ?? 'Kodad',
              'area_name': areaName ?? '',
              if (latitude != null) 'latitude': latitude,
              if (longitude != null) 'longitude': longitude,
              if (phone != null && phone.isNotEmpty) 'phone': phone,
            }),
          ));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      lastError = e.toString();
    }
    return false;
  }
}

