import 'package:flutter/material.dart';
import '../../models/customer_address_model.dart';
import '../../providers/app_state.dart';
import '../../screens/customer/address_book_screen.dart';

class HomeLocationBar extends StatelessWidget {
  final AppState state;
  final VoidCallback onLocationTap;

  const HomeLocationBar({
    super.key,
    required this.state,
    required this.onLocationTap,
  });

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
    final iconText = activeAddr?.icon ?? '📍';
    final isDetecting = state.isDetectingLocation;

    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onLocationTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(iconText, style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                townCity.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              if (isDetecting)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: SizedBox(
                                    width: 8,
                                    height: 8,
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF10B981),
                                      strokeWidth: 1.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            activeAddr != null ? '${activeAddr.title} • $fullAddress' : fullAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => AddressBookScreen(state: state),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: Color(0xFF10B981), size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Book',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
