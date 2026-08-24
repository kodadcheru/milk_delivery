import 'package:flutter/material.dart';
import '../../models/customer_address_model.dart';
import '../../providers/app_state.dart';
import '../../services/location_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';
import 'map_location_picker_screen.dart';

class AddressBookScreen extends StatefulWidget {
  final AppState state;
  final bool isSelectingForCheckout;

  const AddressBookScreen({
    super.key,
    required this.state,
    this.isSelectingForCheckout = false,
  });

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  @override
  void initState() {
    super.initState();
    widget.state.fetchSavedAddresses();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: InkWell(
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
              ),
            ),
          ),
        ),
        title: const Text(
          'Saved Addresses 📍',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF10B981)),
            tooltip: 'Add New Address',
            onPressed: () => _openAddEditAddressSheet(context, widget.state),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) {
          final addresses = widget.state.savedAddresses;

          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0F2FE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_city_rounded,
                        size: 56,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Saved Addresses Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Save your home, office, and other locations for instant 1-tap morning milk delivery.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _openAddEditAddressSheet(context, state),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Add Delivery Address'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFFECFDF5),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF059669)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Active Delivery Location: ${state.currentDeliveryAddress.split(',').take(2).join(',')}',
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Quick 1-Tap "Use Current GPS Location" Action Card ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: InkWell(
                  onTap: () {
                    AppTheme.hapticLight();
                    _openAddEditAddressSheet(context, state, autoDetectGps: true);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.my_location_rounded, color: Color(0xFF0F766E), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Use Current GPS Location 📍',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Auto-detect exact live coordinates & autofill address',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF10B981)),
                      ],
                    ),
                  ),
                ),
              ),

              // Address Cards List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: addresses.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final addr = addresses[index];
                    final isActive = state.activeAddress?.id == addr.id ||
                        (state.activeAddress == null && addr.isDefault);

                    return _buildAddressCard(context, state, addr, isActive);
                  },
                ),
              ),

              // Bottom Add Address Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _openAddEditAddressSheet(context, state),
                    icon: const Icon(Icons.add_location_alt_outlined, color: Colors.white),
                    label: const Text(
                      'Add New Delivery Address',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAddressCard(
    BuildContext context,
    AppState appState,
    CustomerAddressModel addr,
    bool isActive,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive ? const Color(0x1A10B981) : Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Title + Badges
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(addr.icon, style: const TextStyle(fontSize: 18)),
                ),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (addr.isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'PRIMARY',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                          if (isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ACTIVE 📍',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${addr.city} • PIN ${addr.pincode}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                // Edit & Delete Popup Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8), size: 20),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openAddEditAddressSheet(context, appState, existing: addr);
                    } else if (value == 'default') {
                      appState.setDefaultCustomerAddress(addr.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("⭐ Set '${addr.title}' as primary delivery address"),
                          backgroundColor: const Color(0xFF0F172A),
                        ),
                      );
                    } else if (value == 'delete') {
                      _confirmDeleteAddress(context, appState, addr);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0F172A)),
                          SizedBox(width: 8),
                          Text('Edit Address'),
                        ],
                      ),
                    ),
                    if (!addr.isDefault)
                      const PopupMenuItem(
                        value: 'default',
                        child: Row(
                          children: [
                            Icon(Icons.star_border_rounded, size: 16, color: Color(0xFFD97706)),
                            SizedBox(width: 8),
                            Text('Set as Default'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Delete Address', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Street & House Details
            Text(
              addr.summaryAddress,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
                height: 1.35,
              ),
            ),

            if (addr.deliveryInstructions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.doorbell_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        addr.deliveryInstructions,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      appState.selectActiveAddress(addr);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("🚀 Delivering to '${addr.title}' (${addr.flatHouseNo.isNotEmpty ? addr.flatHouseNo : addr.streetAddress})"),
                          backgroundColor: const Color(0xFF10B981),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      if (widget.isSelectingForCheckout || Navigator.canPop(context)) {
                        Navigator.pop(context, addr);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive ? const Color(0xFF0F172A) : const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isActive ? 'Selected Active Address ✓' : 'Deliver Here 🚀',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAddress(BuildContext context, AppState appState, CustomerAddressModel addr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Address?'),
        content: Text("Are you sure you want to remove '${addr.title}' from your Address Book?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await appState.deleteCustomerAddress(addr.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("🗑️ '${addr.title}' removed from saved addresses")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  static void _openAddEditAddressSheet(
    BuildContext context,
    AppState state, {
    CustomerAddressModel? existing,
    bool autoDetectGps = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEditAddressModal(
        state: state,
        existing: existing,
        autoDetectGps: autoDetectGps,
      ),
    );
  }
}

class _AddEditAddressModal extends StatefulWidget {
  final AppState state;
  final CustomerAddressModel? existing;
  final bool autoDetectGps;

  const _AddEditAddressModal({
    required this.state,
    this.existing,
    this.autoDetectGps = false,
  });

  @override
  State<_AddEditAddressModal> createState() => _AddEditAddressModalState();
}

class _AddEditAddressModalState extends State<_AddEditAddressModal> {
  final _formKey = GlobalKey<FormState>();
  late String _addressType;
  late TextEditingController _customTagController;
  late TextEditingController _flatNoController;
  late TextEditingController _floorController;
  late TextEditingController _buildingController;
  late TextEditingController _streetController;
  late TextEditingController _landmarkController;
  late TextEditingController _cityController;
  late TextEditingController _pincodeController;
  late TextEditingController _instructionsController;
  double _lat = 17.4319;
  double _lon = 78.4073;
  bool _isDefault = false;
  bool _isSaving = false;
  bool _isDetectingGps = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _addressType = e?.addressType ?? 'HOME';
    _customTagController = TextEditingController(text: e?.customTag ?? '');
    _flatNoController = TextEditingController(text: e?.flatHouseNo ?? '');
    _floorController = TextEditingController(text: e?.floor ?? '');
    _buildingController = TextEditingController(text: e?.buildingName ?? '');
    _streetController = TextEditingController(
      text: e?.streetAddress ?? (widget.state.currentDeliveryAddress != 'Select Delivery Location' ? widget.state.currentDeliveryAddress : ''),
    );
    _landmarkController = TextEditingController(text: e?.landmark ?? '');
    _cityController = TextEditingController(text: e?.city ?? 'Hyderabad');
    _pincodeController = TextEditingController(text: e?.pincode ?? '');
    _instructionsController = TextEditingController(
      text: e?.deliveryInstructions ?? '',
    );
    _lat = e?.latitude ?? widget.state.currentLat;
    _lon = e?.longitude ?? widget.state.currentLon;
    _isDefault = e?.isDefault ?? (widget.state.savedAddresses.isEmpty);

    if (widget.autoDetectGps && widget.existing == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _useCurrentGPSLocation();
      });
    }
  }

  Future<void> _useCurrentGPSLocation() async {
    AppTheme.hapticLight();
    setState(() => _isDetectingGps = true);
    try {
      final pos = await PermissionService.getDeviceCoordinates();
      if (pos != null) {
        _lat = pos.latitude;
        _lon = pos.longitude;
        final loc = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
        if (loc != null) {
          setState(() {
            if (loc['full_address'] != null && loc['full_address'].toString().isNotEmpty) {
              _streetController.text = loc['full_address'];
            } else if (loc['short_address'] != null && loc['short_address'].toString().isNotEmpty) {
              _streetController.text = loc['short_address'];
            }
            if (loc['city'] != null && loc['city'].toString().isNotEmpty) {
              _cityController.text = loc['city'];
            }
            if (loc['postcode'] != null && loc['postcode'].toString().isNotEmpty) {
              _pincodeController.text = loc['postcode'];
            }
            if (loc['suburb'] != null && loc['suburb'].toString().isNotEmpty && _buildingController.text.isEmpty) {
              _buildingController.text = loc['suburb'];
            }
            if (loc['house_no'] != null && loc['house_no'].toString().isNotEmpty && _flatNoController.text.isEmpty) {
              _flatNoController.text = loc['house_no'];
            }
            if (loc['landmark'] != null && loc['landmark'].toString().isNotEmpty && _landmarkController.text.isEmpty) {
              _landmarkController.text = loc['landmark'];
            }
          });
          AppTheme.hapticSuccess();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📍 Current GPS location detected & populated!'),
                backgroundColor: AppTheme.primaryMint,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Unable to fetch GPS fix. Please ensure location is enabled.'),
            ),
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isDetectingGps = false);
      }
    }
  }

  @override
  void dispose() {
    _customTagController.dispose();
    _flatNoController.dispose();
    _floorController.dispose();
    _buildingController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickOnGoogleMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPickerScreen(
          state: widget.state,
          initialLat: _lat,
          initialLon: _lon,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _lat = double.tryParse(result['lat']?.toString() ?? '$_lat') ?? _lat;
        _lon = double.tryParse(result['lon']?.toString() ?? '$_lon') ?? _lon;
        if (result['full_address'] != null && result['full_address'].toString().isNotEmpty) {
          _streetController.text = result['full_address'];
        } else if (result['short_address'] != null && result['short_address'].toString().isNotEmpty) {
          _streetController.text = result['short_address'];
        }
        if (result['city'] != null && result['city'].toString().isNotEmpty) {
          _cityController.text = result['city'];
        }
        if (result['postcode'] != null && result['postcode'].toString().isNotEmpty) {
          _pincodeController.text = result['postcode'];
        }
        if (result['suburb'] != null && result['suburb'].toString().isNotEmpty && _buildingController.text.isEmpty) {
          _buildingController.text = result['suburb'];
        }
        if (result['house_no'] != null && result['house_no'].toString().isNotEmpty && _flatNoController.text.isEmpty) {
          _flatNoController.text = result['house_no'];
        }
        if (result['landmark'] != null && result['landmark'].toString().isNotEmpty && _landmarkController.text.isEmpty) {
          _landmarkController.text = result['landmark'];
        }
        if (result['tag'] != null && result['tag'].toString().isNotEmpty) {
          _addressType = result['tag'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_location_alt_rounded : Icons.add_location_alt_rounded,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(width: 10),
                Text(
                  isEditing ? 'Edit Address' : 'Add New Delivery Address',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Form Scrollable
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Address Type Selector (Home, Work, Other)
                  const Text(
                    'Save Address As',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildTypeButton('HOME', '🏠 Home'),
                      const SizedBox(width: 8),
                      _buildTypeButton('WORK', '💼 Work'),
                      const SizedBox(width: 8),
                      _buildTypeButton('OTHER', '📍 Other'),
                    ],
                  ),

                  if (_addressType == 'OTHER') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customTagController,
                      decoration: InputDecoration(
                        labelText: 'Custom Label (e.g. Parents Villa, Farm)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter label' : null,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── 📍 1-Tap "Use Current GPS Location" Button ──
                  InkWell(
                    onTap: _isDetectingGps ? null : _useCurrentGPSLocation,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF10B981)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _isDetectingGps
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isDetectingGps ? 'Detecting Live GPS...' : 'Use Current GPS Location 📍',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isDetectingGps
                                      ? 'Reverse-geocoding street & pin code...'
                                      : 'Auto-fill street, society, city & coordinates',
                                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Google Maps Pin Drop Button
                  InkWell(
                    onTap: _pickOnGoogleMap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.map_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pinpoint on Google Maps 🗺️',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                                Text(
                                  'Tap to adjust exact GPS delivery point & search societies',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF047857)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF059669)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Flat / House No & Floor
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _flatNoController,
                          decoration: InputDecoration(
                            labelText: 'Flat / House / Door No. *',
                            hintText: 'e.g. Flat 402',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _floorController,
                          decoration: InputDecoration(
                            labelText: 'Floor (Optional)',
                            hintText: 'e.g. 4th Floor',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Building / Society Name
                  TextFormField(
                    controller: _buildingController,
                    decoration: InputDecoration(
                      labelText: 'Apartment / Building / Society Name *',
                      hintText: 'e.g. My Home Bhooja, Rainbow Vistas',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                  ),

                  const SizedBox(height: 12),

                  // Street Address & Locality
                  TextFormField(
                    controller: _streetController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Street Address / Locality *',
                      hintText: 'e.g. Road No. 36, Jubilee Hills',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                  ),

                  const SizedBox(height: 12),

                  // Landmark
                  TextFormField(
                    controller: _landmarkController,
                    decoration: InputDecoration(
                      labelText: 'Nearby Landmark',
                      hintText: 'e.g. Opposite Peddamma Temple',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // City & Pincode
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          decoration: InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _pincodeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'PIN Code',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Doorstep Delivery Instructions
                  TextFormField(
                    controller: _instructionsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Doorstep Delivery Instructions 🥛',
                      hintText: 'e.g. Place in milk bag at door, do not ring bell before 6 AM',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Default Address Switch
                  SwitchListTile(
                    value: _isDefault,
                    onChanged: (val) => setState(() => _isDefault = val),
                    title: const Text(
                      'Make this my primary delivery address',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Morning milk deliveries and orders will default to this address',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    activeThumbColor: const Color(0xFF10B981),
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submitSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              isEditing ? 'Update Address' : 'Save Address to Book',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
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

  Widget _buildTypeButton(String type, String label) {
    final isSelected = _addressType == type;
    return Expanded(
      child: OutlinedButton(
        onPressed: () => setState(() => _addressType = type),
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFFECFDF5) : Colors.white,
          side: BorderSide(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF047857) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Future<void> _submitSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final newAddr = CustomerAddressModel(
      id: widget.existing?.id ?? 0,
      addressType: _addressType,
      customTag: _customTagController.text.trim(),
      flatHouseNo: _flatNoController.text.trim(),
      floor: _floorController.text.trim(),
      buildingName: _buildingController.text.trim(),
      streetAddress: _streetController.text.trim(),
      landmark: _landmarkController.text.trim(),
      city: _cityController.text.trim(),
      pincode: _pincodeController.text.trim(),
      latitude: _lat,
      longitude: _lon,
      deliveryInstructions: _instructionsController.text.trim(),
      isDefault: _isDefault,
    );

    final success = await widget.state.saveCustomerAddress(newAddr);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Saved '${newAddr.title}' to Address Book"),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save address. Please check connection.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
