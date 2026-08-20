import 'package:flutter/material.dart';
import '../../models/customer_address_model.dart';
import '../../providers/app_state.dart';
import '../../screens/customer/notifications_screen.dart';

class HomeLocationBar extends StatelessWidget {
  final AppState state;
  final VoidCallback onLocationTap;

  const HomeLocationBar({
    super.key,
    required this.state,
    required this.onLocationTap,
  });

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getTownOrCity(CustomerAddressModel? activeAddr, String rawAddress) {
    if (activeAddr != null && activeAddr.city.isNotEmpty) {
      final street = activeAddr.streetAddress;
      if (street.isNotEmpty) {
        final parts = street.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (parts.isNotEmpty) {
          final lastSegment = parts.last;
          if (lastSegment.toLowerCase() != activeAddr.city.toLowerCase() && lastSegment.length < 25) {
            return '$lastSegment, ${activeAddr.city}';
          }
        }
      }
      return activeAddr.city;
    }

    if (rawAddress.isNotEmpty && rawAddress != 'Select Delivery Location') {
      final parts = rawAddress.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.length >= 2) {
        final locality = parts[parts.length - 2].replaceAll(RegExp(r'\d+'), '').trim();
        final city = parts.last.replaceAll(RegExp(r'\d+'), '').trim();
        if (locality.isNotEmpty && city.isNotEmpty && locality.toLowerCase() != city.toLowerCase() && locality.length < 20) {
          return '$locality, $city';
        }
        if (city.isNotEmpty) return city;
      } else if (parts.isNotEmpty) {
        final town = parts.last.replaceAll(RegExp(r'\d+'), '').trim();
        if (town.isNotEmpty) return town;
      }
    }

    return 'Kodad';
  }

  @override
  Widget build(BuildContext context) {
    final activeAddr = state.activeAddress;
    final fullAddress = activeAddr?.summaryAddress ?? state.currentDeliveryAddress;
    final townCity = _getTownOrCity(activeAddr, fullAddress);
    final userFirstName = state.currentUser?.firstName.isNotEmpty == true
        ? state.currentUser!.firstName
        : (state.currentUser?.username.isNotEmpty == true ? state.currentUser!.username : 'Customer');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF0D7C66),
            Color(0xFF14A38B),
          ],
          stops: <double>[0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0D7C66).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          '${_greeting()} ✨',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.verified_rounded, size: 10, color: Color(0xFF34D399)),
                              SizedBox(width: 3),
                              Text(
                                'VERIFIED',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF34D399),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      userFirstName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: onLocationTap,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: Color(0xFFFFD700),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '${townCity.toUpperCase()} • ⚡ 6 AM Fresh Drop',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => NotificationsScreen(state: state),
                    ),
                  );
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                      if (state.unreadNotificationCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE11D48),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
