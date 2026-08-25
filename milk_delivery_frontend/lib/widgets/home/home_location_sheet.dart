import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../services/location_service.dart';
import '../../widgets/service_area_sheet.dart';
import '../../screens/customer/address_book_screen.dart';
import '../../screens/customer/map_location_picker_screen.dart';
import '../../theme/ui_tokens.dart';

class HomeLocationSheet {
  static void show(BuildContext context, AppState state) {
    state.fetchSavedAddresses();
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: UiTone.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle indicator bar
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Title Row & Add Address Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Delivery Location 📍',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: UiTone.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: UiTone.softText),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── GPS Current Location Quick Button ──
              InkWell(
                onTap: () async {
                  setModalState(() => isSearching = true);
                  await state.requestDeviceGPS();
                  final lat = state.currentLat ?? 17.001734;
                  final lon = state.currentLon ?? 79.9625;
                  final res = await LocationService.reverseGeocode(lat, lon);
                  setModalState(() => isSearching = false);
                  final addrStr = res?['summary_address'] ?? res?['full_address'] ?? 'Kodad Central Hub, Telangana - 508206';
                  state.updateDeliveryLocation(addrStr, lat, lon);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: UiTone.primary,
                        content: Text("🎯 Located doorstep: $addrStr"),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE6F5F0), Color(0xFFD1FAE5)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: UiTone.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: UiTone.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Use Current GPS Location 🎯',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: UiTone.primaryDark,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Auto-detect precise doorstep coordinates in Kodad',
                              style: TextStyle(fontSize: 10.5, color: Color(0xFF047857), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: UiTone.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Saved Addresses Section Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SAVED ADDRESSES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
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
                    icon: const Icon(Icons.add_location_alt_rounded, size: 14, color: UiTone.primary),
                    label: Text(
                      state.savedAddresses.isNotEmpty ? 'Manage Book' : '+ Add Address',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: UiTone.primary,
                      ),
                    ),
                  ),
                ],
              ),

              if (state.savedAddresses.isNotEmpty) ...[
                SizedBox(
                  height: 82,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.savedAddresses.length,
                    separatorBuilder: (c, i) => const SizedBox(width: 10),
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
                              backgroundColor: UiTone.primary,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 200,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE6F5F0) : UiTone.shellBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? UiTone.primary : UiTone.surfaceBorder,
                              width: isSelected ? 1.8 : 1.0,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: UiTone.primary.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ] : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: isSelected ? UiTone.primary.withValues(alpha: 0.15) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isSelected ? UiTone.primary.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
                                ),
                                child: Center(
                                  child: Text(addr.icon, style: const TextStyle(fontSize: 16)),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            addr.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12.5,
                                              color: isSelected ? UiTone.primaryDark : UiTone.ink,
                                            ),
                                          ),
                                        ),
                                        if (addr.isDefault) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: const Text(
                                              'DEFAULT',
                                              style: TextStyle(
                                                fontSize: 7.5,
                                                fontWeight: FontWeight.w900,
                                                color: UiTone.warning,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      addr.summaryAddress,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), height: 1.2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),
              ],

              // Google Maps Search Bar
              TextField(
                controller: searchCtrl,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Search society, building, or street in Kodad...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12.5),
                  prefixIcon: const Icon(Icons.search_rounded, color: UiTone.primary),
                  suffixIcon: isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: UiTone.primary),
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
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: UiTone.primary, width: 1.5),
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
              ),
              const SizedBox(height: 10),

              // Search Results List
              if (searchResults.isNotEmpty) ...[
                const Text(
                  'Location Suggestions:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.ink),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
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
                            color: Color(0xFFE6F5F0),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.place_rounded, color: UiTone.primary, size: 16),
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
                          final lat = double.tryParse(item['lat']?.toString() ?? '17.001734') ?? 17.001734;
                          final lon = double.tryParse(item['lon']?.toString() ?? '79.9625') ?? 79.9625;
                          final chosenAddr = item['display_name'] ?? item['short_title'] ?? 'Custom Address';
                          state.updateDeliveryLocation(chosenAddr, lat, lon);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: UiTone.primary,
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

              // ── Pin on Map Button ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => MapLocationPickerScreen(state: state),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_rounded, size: 16, color: UiTone.primary),
                  label: const Text(
                    'Pin Doorstep Location on Map 🗺️',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: UiTone.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: UiTone.primary, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Service Area Check Button
              Center(
                child: TextButton.icon(
                  onPressed: () => ServiceAreaSheet.show(context, state),
                  icon: const Icon(Icons.verified_user_outlined, size: 13, color: Color(0xFF64748B)),
                  label: const Text(
                    'Check Active Kodad Hub Delivery Zones ⚡',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
