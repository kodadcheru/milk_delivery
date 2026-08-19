import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/customer_address_model.dart';
import '../models/product_model.dart';
import '../models/subscription_model.dart';
import '../models/delivery_task_model.dart';
import '../models/wallet_transaction_model.dart';
import '../models/notification_model.dart';
import '../models/live_order_model.dart';
import '../models/service_area_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/permission_service.dart';

class AppState extends ChangeNotifier {
  UserModel? currentUser;
  String currentRole = 'CUSTOMER';
  bool isLoading = false;
  String? errorMessage;

  bool isVacationMode = false;
  int currentTabIndex = 0;

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
  List<Map<String, dynamic>> locationHubs = [];

  // Distance helper in KM using Haversine formula
  double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // math.pi / 180
    final a = 0.5 - math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  Map<String, dynamic>? get nearestCoveringHub {
    if (locationHubs.isEmpty) return null;

    Map<String, dynamic>? bestHub;
    double minDistance = double.infinity;

    for (var hub in locationHubs) {
      final hLat = (hub['latitude'] as num?)?.toDouble() ?? 17.4319;
      final hLon = (hub['longitude'] as num?)?.toDouble() ?? 78.4073;
      final radius = (hub['coverage_radius_km'] as num?)?.toDouble() ?? 5.0;

      final dist = calculateDistanceKm(currentLat, currentLon, hLat, hLon);
      if (dist <= radius && dist < minDistance) {
        minDistance = dist;
        bestHub = hub;
      }
    }

    return bestHub;
  }

  bool get isLocationCovered => nearestCoveringHub != null;

  void selectServiceArea(ServiceAreaModel area) {
    selectedServiceArea = area;
    currentDeliveryAddress = '${area.name}, ${area.city}';
    currentLat = area.latitude;
    currentLon = area.longitude;
    notifyListeners();
  }

  List<ProductModel> products = [];
  List<SubscriptionModel> subscriptions = [];
  List<WalletTransactionModel> transactions = [];
  List<DeliveryTaskModel> deliveries = [];
  List<LiveOrderModel> liveOrders = [];
  List<NotificationModel> notifications = [];
  Map<String, dynamic>? adminSummary;

  // In-memory Shopping Cart State
  final Map<int, int> cartItems = {};

  int get totalCartItemCount => cartItems.values.fold(0, (sum, count) => sum + count);

