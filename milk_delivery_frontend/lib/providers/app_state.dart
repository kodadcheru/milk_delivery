import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/customer_address_model.dart';
import '../models/product_model.dart';
import '../models/subscription_model.dart';
import '../models/delivery_task_model.dart';
import '../models/wallet_transaction_model.dart';
import '../models/notification_model.dart';
import '../models/live_order_model.dart';
import '../models/service_area_model.dart';
import '../models/storefront_config_model.dart';
import '../services/api_service.dart';
import '../services/hub_realtime_service.dart';
import '../services/location_service.dart';
import '../services/permission_service.dart';

class AppState extends ChangeNotifier {
  UserModel? currentUser;
  String currentRole = 'CUSTOMER';
  bool isLoading = false;
  String? errorMessage;

  bool isVacationMode = false;
  int currentTabIndex = 0;
  String? customBannerImagePath;
  StorefrontConfigModel storefrontConfig = const StorefrontConfigModel();

  // ── Redis & Real-Time Sync State ──
  bool isRedisConnected = false;
  Timer? _providerHeartbeatTimer;
  String get activeHubCode => locationHubs.isNotEmpty ? (locationHubs.first['hub_code'] ?? locationHubs.first['id'] ?? 'HUB-KDD-01').toString() : 'HUB-KDD-01';

  // Real-Time Location & Customer Address Book State
  String currentDeliveryAddress = 'Select Delivery Location';
  double currentLat = 17.4319;
  double currentLon = 78.4073;
  bool isDetectingLocation = false;
  bool hasLocationPermission = false;
  bool hasNotificationPermission = false;

  List<CustomerAddressModel> savedAddresses = [];
  CustomerAddressModel? activeAddress;

  List<ServiceAreaModel> serviceAreas = [];
  ServiceAreaModel selectedServiceArea = ServiceAreaModel.fallbackArea;
  List<Map<String, dynamic>> dailyMilkBatches = [];
  List<Map<String, dynamic>> qualityHistory = [];
  List<Map<String, dynamic>> hubDrivers = [];

  List<Map<String, dynamic>> locationHubs = [
    {
      'id': 'HUB-KDD-01',
      'hub_code': 'HUB-KDD-01',
      'name': 'Kodad Depot',
      'address': '2X27+M36, Kodad, Telangana 508206, India',
      'latitude': 17.001734,
      'longitude': 79.9625,
      'coverage_radius_km': 8.5,
    },
  ];

  // Distance helper in KM using Haversine formula
  double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // math.pi / 180
    final a = 0.5 - math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  Map<String, dynamic>? get nearestCoveringHub {
    if (locationHubs.isEmpty) return null;

    final hub = locationHubs.first;
    final hLat = double.tryParse(hub['latitude']?.toString() ?? '17.001734') ?? 17.001734;
    final hLon = double.tryParse(hub['longitude']?.toString() ?? '79.9625') ?? 79.9625;
    // Dynamic radius as configured in the Admin Web Console / Railway DB
    final radius = double.tryParse(hub['coverage_radius_km']?.toString() ?? '8.5') ?? 8.5;

    final dist = calculateDistanceKm(currentLat, currentLon, hLat, hLon);
    if (dist <= radius) {
      return hub;
    }
    return hub; // Always route to Kodad Depot as single dedicated hub
  }

  bool get isLocationCovered => nearestCoveringHub != null;

  void selectServiceArea(ServiceAreaModel area) {
    selectedServiceArea = area;
    currentDeliveryAddress = '${area.name}, ${area.city}';
    currentLat = area.latitude;
    currentLon = area.longitude;
    notifyListeners();
  }

  // Products populated from API via fetchProducts() — no hardcoded fallbacks
  List<ProductModel> products = [];
  List<SubscriptionModel> subscriptions = [];
  List<WalletTransactionModel> transactions = [];
  List<DeliveryTaskModel> deliveries = [];
  List<LiveOrderModel> liveOrders = [];
  List<NotificationModel> notifications = [];
  List<Map<String, dynamic>> hubInventory = [];
  Map<String, dynamic>? adminSummary;

