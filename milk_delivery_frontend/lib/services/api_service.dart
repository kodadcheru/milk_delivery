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
import 'image_upload_service.dart';

class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;
  static String? authToken;
  static String? refreshToken;

  static const String _prefTokenKey = 'milkdrop_auth_token';
  static const String _prefRefreshTokenKey = 'milkdrop_refresh_token';
  static const String _prefUserKey = 'milkdrop_user_data';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  /// Initialize and restore stored tokens from SharedPreferences
  static Future<String?> initAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      authToken = prefs.getString(_prefTokenKey);
      refreshToken = prefs.getString(_prefRefreshTokenKey);
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
    } catch (_) {}
  }

  /// Refresh JWT Access Token using Refresh Token
  static Future<bool> refreshAuthToken() async {
    if (refreshToken == null || refreshToken!.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      ).timeout(AppConfig.requestTimeout);

      if (res.statusCode == 200) {
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
      }
    } catch (_) {}
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
    } catch (_) {}
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
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/auth/send-otp/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone}),
          ));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        final err = jsonDecode(res.body);
        return {'success': false, 'error': err['detail'] ?? err['message'] ?? 'Failed to send OTP'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network connection error. Please check your connection.'};
    }
  }

  static Future<Map<String, dynamic>> verifyOTP(String phone, String otp) async {
    try {
      final res = await _executeWithRetry(() => http.post(
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
      final res = await _executeWithRetry(() => http.post(
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

  static Future<List<Map<String, dynamic>>> fetchDrivers({int? hubId}) async {
    try {
      final uri = hubId != null
          ? Uri.parse('$baseUrl/admin/drivers/?hub_id=$hubId')
          : Uri.parse('$baseUrl/admin/drivers/');
      final res = await _executeWithRetry(() => http.get(uri, headers: _headers));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ── 2. Standard Auth & Profile ──
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/auth/token/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          ));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await saveAuthToken(data['access'], refresh: data['refresh']);
        return {'success': true, 'token': data['access']};
      }
    } catch (_) {}
    return {'success': false, 'error': 'Failed to connect to backend'};
  }

  static Future<UserModel?> fetchUserProfile() async {
    if (authToken == null) return null;
    try {
      final res = await _executeWithRetry(() => http.get(Uri.parse('$baseUrl/auth/me/'), headers: _headers));
      if (res.statusCode == 200) {
        return UserModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  static Future<UserModel?> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      final res = await _executeWithRetry(() => http.patch(
            Uri.parse('$baseUrl/auth/me/'),
            headers: _headers,
            body: jsonEncode(updates),
          ));
      if (res.statusCode == 200) {
        return UserModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
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
      if (res.statusCode == 200) {
        final list = _extractList(jsonDecode(res.body));
        return list.map((e) => NotificationModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> markNotificationRead(int id) async {
    try {
      final res = await _executeWithRetry(() => http.post(Uri.parse('$baseUrl/notifications/$id/read/'), headers: _headers));
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  static Future<bool> markAllNotificationsRead() async {
    try {
      final res = await _executeWithRetry(() => http.post(Uri.parse('$baseUrl/notifications/read-all/'), headers: _headers));
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  // ── 4. Products & Categories ──
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
      if (res.statusCode == 200) {
        final list = _extractList(jsonDecode(res.body));
        return list.map((e) => ProductModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<ProductModel?> createProduct(String name, String description, double price, String unitQty, String imageUrl, {String category = 'MILK'}) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/products/'),
            headers: _headers,
            body: jsonEncode({
              'name': name,
              'description': description,
              'category': category,
              'price_per_unit': price.toStringAsFixed(2),
              'unit_quantity': unitQty,
              'image_url': imageUrl,
              'is_available': true,
            }),
          ));
      if (res.statusCode == 201) {
        return ProductModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  // ── 5. Subscriptions ──
  static Future<List<SubscriptionModel>> fetchSubscriptions() async {
    try {
      final res = await _executeWithRetry(() => http.get(Uri.parse('$baseUrl/subscriptions/'), headers: _headers));
      if (res.statusCode == 200) {
        final list = _extractList(jsonDecode(res.body));
        return list.map((e) => SubscriptionModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<SubscriptionModel?> createSubscription(int productId, int quantity, String scheduleType) async {
    try {
      final todayStr = DateTime.now().toString().split(' ')[0];
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/subscriptions/'),
            headers: _headers,
            body: jsonEncode({
              'product': productId,
              'quantity': quantity,
              'schedule_type': scheduleType,
              'start_date': todayStr,
            }),
          ));
      if (res.statusCode == 201) {
        return SubscriptionModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> pauseSubscription(int subId, String startDate, String endDate) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/subscriptions/$subId/pause/'),
            headers: _headers,
            body: jsonEncode({'start_date': startDate, 'end_date': endDate, 'reason': 'Vacation Mode'}),
          ));
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  static Future<bool> resumeSubscription(int subId) async {
    try {
      final res = await _executeWithRetry(() => http.post(Uri.parse('$baseUrl/subscriptions/$subId/resume/'), headers: _headers));
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  static Future<bool> cancelSubscription(int subId) async {
    try {
      final res = await _executeWithRetry(() => http.delete(Uri.parse('$baseUrl/subscriptions/$subId/'), headers: _headers));
      return res.statusCode == 204 || res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  static Future<bool> updateSubscription(int subId, {int? quantity, String? scheduleType}) async {
    try {
      final bodyMap = <String, dynamic>{};
      if (quantity != null) bodyMap['quantity'] = quantity;
      if (scheduleType != null) bodyMap['schedule_type'] = scheduleType;

      final res = await _executeWithRetry(() => http.patch(
            Uri.parse('$baseUrl/subscriptions/$subId/'),
            headers: _headers,
            body: jsonEncode(bodyMap),
          ));
      return res.statusCode == 200;
    } catch (_) {}
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
      return res.statusCode == 200;
    } catch (_) {}
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
      if (res.statusCode == 200) {
        final list = _extractList(jsonDecode(res.body));
        return list.map((e) => WalletTransactionModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ── 7. Delivery Tasks ──
  static Future<List<DeliveryTaskModel>> fetchDeliveries({int? page, int? pageSize, String? date}) async {
    try {
      final queryParams = <String, String>{};
      if (page != null) queryParams['page'] = page.toString();
      if (pageSize != null) queryParams['page_size'] = pageSize.toString();
      if (date != null) queryParams['date'] = date;

      final uri = Uri.parse('$baseUrl/deliveries/').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final res = await _executeWithRetry(() => http.get(uri, headers: _headers));
      if (res.statusCode == 200) {
        final list = _extractList(jsonDecode(res.body));
        return list.map((e) => DeliveryTaskModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> completeDelivery(int taskId, String proofUrl) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/deliveries/$taskId/complete/'),
            headers: _headers,
            body: jsonEncode({'proof_image_url': proofUrl}),
          ));
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  static Future<bool> skipDelivery(int taskId) async {
    try {
      final res = await _executeWithRetry(() => http.post(Uri.parse('$baseUrl/deliveries/$taskId/skip/'), headers: _headers));
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  // ── 8. Admin Analytics Summary ──
  static Future<Map<String, dynamic>?> fetchDeliverySummary() async {
    try {
      final res = await _executeWithRetry(() => http.get(Uri.parse('$baseUrl/deliveries/summary/'), headers: _headers));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ── 9. Geofenced Service Areas ──
  static Future<List<Map<String, dynamic>>> fetchServiceAreas() async {
    try {
      final res = await _executeWithRetry(() => http.get(Uri.parse('$baseUrl/service-areas/')));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  // ── 10. Location Hubs ──
  static Future<List<Map<String, dynamic>>> fetchHubs() async {
    try {
      final res = await _executeWithRetry(() => http.get(Uri.parse('$baseUrl/admin/hubs/')));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  // ── 11. Salaried Delivery Fleet & Hub Onboarding ──
  static Future<List<Map<String, dynamic>>> fetchFleet({int? hubId}) async {
    try {
      final url = hubId != null ? '$baseUrl/admin/fleet/?hub_id=$hubId' : '$baseUrl/admin/fleet/';
      final res = await _executeWithRetry(() => http.get(Uri.parse(url)));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> createHubDriver({
    required String firstName,
    required String lastName,
    required String phone,
    required int hubId,
    double monthlySalary = 15000.0,
  }) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/admin/fleet/create-driver/'),
            headers: _headers,
            body: jsonEncode({
              'first_name': firstName,
              'last_name': lastName,
              'phone': phone,
              'hub_id': hubId,
              'monthly_salary': monthlySalary,
            }),
          ));
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  // ── 12. Customer Address Book APIs ──
  static Future<List<CustomerAddressModel>> fetchCustomerAddresses() async {
    try {
      final res = await _executeWithRetry(() => http.get(
            Uri.parse('$baseUrl/accounts/addresses/'),
            headers: _headers,
          ));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((item) => CustomerAddressModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<CustomerAddressModel?> createCustomerAddress(CustomerAddressModel address) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/accounts/addresses/'),
            headers: _headers,
            body: jsonEncode(address.toJson()),
          ));
      if (res.statusCode == 201 || res.statusCode == 200) {
        return CustomerAddressModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  static Future<CustomerAddressModel?> updateCustomerAddress(CustomerAddressModel address) async {
    try {
      final res = await _executeWithRetry(() => http.patch(
            Uri.parse('$baseUrl/accounts/addresses/${address.id}/'),
            headers: _headers,
            body: jsonEncode(address.toJson()),
          ));
      if (res.statusCode == 200) {
        return CustomerAddressModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> deleteCustomerAddress(int addressId) async {
    try {
      final res = await _executeWithRetry(() => http.delete(
            Uri.parse('$baseUrl/accounts/addresses/$addressId/'),
            headers: _headers,
          ));
      return res.statusCode == 204 || res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  static Future<bool> setDefaultCustomerAddress(int addressId) async {
    try {
      final res = await _executeWithRetry(() => http.post(
            Uri.parse('$baseUrl/accounts/addresses/$addressId/set-default/'),
            headers: _headers,
          ));
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  // ── 13. Express / Live Orders APIs ──
  static Future<List<LiveOrderModel>> fetchLiveOrders({int? page, int? pageSize, String? status}) async {
    try {
      final queryParams = <String, String>{};
      if (page != null) queryParams['page'] = page.toString();
      if (pageSize != null) queryParams['page_size'] = pageSize.toString();
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('$baseUrl/orders/express/').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final res = await _executeWithRetry(() => http.get(
            uri,
            headers: _headers,
          ));
      if (res.statusCode == 200) {
        final list = _extractList(jsonDecode(res.body));
        return list.map((item) => LiveOrderModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<LiveOrderModel?> createExpressOrder({
    required List<Map<String, dynamic>> items,
    String? deliveryDate,
    String? deliverySlot,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
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
              'delivery_latitude': ?deliveryLatitude,
              'delivery_longitude': ?deliveryLongitude,
            }),
          ));
      if (res.statusCode == 201 || res.statusCode == 200) {
        return LiveOrderModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  static Future<LiveOrderModel?> updateLiveOrderStatus(String orderId, String newStatus, {String? proofImageUrl}) async {
    try {
      final body = <String, dynamic>{'status': newStatus};
      if (proofImageUrl != null) body['proof_image_url'] = proofImageUrl;

      final res = await _executeWithRetry(() => http.patch(
            Uri.parse('$baseUrl/orders/express/$orderId/'),
            headers: _headers,
            body: jsonEncode(body),
          ));
      if (res.statusCode == 200) {
        return LiveOrderModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  // ── 14. Media & Image Upload Service ──
  static Future<String?> uploadImage(Uint8List bytes, String filename, {String folder = 'proofs'}) async {
    return ImageUploadService.uploadImageBytes(
      bytes: bytes,
      filename: filename,
      folder: folder,
    );
  }
}