  double get totalCartPrice {
    double total = 0.0;
    for (var entry in cartItems.entries) {
      final product = products.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => ProductModel(id: entry.key, name: 'Item', description: '', pricePerUnit: 50.0, unit: 'PACKET', unitQuantity: '1 Unit', imageUrl: ''),
      );
      total += product.pricePerUnit * entry.value;
    }
    return total;
  }

  List<MapEntry<ProductModel, int>> get cartProductsList {
    final list = <MapEntry<ProductModel, int>>[];
    for (var entry in cartItems.entries) {
      final product = products.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => ProductModel(id: entry.key, name: 'Item', description: '', pricePerUnit: 50.0, unit: 'PACKET', unitQuantity: '1 Unit', imageUrl: ''),
      );
      list.add(MapEntry(product, entry.value));
    }
    return list;
  }

  void addToCart(ProductModel product) {
    cartItems[product.id] = (cartItems[product.id] ?? 0) + 1;
    notifyListeners();
  }

  void decreaseCartQty(int productId) {
    if (!cartItems.containsKey(productId)) return;
    if (cartItems[productId]! > 1) {
      cartItems[productId] = cartItems[productId]! - 1;
    } else {
      cartItems.remove(productId);
    }
    notifyListeners();
  }

  void updateCartQty(int productId, int qty) {
    if (qty <= 0) {
      cartItems.remove(productId);
    } else {
      cartItems[productId] = qty;
    }
    notifyListeners();
  }

  void removeFromCart(int productId) {
    cartItems.remove(productId);
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
    final orderItems = cartProductsList.map((entry) {
      return OrderItemModel(
        product: entry.key,
        quantity: entry.value,
        unitPrice: entry.key.pricePerUnit,
      );
    }).toList();

    final total = totalCartPrice;
    final orderId = 'MD-${8000 + liveOrders.length + 1}';
    final addr = deliveryAddress ?? (activeAddress?.summaryAddress ?? (currentDeliveryAddress != 'Select Delivery Location' ? currentDeliveryAddress : 'Doorstep Drop'));
    final dateStr = deliveryDate ?? 'Tomorrow';
    final slotStr = deliverySlot ?? '05:30 AM - 07:00 AM';

    final hub = nearestCoveringHub;
    final driverPlaceholder = hub != null ? 'Assigning Partner (${hub['name']})...' : 'Assigning Delivery Partner...';

    final newOrder = LiveOrderModel(
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

    liveOrders.insert(0, newOrder);

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

    if (currentUser != null && currentUser!.walletBalance < 150.0) {
      notifications.insert(
        0,
        NotificationModel(
          id: notifications.length + 2,
          title: '⚠️ Wallet Balance Low (₹${currentUser!.walletBalance.toStringAsFixed(0)})',
          message: 'Your balance is below ₹150. Re-charge now for smooth morning milk drops!',
          notificationType: 'WALLET',
          isRead: false,
          createdAt: 'Just now',
        ),
      );
    }

    cartItems.clear();
    notifyListeners();
    return newOrder;
  }

  void updateOrderStatus(String orderId, String newStatus) {
    final idx = liveOrders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final old = liveOrders[idx];
      liveOrders[idx] = LiveOrderModel(
        id: old.id,
        orderType: old.orderType,
        items: old.items,
        totalAmount: old.totalAmount,
        status: newStatus,
        deliverySlot: old.deliverySlot,
        deliveryAddress: old.deliveryAddress,
        deliveryLatitude: old.deliveryLatitude,
        deliveryLongitude: old.deliveryLongitude,
        deliveryOtp: old.deliveryOtp,
        driverName: old.driverName,
        driverPhone: old.driverPhone,
        paymentStatus: old.paymentStatus,
        createdAt: old.createdAt,
      );
      notifications.insert(
        0,
        NotificationModel(
          id: notifications.length + 1,
          title: '🎉 Express Order $orderId Delivered!',
          message: 'Your express delivery was completed successfully by driver.',
          notificationType: 'DELIVERY',
          isRead: false,
          createdAt: 'Just now',
        ),
      );
      notifyListeners();
    }
  }

  Future<void> checkoutCart({
    String schedule = 'DAILY',
    String slot = '05:30 AM - 07:00 AM',
    String? deliveryAddress,
  }) async {
    for (var entry in cartProductsList) {
      await createNewSubscription(entry.key, entry.value, schedule);
    }
    cartItems.clear();
    notifyListeners();
  }

  int get unreadNotificationCount => notifications.where((n) => !n.isRead).length;

  AppState() {
    initApp();
  }

  Future<void> initApp() async {
    await initDevicePermissionsAndLocation();
    final savedToken = await ApiService.initAuthToken();
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

    try {
      final pos = await PermissionService.getDeviceCoordinates();
      if (pos != null) {
        currentLat = pos.latitude;
        currentLon = pos.longitude;
        hasLocationPermission = true;

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
    return hasLocationPermission;
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

  Future<void> reloadAllData() async {
    final user = await ApiService.fetchUserProfile();
    if (user != null) {
      currentUser = user;
      currentRole = user.role;
      if (user.address.isNotEmpty) {
        currentDeliveryAddress = user.address;
      }
      currentLat = user.latitude;
      currentLon = user.longitude;
    }

    await fetchSavedAddresses();
    products = await ApiService.fetchProducts();
    subscriptions = await ApiService.fetchSubscriptions();
    deliveries = await ApiService.fetchDeliveries();
    transactions = await ApiService.fetchWalletTransactions();
    notifications = await ApiService.fetchNotifications();

    locationHubs = await ApiService.fetchHubs();
    final fetchedAreas = await ApiService.fetchServiceAreas();
    if (fetchedAreas.isNotEmpty) {
      serviceAreas = fetchedAreas.map((json) => ServiceAreaModel.fromJson(json)).toList();
      selectedServiceArea = serviceAreas.first;
    }

    if (savedAddresses.isEmpty && locationHubs.isNotEmpty) {
      final h = locationHubs.first;
      currentLat = (h['latitude'] as num?)?.toDouble() ?? 16.9947;
      currentLon = (h['longitude'] as num?)?.toDouble() ?? 79.9750;
      currentDeliveryAddress = '${h['name'] ?? 'Kodad Depot'}, ${h['city'] ?? 'Telangana'}';
    }

    if (currentRole == 'ADMIN' || currentRole == 'PROVIDER') {
      adminSummary = await ApiService.fetchDeliverySummary();
    }

    notifyListeners();
  }

  // ── Customer Address Book Handlers ──
  Future<void> fetchSavedAddresses() async {
    try {
      final addrs = await ApiService.fetchCustomerAddresses();
      savedAddresses = addrs;
      if (addrs.isNotEmpty) {
        final defaultAddr = addrs.firstWhere((a) => a.isDefault, orElse: () => addrs.first);
        activeAddress = defaultAddr;
        currentDeliveryAddress = defaultAddr.summaryAddress;
        currentLat = defaultAddr.latitude;
        currentLon = defaultAddr.longitude;
      } else {
        activeAddress = null;
        if (locationHubs.isNotEmpty) {
          final h = locationHubs.first;
          currentLat = (h['latitude'] as num?)?.toDouble() ?? 16.9947;
          currentLon = (h['longitude'] as num?)?.toDouble() ?? 79.9750;
          currentDeliveryAddress = '${h['name'] ?? 'Kodad Depot'}, ${h['city'] ?? 'Telangana'}';
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  void selectActiveAddress(CustomerAddressModel addr) {
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
      selectActiveAddress(result);
      return true;
    }
    return false;
  }

  Future<bool> deleteCustomerAddress(int addressId) async {
    final success = await ApiService.deleteCustomerAddress(addressId);
    if (success) {
      savedAddresses.removeWhere((a) => a.id == addressId);
      if (activeAddress?.id == addressId) {
        if (savedAddresses.isNotEmpty) {
          selectActiveAddress(savedAddresses.first);
        }
      }
      notifyListeners();
      return true;
    }
    return false;
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
    bool ok = await ApiService.topUpWallet(amount, 'Recharge via $method');
    if (ok) {
      await reloadAllData();
    } else if (currentUser != null) {
      double newBal = currentUser!.walletBalance + amount;
      currentUser = currentUser!.copyWith(walletBalance: newBal);
      transactions.insert(
        0,
        WalletTransactionModel(
          id: transactions.length + 1,
          amount: amount,
          transactionType: 'CREDIT',
          description: 'Recharge via $method',
          createdAt: 'Just now',
        ),
      );
      notifyListeners();
    }
  }

  Future<void> createNewSubscription(ProductModel product, int qty, String schedule) async {
    final newSub = await ApiService.createSubscription(product.id, qty, schedule);
    if (newSub != null) {
      await reloadAllData();
    } else {
      int newId = 200 + subscriptions.length + 1;
      final sub = SubscriptionModel(
        id: newId,
        customerId: currentUser?.id ?? 1,
        productId: product.id,
        productDetail: product,
        quantity: qty,
        scheduleType: schedule,
        startDate: DateTime.now().toString().split(' ')[0],
        status: 'ACTIVE',
      );
      subscriptions.add(sub);
      deliveries.add(
        DeliveryTaskModel(
          id: 600 + deliveries.length + 1,
          subscriptionId: newId,
          subscriptionDetail: sub,
          deliveryDate: DateTime.now().toString().split(' ')[0],
          slotTime: '05:30 AM - 07:00 AM',
          status: 'PENDING',
          deliveryAddress: activeAddress?.summaryAddress ?? (currentDeliveryAddress != 'Select Delivery Location' ? currentDeliveryAddress : 'Doorstep Drop'),
          proofImageUrl: product.imageUrl.isNotEmpty
              ? product.imageUrl
              : 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&q=80',
        ),
      );
      notifyListeners();
    }
  }

  Future<void> updateSubscriptionQuantity(int subId, int newQty) async {
    bool ok = await ApiService.updateSubscription(subId, quantity: newQty);
    if (ok) {
      await reloadAllData();
    } else {
      subscriptions = subscriptions.map((s) {
        if (s.id == subId) return s.copyWith(quantity: newQty);
        return s;
      }).toList();
      notifyListeners();
    }
  }

  Future<void> updateSubscriptionSchedule(int subId, String newSchedule) async {
    bool ok = await ApiService.updateSubscription(subId, scheduleType: newSchedule);
    if (ok) {
      await reloadAllData();
    } else {
      subscriptions = subscriptions.map((s) {
        if (s.id == subId) return s.copyWith(scheduleType: newSchedule);
        return s;
      }).toList();
      notifyListeners();
    }
  }

  Future<void> toggleSubscriptionStatus(int subId) async {
    final sub = subscriptions.firstWhere((s) => s.id == subId, orElse: () => subscriptions.first);
    bool isPaused = sub.status == 'PAUSED';

    if (isPaused) {
      await ApiService.resumeSubscription(subId);
    } else {
      final todayStr = DateTime.now().toString().split(' ')[0];
      final nextMonthStr = DateTime.now().add(const Duration(days: 30)).toString().split(' ')[0];
      await ApiService.pauseSubscription(subId, todayStr, nextMonthStr);
    }
    await reloadAllData();
  }

  Future<void> pauseSubscriptionWithDates(int subId, String startDate, String endDate, String reason) async {
    await ApiService.pauseSubscription(subId, startDate, endDate);
    await reloadAllData();
  }

  Future<void> cancelSubscription(int subId) async {
    await ApiService.cancelSubscription(subId);
    await reloadAllData();
  }

  Future<void> markDeliveryCompleted(int taskId, String proofUrl) async {
    bool ok = await ApiService.completeDelivery(taskId, proofUrl);
    if (ok) {
      await reloadAllData();
    } else {
      deliveries = deliveries.map((d) {
        if (d.id == taskId) {
          return d.copyWith(status: 'DELIVERED', proofImageUrl: proofUrl, deliveredAt: '06:25 AM');
        }
        return d;
      }).toList();

      if (currentUser != null) {
        double newBal = currentUser!.walletBalance - 72.0;
        currentUser = currentUser!.copyWith(walletBalance: newBal > 0 ? newBal : 0.0);
      }
      notifyListeners();
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
    return total > 0 ? total : 250.0;
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
    return total > 0 ? total : 4500.0;
  }
}
