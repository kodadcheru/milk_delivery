import 'package:flutter/material.dart';
import '../../models/customer_address_model.dart';
import '../../providers/app_state.dart';
import '../../screens/customer/address_book_screen.dart';
import '../../theme/ui_tokens.dart';

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
      color: UiTone.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onLocationTap,
              borderRadius: BorderRadius.circular(UiRadius.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: UiTone.shellBackground,
                  borderRadius: BorderRadius.circular(UiRadius.sm),
                  border: Border.all(color: UiTone.surfaceBorder),
                  boxShadow: [
                    BoxShadow(
                      color: UiTone.ink.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: UiTone.primarySoft,
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
                                  color: UiTone.primary,
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
                                      color: UiTone.primary,
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
                            style: const TextStyle(
                              color: UiTone.softText,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: UiTone.softText, size: 20),
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
            borderRadius: BorderRadius.circular(UiRadius.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: UiTone.primarySoft,
                borderRadius: BorderRadius.circular(UiRadius.sm),
                border: Border.all(color: UiTone.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: UiTone.primary, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Book',
                    style: TextStyle(
                      color: UiTone.primary,
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
