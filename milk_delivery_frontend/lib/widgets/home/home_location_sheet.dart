import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../services/location_service.dart';
import '../../widgets/service_area_sheet.dart';
import '../../screens/customer/address_book_screen.dart';
import '../../screens/customer/map_location_picker_screen.dart';
import '../../theme/ui_tokens.dart';

class HomeLocationSheet {
  static void show(BuildContext context, AppState state) {
    if (state.savedAddresses.isEmpty) {
      state.fetchSavedAddresses();
    }
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: UiTone.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Delivery Location 📍',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Saved Addresses Section Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SAVED ADDRESSES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => AddressBookScreen(state: state),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_location_alt_rounded, size: 14, color: UiTone.secondary),
                    label: Text(
                      state.savedAddresses.isNotEmpty ? 'Manage Book' : '+ Add Address',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: UiTone.secondary,
                      ),
                    ),
                  ),
                ],
              ),

              if (state.savedAddresses.isNotEmpty) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.savedAddresses.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 8),
                    itemBuilder: (c, i) {
                      final addr = state.savedAddresses[i];
                      final isSelected = state.activeAddress?.id == addr.id;

                      return InkWell(
                        onTap: () {
                          state.selectActiveAddress(addr);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("🚀 Delivering to '${addr.title}'"),
                              backgroundColor: UiTone.secondary,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(UiRadius.sm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFECFDF5) : UiTone.shellBackground,
                            borderRadius: BorderRadius.circular(UiRadius.sm),
                            border: Border.all(
                              color: isSelected ? UiTone.secondary : UiTone.surfaceBorder,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(addr.icon, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          addr.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: UiTone.ink,
                                          ),
                                        ),
                                        if (addr.isDefault) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'PRIMARY',
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w800,
                                                color: UiTone.warning,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      addr.summaryAddress,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: UiTone.secondary, size: 18)
                              else
                                const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
              ],

              // Google Maps Search Bar
              TextField(
                controller: searchCtrl,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Search society, building, or street on Google Maps...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: UiTone.secondary),
                  suffixIcon: isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: UiTone.secondary),
                          ),
                        )
                      : (searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                searchCtrl.clear();
                                setModalState(() => searchResults = []);
                              },
                            )
                          : null),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  filled: true,
                  fillColor: UiTone.shellBackground,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (query) async {
                  if (query.trim().isEmpty) {
                    setModalState(() {
                      searchResults = [];
                      isSearching = false;
                    });
                    return;
                  }
                  setModalState(() => isSearching = true);
                  final results = await LocationService.searchPlaces(query);
                  setModalState(() {
                    searchResults = results;
                    isSearching = false;
                  });
                },
                onSubmitted: (query) async {
                  if (query.trim().isEmpty) return;
                  setModalState(() => isSearching = true);
                  final results = await LocationService.searchPlaces(query);
                  setModalState(() {
                    searchResults = results;
                    isSearching = false;
                  });
                },
              ),
              const SizedBox(height: 10),

              // Search Results List Dropdown
              if (searchResults.isNotEmpty) ...[
                const Text(
                  'Google Maps Results:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.ink),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: searchResults.length,
                    separatorBuilder: (ctx, sepIdx) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = searchResults[idx];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFECFDF5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.place_rounded, color: UiTone.secondary, size: 16),
                        ),
                        title: Text(
                          item['short_title'] ?? item['display_name'] ?? '',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          item['display_name'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        onTap: () {
                          final lat = (item['lat'] as num?)?.toDouble() ?? 17.4319;
                          final lon = (item['lon'] as num?)?.toDouble() ?? 78.4073;
                          final chosenAddr = item['display_name'] ?? item['short_title'] ?? 'Custom Address';
                          state.updateDeliveryLocation(chosenAddr, lat, lon);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: UiTone.secondary,
                              content: Text('📍 Delivery address updated to: $chosenAddr'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 16),
              ],

              // Quick Location Action Tiles
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: UiTone.secondary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.my_location_rounded, color: UiTone.secondary, size: 20),
                ),
                title: const Text('Use Current Device GPS Location 📍', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Auto-detect and reverse-geocode doorstep address', style: TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () async {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('📍 Detecting current location via GPS...')),
                  );
                  bool ok = await state.requestDeviceGPS();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: UiTone.secondary,
                        content: Text(ok ? '📍 Location auto-filled to: ${state.currentDeliveryAddress}' : 'Location permission needed.'),
                      ),
                    );
                  }
                },
              ),
              const Divider(height: 10),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: UiTone.accentBlue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.map_rounded, color: UiTone.accentBlue, size: 20),
                ),
                title: const Text('Pick on Google Map / Pin Doorstep 🗺️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                subtitle: const Text('Interactive map with live draggable pin & search', style: TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: const Icon(Icons.chevron_right_rounded, color: UiTone.accentBlue),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => MapLocationPickerScreen(state: state),
                    ),
                  );
                },
              ),
              const Divider(height: 10),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_city_rounded, color: Color(0xFF6366F1), size: 20),
                ),
                title: const Text('Browse Hyderabad Service Zones 🏙️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(
                  'Current Zone: ${state.selectedServiceArea.name}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6366F1)),
                onTap: () {
                  Navigator.pop(ctx);
                  ServiceAreaSheet.show(context, state);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