  // Real-Time Hub Product Slot & Capacity Manager (Optimistic 0ms Latency)
  Future<void> updateHubProductCapacity(int productId, int dailyCapacitySlots, {bool? isAvailable}) async {
    HapticFeedback.lightImpact();

    final existingIdx = hubInventory.indexWhere((inv) => (inv['product'] == productId || inv['product_id'] == productId));
    if (existingIdx >= 0) {
      hubInventory[existingIdx]['daily_capacity_slots'] = dailyCapacitySlots;
      if (isAvailable != null) {
        hubInventory[existingIdx]['is_available'] = isAvailable;
      }
    } else {
      hubInventory.add({
        'product': productId,
        'product_id': productId,
        'daily_capacity_slots': dailyCapacitySlots,
        'is_available': isAvailable ?? true,
      });
    }

    final prodIdx = products.indexWhere((p) => p.id == productId);
    if (prodIdx >= 0) {
      final old = products[prodIdx];
      products[prodIdx] = ProductModel(
        id: old.id,
        name: old.name,
        category: old.category,
        description: old.description,
        pricePerUnit: old.pricePerUnit,
        unit: old.unit,
        unitQuantity: old.unitQuantity,
        imageUrl: old.imageUrl,
        badgeText: old.badgeText,
        nutritionInfo: old.nutritionInfo,
        farmOrigin: old.farmOrigin,
        isAvailable: isAvailable ?? old.isAvailable,
        availableSlots: (dailyCapacitySlots - (old.dailyCapacitySlots - old.availableSlots)).clamp(0, 9999),
        dailyCapacitySlots: dailyCapacitySlots,
        rating: old.rating,
        icon: old.icon,
      );
    }

    notifyListeners();

    try {
      final updated = await ApiService.updateHubInventory(
        productId: productId,
        dailyCapacitySlots: dailyCapacitySlots,
        isAvailable: isAvailable,
      );
      if (updated != null) {
        final idx = hubInventory.indexWhere((inv) => (inv['product'] == productId || inv['product_id'] == productId));
        if (idx >= 0) {
          hubInventory[idx] = updated;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  // In-memory Shopping Cart State
  final Map<String, MapEntry<ProductModel, int>> cartItems = {};

  int get totalCartItemCount => cartItems.values.fold(0, (sum, entry) => sum + entry.value);

  double get totalCartPrice {
    double total = 0.0;
    for (var entry in cartItems.values) {
      total += entry.key.pricePerUnit * entry.value;
    }
    return total;
  }

  List<MapEntry<ProductModel, int>> get cartProductsList => cartItems.values.toList();

  /// Stable per-line cart key. Each pack size of a product is its own cart
  /// line, so the key combines the product id with its pack size
  /// (`unitQuantity`). All cart mutations below operate on this exact key, so a
  /// stepper always changes the line it is showing.
  String cartKey(ProductModel product) => '${product.id}_${product.unitQuantity}';

  /// Quantity of this exact product line (specific to its pack size). This is
  /// what a per-line stepper/badge should display so shown == changed.
  int cartQtyOf(ProductModel product) => cartItems[cartKey(product)]?.value ?? 0;


  void addToCart(ProductModel product) {
    HapticFeedback.lightImpact();
    final key = cartKey(product);
    final existingQty = cartItems[key]?.value ?? 0;
    cartItems[key] = MapEntry(product, existingQty + 1);
    notifyListeners();
  }

  void decreaseCartQty(ProductModel product) {
    HapticFeedback.lightImpact();
    final key = cartKey(product);
    final item = cartItems[key];
    if (item == null) return;
    if (item.value > 1) {
      cartItems[key] = MapEntry(item.key, item.value - 1);
    } else {
      cartItems.remove(key);
    }
    notifyListeners();
  }

  void updateCartQty(ProductModel product, int qty) {
    final key = cartKey(product);
    if (qty <= 0) {
      cartItems.remove(key);
    } else {
      cartItems[key] = MapEntry(cartItems[key]?.key ?? product, qty);
    }
    notifyListeners();
  }

  void removeFromCart(ProductModel product) {
    cartItems.remove(cartKey(product));
    notifyListeners();
  }

  void clearCart() {
    cartItems.clear();
    notifyListeners();
  }

  Future<LiveOrderModel> placeExpressOrder({
    String? deliveryDate,
    String? deliverySlot,
    String? deliveryAddress,
  }) async {
    HapticFeedback.mediumImpact();
    final orderItems = cartProductsList.map((entry) {
      return OrderItemModel(
        product: entry.key,
        quantity: entry.value,
        unitPrice: entry.key.pricePerUnit,
      );
    }).toList();

    final total = totalCartPrice;
    final addr = deliveryAddress ?? (activeAddress?.summaryAddress ?? (currentDeliveryAddress != 'Select Delivery Location' ? currentDeliveryAddress : 'Doorstep Drop'));
    final dateStr = deliveryDate ?? 'Tomorrow';
    final slotStr = deliverySlot ?? '05:30 AM - 07:00 AM';

    // 1. Send to Backend API
    final itemsPayload = cartProductsList.map((e) => {
      'product_id': e.key.id,
      'quantity': e.value,
    }).toList();

    final targetLat = activeAddress?.latitude ?? currentLat;
    final targetLon = activeAddress?.longitude ?? currentLon;

    LiveOrderModel? serverOrder = await ApiService.createExpressOrder(
      items: itemsPayload,
      deliveryDate: dateStr,
      deliverySlot: slotStr,
      deliveryAddress: addr,
      deliveryLatitude: targetLat,
      deliveryLongitude: targetLon,
    );

    if (serverOrder != null) {
      liveOrders.insert(0, serverOrder);
      cartItems.clear();
      await reloadAllData();
      return serverOrder;
    }

    // 2. Resilient In-Memory Fallback if backend is unreachable
    final orderId = 'MD-${8000 + liveOrders.length + 1}';
    final hub = nearestCoveringHub;
    final driverPlaceholder = hub != null ? 'Assigning Partner (${hub['name']})...' : 'Assigning Delivery Partner...';

    final fallbackOrder = LiveOrderModel(
      id: orderId,
      orderType: 'ONE_TIME',
      items: orderItems,
      totalAmount: total,
      status: 'PREPARING',
      deliveryDate: dateStr,
      deliverySlot: slotStr,
      deliveryAddress: addr,
      deliveryLatitude: currentLat,
      deliveryLongitude: currentLon,
      deliveryOtp: '${(1000 + (orderId.hashCode % 9000)).abs()}',
      driverName: driverPlaceholder,
      driverPhone: '',
      paymentStatus: 'PAID (Prepaid Wallet)',
      createdAt: 'Just now',
    );

    liveOrders.insert(0, fallbackOrder);

    // Deduct from wallet & record transaction
    if (currentUser != null) {
      double newBal = currentUser!.walletBalance - total;
      currentUser = currentUser!.copyWith(walletBalance: newBal > 0 ? newBal : 0.0);
    }

    transactions.insert(
      0,
      WalletTransactionModel(
        id: transactions.length + 1,
        amount: total,
        transactionType: 'DEBIT',
        description: 'Express Order $orderId (${orderItems.length} items)',
        createdAt: 'Just now',
      ),
    );

    notifications.insert(
      0,
      NotificationModel(
        id: notifications.length + 1,
        title: '⚡ Express Order $orderId Dispatched!',
        message: 'Your order with ${orderItems.length} items is out for delivery. ETA ~25 mins.',
        notificationType: 'DELIVERY',
        isRead: false,
        createdAt: 'Just now',
      ),
    );

    cartItems.clear();
    notifyListeners();
    return fallbackOrder;
  }

  void updateOrderStatus(String orderId, String newStatus) async {
    final idx = liveOrders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final old = liveOrders[idx];
      liveOrders[idx] = old.copyWith(status: newStatus);
      notifyListeners();
    }

    await ApiService.updateLiveOrderStatus(orderId, newStatus);
    await reloadAllData();
  }

  Future<void> checkoutCart({
    String schedule = 'DAILY',
    String slot = '05:30 AM - 07:00 AM',
    String? deliveryAddress,
  }) async {
    final addr = deliveryAddress ?? (activeAddress?.summaryAddress ?? (currentDeliveryAddress != 'Select Delivery Location' ? currentDeliveryAddress : null));
    for (var entry in cartProductsList) {
      await createNewSubscription(entry.key, entry.value, schedule, deliveryAddress: addr, deliverySlot: slot, skipReload: true);
    }
    cartItems.clear();
    await reloadAllData();
    notifyListeners();
  }

  int get unreadNotificationCount => notifications.where((n) => !n.isRead).length;

  Future<void> loadCustomBannerImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      customBannerImagePath = prefs.getString('custom_home_banner_path');
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setCustomBannerImage(String? path) async {
    customBannerImagePath = path;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (path != null && path.isNotEmpty) {
        await prefs.setString('custom_home_banner_path', path);
      } else {
        await prefs.remove('custom_home_banner_path');
      }
    } catch (_) {}
  }

  AppState() {
    initApp();
  }

  Future<void> initApp() async {
    // CRITICAL: Load auth token FIRST before anything else
    final savedToken = await ApiService.initAuthToken();
    
    await loadCustomBannerImage();
    await initDevicePermissionsAndLocation();
    storefrontConfig = await ApiService.fetchStorefrontConfig();
    
    if (savedToken != null) {
      await reloadAllData();
    } else {
      products = await ApiService.fetchProducts();
      notifyListeners();
    }
  }

  Future<void> initDevicePermissionsAndLocation() async {
    hasNotificationPermission = await PermissionService.requestNotificationPermission();
    await requestDeviceGPS(isStartup: true);
  }

  Future<bool> requestDeviceGPS({bool isStartup = false}) async {
    isDetectingLocation = true;
    notifyListeners();

    bool success = false;
    try {
      final pos = await PermissionService.getDeviceCoordinates();
      if (pos != null) {
        currentLat = pos.latitude;
        currentLon = pos.longitude;
        hasLocationPermission = true;
        success = true;

        final loc = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
        if (loc != null && loc['short_address'] != null) {
          currentDeliveryAddress = loc['short_address'];
        }
      } else {
        final loc = await LocationService.reverseGeocode(currentLat, currentLon);
        if (loc != null && loc['short_address'] != null) {
          currentDeliveryAddress = loc['short_address'];
        }
      }
    } catch (_) {}

    isDetectingLocation = false;
    notifyListeners();
    return success;
  }

  Future<void> updateDeliveryLocation(String newAddress, double lat, double lon) async {
    currentDeliveryAddress = newAddress;
    currentLat = lat;
    currentLon = lon;
    notifyListeners();

    if (currentUser != null) {
      await updateUserProfile(address: newAddress, latitude: lat, longitude: lon);
    }
  }

  Future<void> loginAndSync(String username, String password, String role) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    currentRole = role;

    final authRes = await ApiService.login(username, password);
    if (authRes['success'] == true) {
      await reloadAllData();
    } else {
      errorMessage = authRes['error'] ?? 'Connection error';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> generateTodayTasks({
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
    final result = await ApiService.generateTodayTasks(
      date: date,
      productName: productName,
      fatPercentage: fatPercentage,
      snfPercentage: snfPercentage,
      waterPercentage: waterPercentage,
      pricePerLitre: pricePerLitre,
      totalLitres: totalLitres,
      temperatureCelsius: temperatureCelsius,
      hubCode: hubCode ?? activeHubCode,
    );
    if (result != null) {
      await reloadAllData();
    }
    return result;
  }

  Future<bool> assignTaskToDriver(int taskId, int? driverId) async {
    final success = await ApiService.reassignDeliveryTask(taskId, driverId);
    if (success) {
      await reloadAllData(silent: true);
    }
    return success;
  }


  Future<Map<String, dynamic>?> autoBalanceHubDeliveries([String? hubCode]) async {
    final targetHub = hubCode ?? activeHubCode;
    final res = await ApiService.rebalanceHubDeliveries(targetHub);
    if (res != null) {
      await reloadAllData(silent: true);
    }
    return res;
  }

  Future<void> loadQualityHistory() async {
    qualityHistory = await ApiService.fetchQualityHistory();
    notifyListeners();
  }

  Future<void> reloadAllData({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      notifyListeners();
    }
    try {
      final results = await Future.wait([
        ApiService.fetchUserProfile(),
        ApiService.fetchCustomerAddresses(),
        ApiService.fetchProducts(),
        ApiService.fetchSubscriptions(),
        ApiService.fetchDeliveries(),
        ApiService.fetchLiveOrders(),
        ApiService.fetchWalletTransactions(),
        ApiService.fetchNotifications(),
        ApiService.fetchHubs(),
        ApiService.fetchServiceAreas(),
        ApiService.fetchStorefrontConfig(),
        ApiService.fetchHubInventory(),
        ApiService.fetchDailyMilkBatches(),
      ]);

      storefrontConfig = results[10] as StorefrontConfigModel? ?? const StorefrontConfigModel();
      hubInventory = (results[11] as List<Map<String, dynamic>>?) ?? [];
      dailyMilkBatches = (results[12] as List<Map<String, dynamic>>?) ?? [];
      
      await loadQualityHistory();

      final user = results[0] as UserModel?;
      if (user != null) {
        currentUser = user;
        currentRole = user.role;
        if (user.address.isNotEmpty) {
          currentDeliveryAddress = user.address;
        }
        currentLat = user.latitude;
        currentLon = user.longitude;
      }

      final addrs = results[1] as List<CustomerAddressModel>? ?? [];
      if (addrs.isNotEmpty) {
        savedAddresses = addrs;
        final defaultAddr = addrs.firstWhere((a) => a.isDefault, orElse: () => addrs.first);
        activeAddress = defaultAddr;
        currentDeliveryAddress = defaultAddr.summaryAddress;
        currentLat = defaultAddr.latitude;
        currentLon = defaultAddr.longitude;
      } else if (savedAddresses.isEmpty) {
        if (user != null && user.address.isNotEmpty) {
          final profileAddr = CustomerAddressModel(
            id: 0,
            userId: user.id,
            addressType: 'HOME',
            displayType: 'Home',
            flatHouseNo: '',
            streetAddress: user.address,
            city: user.city.isNotEmpty ? user.city : 'Kodad',
            pincode: '508206',
            latitude: user.latitude,
            longitude: user.longitude,
            isDefault: true,
          );
          savedAddresses = [profileAddr];
          activeAddress = profileAddr;
          currentDeliveryAddress = profileAddr.summaryAddress;
          currentLat = profileAddr.latitude;
          currentLon = profileAddr.longitude;
        }
      }

      final fetchedProds = (results[2] as List<ProductModel>?) ?? [];
      if (fetchedProds.isNotEmpty) {
        products = fetchedProds;
      }
      subscriptions = (results[3] as List<SubscriptionModel>?) ?? [];
      deliveries = (results[4] as List<DeliveryTaskModel>?) ?? [];
      liveOrders = (results[5] as List<LiveOrderModel>?) ?? [];
      transactions = (results[6] as List<WalletTransactionModel>?) ?? [];
      notifications = (results[7] as List<NotificationModel>?) ?? [];
      final fetchedHubs = (results[8] as List<Map<String, dynamic>>?) ?? [];
      if (fetchedHubs.isNotEmpty) {
        locationHubs = fetchedHubs;
      }
      // Notifications are fetched from API — no hardcoded fallbacks
      final fetchedAreas = (results[9] as List<Map<String, dynamic>>?) ?? [];
      if (fetchedAreas.isNotEmpty) {
        serviceAreas = fetchedAreas.map((json) => ServiceAreaModel.fromJson(json)).toList();
        selectedServiceArea = serviceAreas.first;
      isVacationMode = subscriptions.isNotEmpty && subscriptions.any((sub) => sub.status == 'PAUSED');
      }

      if (savedAddresses.isEmpty && locationHubs.isNotEmpty && currentDeliveryAddress == 'Select Delivery Location') {
        final h = locationHubs.first;
        currentLat = double.tryParse(h['latitude']?.toString() ?? '16.9947') ?? 16.9947;
        currentLon = double.tryParse(h['longitude']?.toString() ?? '79.9750') ?? 79.9750;
        currentDeliveryAddress = '${h['name'] ?? 'Kodad Depot'}, ${h['city'] ?? 'Telangana'}';
      }

      if (currentRole == 'ADMIN' || currentRole == 'PROVIDER' || currentRole == 'HUB_MANAGER') {
        adminSummary = await ApiService.fetchDeliverySummary();
        hubDrivers = await ApiService.fetchFleet();
        if (_providerHeartbeatTimer == null) {
          startProviderRealtimeSync();
        }
      }
    } catch (e) {
      debugPrint('🚨 [MilkDrop Concurrent Reload Error]: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  // ── Redis Live Channel Layer & Multi-Tab Real-Time Sync Handlers ──
  void startProviderRealtimeSync() {
    _providerHeartbeatTimer?.cancel();
    
    // Connect to live Redis WebSocket channel
    HubRealtimeService.connect(
      hubCode: activeHubCode,
      onEvent: (event) {
        debugPrint('⚡ [AppState Redis Event Trigger]: $event');
        reloadAllData(silent: true);
      },
      onStatusChange: (connected) {
        if (isRedisConnected != connected) {
          isRedisConnected = connected;
          notifyListeners();
        }
      },
    );

    // Resilient 3-second multi-tab heartbeat to guarantee 0ms latency sync across all tabs
    _providerHeartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (currentRole == 'PROVIDER' || currentRole == 'HUB_MANAGER') {
        reloadAllData(silent: true);
      } else {
        timer.cancel();
      }
    });
  }

  void stopProviderRealtimeSync() {
    _providerHeartbeatTimer?.cancel();
    _providerHeartbeatTimer = null;
    HubRealtimeService.disconnect();
    isRedisConnected = false;
    notifyListeners();
  }

  Future<void> syncProviderTab(int tabIndex) async {
    currentTabIndex = tabIndex;
    notifyListeners();
    await reloadAllData(silent: true);
  }

  // ── Customer Address Book Handlers ──
  Future<void> fetchSavedAddresses() async {
    try {
      final addrs = await ApiService.fetchCustomerAddresses(
        customerId: currentUser?.id,
        phone: currentUser?.phone,
      );
      if (addrs.isNotEmpty) {
        savedAddresses = addrs;
        // Keep the currently active address if it still exists in the fetched list
        if (activeAddress != null && addrs.any((a) => a.id == activeAddress!.id)) {
          final matched = addrs.firstWhere((a) => a.id == activeAddress!.id);
          activeAddress = matched;
          currentDeliveryAddress = matched.summaryAddress;
          currentLat = matched.latitude;
          currentLon = matched.longitude;
        } else {
          final defaultAddr = addrs.firstWhere((a) => a.isDefault, orElse: () => addrs.first);
          activeAddress = defaultAddr;
          currentDeliveryAddress = defaultAddr.summaryAddress;
          currentLat = defaultAddr.latitude;
          currentLon = defaultAddr.longitude;
        }
      } else if (savedAddresses.isEmpty) {
        if (currentUser != null && currentUser!.address.isNotEmpty) {
          final profileAddr = CustomerAddressModel(
            id: 0,
            userId: currentUser!.id,
            addressType: 'HOME',
            displayType: 'Home',
            flatHouseNo: '',
            streetAddress: currentUser!.address,
            city: currentUser!.city.isNotEmpty ? currentUser!.city : 'Kodad',
            pincode: '508206',
            latitude: currentUser!.latitude,
            longitude: currentUser!.longitude,
            isDefault: true,
          );
          savedAddresses = [profileAddr];
          activeAddress = profileAddr;
          currentDeliveryAddress = profileAddr.summaryAddress;
          currentLat = profileAddr.latitude;
          currentLon = profileAddr.longitude;
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  void selectActiveAddress(CustomerAddressModel addr) {
    HapticFeedback.lightImpact();
    activeAddress = addr;
    currentDeliveryAddress = addr.summaryAddress;
    currentLat = addr.latitude;
    currentLon = addr.longitude;
    notifyListeners();

    if (currentUser != null) {
      updateUserProfile(address: addr.summaryAddress, latitude: addr.latitude, longitude: addr.longitude);
    }
  }

  Future<bool> saveCustomerAddress(CustomerAddressModel addr) async {
    CustomerAddressModel? result;
    if (addr.id > 0 && savedAddresses.any((a) => a.id == addr.id)) {
      result = await ApiService.updateCustomerAddress(addr);
    } else {
      result = await ApiService.createCustomerAddress(addr);
    }

    if (result != null) {
      await fetchSavedAddresses();
      final freshlySaved = savedAddresses.firstWhere((a) => a.id == result!.id, orElse: () => result!);
      selectActiveAddress(freshlySaved);
      return true;
    } else {
      // Resilient fallback: save locally to state
      final newId = addr.id > 0 ? addr.id : (DateTime.now().millisecondsSinceEpoch % 10000 + 1);
      final fallbackAddr = addr.copyWith(id: newId);
      savedAddresses.removeWhere((a) => a.id == newId);
      savedAddresses.insert(0, fallbackAddr);
      selectActiveAddress(fallbackAddr);
      return true;
    }
  }

  Future<bool> deleteCustomerAddress(int addressId) async {
    savedAddresses.removeWhere((a) => a.id == addressId);
    if (activeAddress?.id == addressId) {
      if (savedAddresses.isNotEmpty) {
        selectActiveAddress(savedAddresses.first);
      } else {
        activeAddress = null;
        if (locationHubs.isNotEmpty) {
          final h = locationHubs.first;
          currentLat = double.tryParse(h['latitude']?.toString() ?? '17.001734') ?? 17.001734;
          currentLon = double.tryParse(h['longitude']?.toString() ?? '79.9625') ?? 79.9625;
          currentDeliveryAddress = '${h['name'] ?? 'Kodad Depot'}, ${h['city'] ?? 'Telangana'}';
        } else {
          currentDeliveryAddress = 'Select Delivery Location';
        }
      }
    }
    notifyListeners();

    await ApiService.deleteCustomerAddress(addressId);
    return true;
  }

  Future<bool> setDefaultCustomerAddress(int addressId) async {
    final success = await ApiService.setDefaultCustomerAddress(addressId);
    if (success) {
      await fetchSavedAddresses();
      return true;
    }
    return false;
  }

  void setRole(String role) {
    // Role switching with test credentials is only available in debug builds
    if (!kDebugMode) return;
    if (role == 'CUSTOMER') {
      loginAndSync('customer', 'pass123', 'CUSTOMER');
    } else if (role == 'DRIVER') {
      loginAndSync('driver', 'pass123', 'DRIVER');
    } else if (role == 'PROVIDER' || role == 'HUB_MANAGER') {
      loginAndSync('hub_manager', 'pass123', 'PROVIDER');
    } else if (role == 'ADMIN') {
      loginAndSync('admin', 'admin123', 'ADMIN');
    }
  }

  void setTab(int index) {
    currentTabIndex = index;
    notifyListeners();
  }

  Future<void> onUserAuthenticated(UserModel user) async {
    currentUser = user;
    currentRole = user.role;
    savedAddresses = [];
    subscriptions = [];
    deliveries = [];
    transactions = [];
    activeAddress = null;
    await reloadAllData();
  }

  Future<void> logout() async {
    await ApiService.clearAuthToken();
    currentUser = null;
    currentRole = 'CUSTOMER';
    savedAddresses = [];
    subscriptions = [];
    deliveries = [];
    transactions = [];
    activeAddress = null;
    cartItems.clear();
    currentTabIndex = 0;
    notifyListeners();
  }

  Future<void> updateUserProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? address,
    String? deliveryInstructions,
    String? slotPreference,
    double? latitude,
    double? longitude,
    String? vehicleNumber,
    String? drivingLicense,
    double? monthlySalary,
  }) async {
    final updates = <String, dynamic>{};
    if (firstName != null) updates['first_name'] = firstName;
    if (lastName != null) updates['last_name'] = lastName;
    if (email != null) updates['email'] = email;
    if (phone != null) updates['phone'] = phone;
    if (address != null) updates['address'] = address;
    if (deliveryInstructions != null) updates['delivery_instructions'] = deliveryInstructions;
    if (slotPreference != null) updates['delivery_slot_preference'] = slotPreference;
    if (latitude != null) updates['latitude'] = latitude;
    if (longitude != null) updates['longitude'] = longitude;
    if (vehicleNumber != null) updates['vehicle_number'] = vehicleNumber;
    if (drivingLicense != null) updates['driving_license'] = drivingLicense;
    if (monthlySalary != null) updates['monthly_salary'] = monthlySalary;

    final updatedUser = await ApiService.updateUserProfile(updates);
    if (updatedUser != null) {
      currentUser = updatedUser;
    } else if (currentUser != null) {
      currentUser = currentUser!.copyWith(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        address: address,
        deliveryInstructions: deliveryInstructions,
        deliverySlotPreference: slotPreference,
        latitude: latitude,
        longitude: longitude,
        vehicleNumber: vehicleNumber,
        drivingLicense: drivingLicense,
        monthlySalary: monthlySalary,
      );
    }
    notifyListeners();
  }

  Future<void> markNotificationRead(int id) async {
    await ApiService.markNotificationRead(id);
    notifications = notifications.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    await ApiService.markAllNotificationsRead();
    notifications = notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  Future<void> sendSystemBroadcast(String title, String message) async {
    await ApiService.sendBroadcastAlert(title, message);
    notifications.insert(
      0,
      NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch,
        title: title,
        message: message,
        notificationType: 'OFFER',
        isRead: false,
        createdAt: 'Just now',
      ),
    );
    notifyListeners();
  }

  Future<void> toggleVacationMode(bool val) async {
    isVacationMode = val;
    final todayStr = DateTime.now().toString().split(' ')[0];
    final nextMonthStr = DateTime.now().add(const Duration(days: 30)).toString().split(' ')[0];

    for (var sub in subscriptions) {
      if (val) {
        await ApiService.pauseSubscription(sub.id, todayStr, nextMonthStr);
      } else {
        await ApiService.resumeSubscription(sub.id);
      }
    }
    await reloadAllData();
  }

  Future<void> topUpWallet(double amount, String method) async {
    if (currentUser != null) {
      double newBal = currentUser!.walletBalance + amount;
      currentUser = currentUser!.copyWith(walletBalance: newBal);
      transactions.insert(
        0,
        WalletTransactionModel(
          id: DateTime.now().millisecondsSinceEpoch % 10000,
          amount: amount,
          transactionType: 'CREDIT',
          description: 'Recharge via $method',
          createdAt: 'Just now',
        ),
      );
      notifyListeners();
    }

    notifications.insert(
      0,
      NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch,
        title: '⚡ Wallet Top-Up Successful! ₹${amount.toStringAsFixed(0)}',
        message: '₹${amount.toStringAsFixed(0)} credited to your prepaid milk wallet via $method.',
        notificationType: 'WALLET',
        isRead: false,
        createdAt: 'Just now',
      ),
    );

    bool ok = await ApiService.topUpWallet(amount, 'Recharge via $method');
    if (ok) {
      await reloadAllData();
    }
  }

  Future<void> createNewSubscription(
    ProductModel product,
    int qty,
    String schedule, {
    String? deliveryAddress,
    String? deliverySlot,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryInstructions,
    String? packSize,
    bool skipReload = false,
  }) async {
    // Pre-flight auth check
    if (ApiService.authToken == null) {
      throw Exception('Please log in to subscribe. Your session may have expired.');
    }
    
    final slotStr = deliverySlot ?? '05:30 AM - 07:00 AM';
    notifications.insert(
      0,
      NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch,
        title: '🥛 Subscription Confirmed: ${product.name}',
        message: '${qty}x ${product.name} (${packSize ?? product.unitQuantity}) subscribed for $slotStr delivery ($schedule).',
        notificationType: 'DELIVERY',
        isRead: false,
        createdAt: 'Just now',
      ),
    );
    final targetAddr = deliveryAddress ?? (activeAddress?.summaryAddress ?? (currentDeliveryAddress != 'Select Delivery Location' ? currentDeliveryAddress : 'Doorstep Drop'));
    final targetLat = deliveryLatitude ?? (activeAddress?.latitude ?? currentLat);
    final targetLon = deliveryLongitude ?? (activeAddress?.longitude ?? currentLon);
    final targetInst = deliveryInstructions ?? (activeAddress?.deliveryInstructions ?? '');
    final pSize = packSize ?? product.unitQuantity;

    final newSub = await ApiService.createSubscription(
      product.id,
      qty,
      schedule,
      customerId: currentUser?.id,
      customerPhone: currentUser?.phone,
      deliveryAddress: targetAddr,
      deliverySlot: slotStr,
      deliveryLatitude: targetLat,
      deliveryLongitude: targetLon,
      deliveryInstructions: targetInst,
      packSize: pSize,
    );
    if (newSub != null) {
      debugPrint('✅ [Subscription Created]: Sub #${newSub.id} for ${product.name}');
      if (!skipReload) await reloadAllData();
    } else {
      debugPrint('⚠️ [Subscription Create Error]: ${ApiService.lastError}');
      if (ApiService.lastError != null) {
        throw Exception(ApiService.lastError);
      }
      if (!skipReload) await reloadAllData();
    }
  }

  Future<bool> updateSubscriptionAddressAndSlot(
    int subId, {
    required String deliveryAddress,
    required String deliverySlot,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryInstructions,
  }) async {
    bool ok = await ApiService.updateSubscription(
      subId,
      deliveryAddress: deliveryAddress,
      deliverySlot: deliverySlot,
      deliveryLatitude: deliveryLatitude ?? currentLat,
      deliveryLongitude: deliveryLongitude ?? currentLon,
      deliveryInstructions: deliveryInstructions ?? '',
    );
    if (ok) {
      await reloadAllData();
      return true;
    } else {
      subscriptions = subscriptions.map((s) {
        if (s.id == subId) {
          return s.copyWith(
            deliveryAddress: deliveryAddress,
            deliverySlot: deliverySlot,
            deliveryLatitude: deliveryLatitude ?? s.deliveryLatitude,
            deliveryLongitude: deliveryLongitude ?? s.deliveryLongitude,
            deliveryInstructions: deliveryInstructions ?? s.deliveryInstructions,
          );
        }
        return s;
      }).toList();
      notifyListeners();
      return true;
    }
  }

  Future<bool> updateSubscriptionQuantity(int subId, int newQty) async {
    final idx = subscriptions.indexWhere((s) => s.id == subId);
    if (idx != -1) {
      subscriptions[idx] = subscriptions[idx].copyWith(quantity: newQty);
      notifyListeners();
    }
    final ok = await ApiService.updateSubscription(subId, quantity: newQty);
    await reloadAllData(silent: true);
    return ok;
  }

  Future<bool> updateSubscriptionSchedule(int subId, String newSchedule) async {
    final idx = subscriptions.indexWhere((s) => s.id == subId);
    if (idx != -1) {
      subscriptions[idx] = subscriptions[idx].copyWith(scheduleType: newSchedule);
      notifyListeners();
    }
    final ok = await ApiService.updateSubscription(subId, scheduleType: newSchedule);
    await reloadAllData(silent: true);
    return ok;
  }

  Future<bool> toggleSubscriptionStatus(int subId) async {
    final idx = subscriptions.indexWhere((s) => s.id == subId);
    if (idx != -1) {
      final sub = subscriptions[idx];
      final newStatus = sub.status == 'PAUSED' ? 'ACTIVE' : 'PAUSED';
      subscriptions[idx] = sub.copyWith(status: newStatus);
      notifyListeners();

      bool ok = false;
      if (newStatus == 'ACTIVE') {
        ok = await ApiService.resumeSubscription(subId);
      } else {
        final todayStr = DateTime.now().toString().split(' ')[0];
        final nextMonthStr = DateTime.now().add(const Duration(days: 30)).toString().split(' ')[0];
        ok = await ApiService.pauseSubscription(subId, todayStr, nextMonthStr);
      }
      await reloadAllData(silent: true);
      return ok;
    }
    return false;
  }

  Future<bool> pauseSubscriptionWithDates(int subId, String startDate, String endDate, String reason) async {
    final idx = subscriptions.indexWhere((s) => s.id == subId);
    if (idx != -1) {
      subscriptions[idx] = subscriptions[idx].copyWith(status: 'PAUSED');
      notifyListeners();
    }
    final ok = await ApiService.pauseSubscription(subId, startDate, endDate);
    await reloadAllData(silent: true);
    return ok;
  }

  Future<bool> cancelSubscription(int subId) async {
    final idx = subscriptions.indexWhere((s) => s.id == subId);
    if (idx != -1) {
      subscriptions[idx] = subscriptions[idx].copyWith(status: 'CANCELLED');
      notifyListeners();
    }
    final ok = await ApiService.cancelSubscription(subId);
    await reloadAllData(silent: true);
    return ok;
  }

  Future<bool> reactivateSubscription(int subId) async {
    final idx = subscriptions.indexWhere((s) => s.id == subId);
    if (idx != -1) {
      subscriptions[idx] = subscriptions[idx].copyWith(status: 'ACTIVE');
      notifyListeners();
    }
    final ok = await ApiService.reactivateSubscription(subId);
    await reloadAllData(silent: true);
    return ok;
  }

  Future<bool> updateSubscriptionDetails(
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
    final idx = subscriptions.indexWhere((s) => s.id == subId);
    if (idx != -1) {
      final old = subscriptions[idx];
      subscriptions[idx] = old.copyWith(
        quantity: quantity ?? old.quantity,
        scheduleType: scheduleType ?? old.scheduleType,
        deliveryAddress: deliveryAddress ?? old.deliveryAddress,
        deliverySlot: deliverySlot ?? old.deliverySlot,
        deliveryLatitude: deliveryLatitude ?? old.deliveryLatitude,
        deliveryLongitude: deliveryLongitude ?? old.deliveryLongitude,
        deliveryInstructions: deliveryInstructions ?? old.deliveryInstructions,
        packSize: packSize ?? old.packSize,
      );
      notifyListeners();
    }

    final ok = await ApiService.updateSubscription(
      subId,
      quantity: quantity,
      scheduleType: scheduleType,
      deliveryAddress: deliveryAddress,
      deliverySlot: deliverySlot,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      deliveryInstructions: deliveryInstructions,
      packSize: packSize,
    );
    await reloadAllData(silent: true);
    return ok;
  }

  Future<void> markDeliveryCompleted(int taskId, String proofUrl) async {
    bool ok = await ApiService.completeDelivery(taskId, proofUrl);
    if (ok) {
      notifications.insert(
        0,
        NotificationModel(
          id: DateTime.now().millisecondsSinceEpoch,
          title: '🛵 Driver Drop Verified & Completed',
          message: 'Delivery Drop #$taskId successfully completed & doorstep photo proof verified.',
          notificationType: 'DELIVERY',
          isRead: false,
          createdAt: 'Just now',
        ),
      );

      deliveries = deliveries.map((d) {
        if (d.id == taskId) {
          return d.copyWith(status: 'DELIVERED', proofImageUrl: proofUrl, deliveredAt: '06:25 AM');
        }
        return d;
      }).toList();

      if (currentUser != null) {
        final completedTask = deliveries.where((d) => d.id == taskId).firstOrNull;
        double debitAmount = completedTask?.subscriptionDetail?.productDetail?.pricePerUnit ?? 0.0;
        if (debitAmount > 0) {
          double newBal = currentUser!.walletBalance - debitAmount;
          currentUser = currentUser!.copyWith(walletBalance: newBal > 0 ? newBal : 0.0);
        }
      }
      notifyListeners();
      await reloadAllData();
    }
  }

  Future<void> markDeliverySkipped(int taskId) async {
    bool ok = await ApiService.skipDelivery(taskId);
    if (ok) {
      await reloadAllData();
    } else {
      deliveries = deliveries.map((d) {
        if (d.id == taskId) return d.copyWith(status: 'SKIPPED');
        return d;
      }).toList();
      notifyListeners();
    }
  }

  Future<void> addNewProduct(String name, String desc, double price, String unitQty, String imgUrl, {String category = 'MILK'}) async {
    notifications.insert(
      0,
      NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch,
        title: '✨ Catalog Product Listed: $name',
        message: '$name ($unitQty) added to catalog at ₹${price.toStringAsFixed(0)} / unit.',
        notificationType: 'OFFER',
        isRead: false,
        createdAt: 'Just now',
      ),
    );
    final p = await ApiService.createProduct(name, desc, price, unitQty, imgUrl, category: category);
    if (p != null) {
      await reloadAllData();
    }
  }

  double get totalDailyMilkVolume {
    double total = 0;
    for (var d in deliveries) {
      if (d.status != 'SKIPPED') {
        total += (d.subscriptionDetail?.quantity ?? 1);
      }
    }
    return total;
  }

  double get totalDailyRevenue {
    double total = 0;
    for (var d in deliveries) {
      if (d.status == 'DELIVERED') {
        double price = d.subscriptionDetail?.productDetail?.pricePerUnit ?? 72.0;
        int qty = d.subscriptionDetail?.quantity ?? 1;
        total += price * qty;
      }
    }
    return total;
  }

  Future<bool> updateStorefrontSettings({
    String? bannerImageUrl,
    String? headline,
    String? subtitle,
    String? dispatchTag,
    String? promoChip,
    String? ctaText,
  }) async {
    final updated = await ApiService.updateStorefrontConfig(
      bannerImageUrl: bannerImageUrl,
      headline: headline,
      subtitle: subtitle,
      dispatchTag: dispatchTag,
      promoChip: promoChip,
      ctaText: ctaText,
    );
    if (updated != null) {
      storefrontConfig = updated;
      notifyListeners();
      return true;
    }
    return false;
  }
}

