import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import 'driver_route_map_screen.dart';
import 'morning_batch_screen.dart';

class DriverProfileTab extends StatefulWidget {
  final AppState state;
  final VoidCallback onLogout;

  const DriverProfileTab({
    super.key,
    required this.state,
    required this.onLogout,
  });

  @override
  State<DriverProfileTab> createState() => _DriverProfileTabState();
}

class _DriverProfileTabState extends State<DriverProfileTab> {
  bool _isOnDuty = true;

  @override
  Widget build(BuildContext context) {
    final driverUser = widget.state.currentUser;
    final driverName = (driverUser != null && driverUser.fullName.isNotEmpty && driverUser.fullName != 'User')
        ? driverUser.fullName
        : (driverUser?.username.isNotEmpty == true ? driverUser!.username : 'Delivery Partner');
    final driverPhone = driverUser?.phone.isNotEmpty == true ? driverUser!.phone : 'Unregistered Phone';
    final driverId = driverUser != null && driverUser.id > 0 ? 'DRV-${driverUser.id}' : 'DRV-101';

    final activeHub = widget.state.nearestCoveringHub ?? (widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null);
    final hubName = activeHub != null ? (activeHub['name']?.toString() ?? 'Kodad Depot') : 'Kodad Depot';
    final managerName = activeHub != null && activeHub['manager_name'] != null && activeHub['manager_name'].toString().isNotEmpty
        ? activeHub['manager_name'].toString()
        : 'Srinuvasa Reddy';
    final managerPhone = activeHub != null && activeHub['manager_phone'] != null && activeHub['manager_phone'].toString().isNotEmpty
        ? activeHub['manager_phone'].toString()
        : '8885199878';

    final salaryText = (driverUser != null && driverUser.monthlySalary > 0)
        ? '₹${driverUser.monthlySalary.toStringAsFixed(0)}'
        : '₹15,000';

    final vehicleText = (driverUser != null && driverUser.vehicleNumber.isNotEmpty)
        ? driverUser.vehicleNumber
        : 'EV Scooter (Tap to Register)';
    final licenseText = (driverUser != null && driverUser.drivingLicense.isNotEmpty)
        ? driverUser.drivingLicense
        : 'DL Verified (Tap to Update)';

    final totalStops = widget.state.deliveries.length;
    final completedStops = widget.state.deliveries.where((d) => d.status == 'DELIVERED').length;
    final pendingStops = widget.state.deliveries.where((d) => d.status == 'PENDING').length;
    final onTimePct = totalStops > 0 ? ((completedStops / totalStops) * 100).toStringAsFixed(1) : '100.0';

    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Part 1: Hero Header ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF0D7C66), Color(0xFF044E3A)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: [
                BoxShadow(color: Color(0x250D7C66), blurRadius: 20, offset: Offset(0, 10)),
              ],
            ),
            padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row
                Row(
                  children: [
                    const Text(
                      'Driver Profile',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const Spacer(),
                    // Interactive Duty Status Toggle
                    GestureDetector(
                      onTap: () => _toggleDutyStatus(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _isOnDuty
                              ? const Color(0xFF10B981).withValues(alpha: 0.25)
                              : Colors.red.withValues(alpha: 0.25),
                          border: Border.all(
                            color: _isOnDuty ? const Color(0xFF34D399) : Colors.redAccent,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isOnDuty ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                              size: 13,
                              color: _isOnDuty ? const Color(0xFF34D399) : Colors.redAccent,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isOnDuty ? 'On Duty' : 'Off Duty',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Edit Profile Action
                    GestureDetector(
                      onTap: () => _showEditDriverProfileDialog(context, widget.state, driverName, driverPhone, vehicleText, licenseText),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded, size: 15, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Avatar stack
                Center(
                  child: GestureDetector(
                    onTap: () => _showEditDriverProfileDialog(context, widget.state, driverName, driverPhone, vehicleText, licenseText),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0.40)],
                            ),
                            boxShadow: const [
                              BoxShadow(color: Color(0x30000000), blurRadius: 16, offset: Offset(0, 6)),
                            ],
                          ),
                          child: const Center(
                            child: CircleAvatar(
                              radius: 38,
                              backgroundColor: Color(0xFF0D7C66),
                              child: Text('🛵', style: TextStyle(fontSize: 36)),
                            ),
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.edit, size: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Name row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 20, color: Color(0xFF38BDF8)),
                  ],
                ),
                const SizedBox(height: 6),

                // Phone & ID pill
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        Text(
                          'Verified Delivery Partner • ID #$driverId',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Part 2: Scrollable Content ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              children: [
                // Quick Metrics Strip (Interactive)
                Row(
                  children: [
                    _buildQuickStatCard(
                      '4.9 ★',
                      'Driver Rating',
                      Icons.star_rounded,
                      const Color(0xFFF59E0B),
                      const Color(0xFFFEF3C7),
                      () => _showRatingBreakdownSheet(context),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickStatCard(
                      '$onTimePct%',
                      'On-Time Drops',
                      Icons.timer_rounded,
                      const Color(0xFF10B981),
                      const Color(0xFFD1FAE5),
                      () => _showOnTimePerformanceSheet(context, widget.state),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickStatCard(
                      salaryText,
                      'Monthly Salary',
                      Icons.payments_rounded,
                      const Color(0xFF0D7C66),
                      const Color(0xFFE6F5F0),
                      () => _showSalaryDetailsSheet(context, salaryText, hubName),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section 1: Route & Shift Details
                _buildSectionHeader('Route & Shift Assignment'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildMenuTile(
                    icon: Icons.map_rounded,
                    iconBg: const Color(0xFFE8F2FE),
                    iconFg: const Color(0xFF2563EB),
                    label: 'Morning Route #1 • $hubName',
                    subtitle: 'Assigned Urban Zone & GPS Navigation',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DriverRouteMapScreen(state: widget.state, tasks: widget.state.deliveries),
                      ),
                    ),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.schedule_rounded,
                    iconBg: const Color(0xFFE0F7F3),
                    iconFg: const Color(0xFF0D9488),
                    label: 'Shift: 05:00 AM – 08:30 AM Daily',
                    subtitle: 'Morning delivery window & attendance',
                    onTap: () => _showShiftTimingDialog(context),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.two_wheeler_rounded,
                    iconBg: const Color(0xFFFFF3E6),
                    iconFg: const Color(0xFFE67E22),
                    label: 'Vehicle: $vehicleText',
                    subtitle: 'License: $licenseText',
                    onTap: () => _showVehicleKycDialog(context, vehicleText, licenseText, widget.state),
                  ),
                ]),

                const SizedBox(height: 20),

                // Section 2: Operations & Hub Dispatch
                _buildSectionHeader('Operations & Hub Dispatch'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildMenuTile(
                    icon: Icons.warehouse_rounded,
                    iconBg: const Color(0xFFE6F5F0),
                    iconFg: const Color(0xFF0D7C66),
                    label: 'Dispatch Depot: $hubName',
                    subtitle: 'Crate pickup bay & cold storage facility',
                    onTap: () => _showDepotDetailsDialog(context, hubName, activeHub),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.inventory_2_rounded,
                    iconBg: const Color(0xFFEEF2FF),
                    iconFg: const Color(0xFF4F46E5),
                    label: 'Morning Batch Packing Crates',
                    subtitle: 'View crate breakdown & pack counts',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MorningBatchScreen(state: widget.state)),
                    ),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.support_agent_rounded,
                    iconBg: const Color(0xFFFEF2F2),
                    iconFg: const Color(0xFFEF4444),
                    label: 'Hub Manager Contact',
                    subtitle: '$managerName • $managerPhone',
                    onTap: () => _showManagerContactSheet(context, hubName, managerName, managerPhone),
                  ),
                ]),

                const SizedBox(height: 20),

                // Section 3: Safety & Partner Support
                _buildSectionHeader('Support & Partner Safety'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildMenuTile(
                    icon: Icons.headset_mic_rounded,
                    iconBg: const Color(0xFFFFF3E6),
                    iconFg: const Color(0xFFE67E22),
                    label: 'Emergency Delivery Support',
                    subtitle: '24x7 Driver SOS & road breakdown hotline',
                    onTap: () => _showEmergencySupportSheet(context),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.shield_outlined,
                    iconBg: const Color(0xFFF1F5F9),
                    iconFg: const Color(0xFF475569),
                    label: 'Driver Safety Guidelines & Terms',
                    subtitle: 'Zero spillage & cold chain standards',
                    onTap: () => _showSafetyGuidelinesSheet(context),
                  ),
                ]),

                const SizedBox(height: 24),

                // Logout Action
                GestureDetector(
                  onTap: () => _confirmDriverLogout(context, widget.state, widget.onLogout),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFE11D48)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Color(0x28E11D48), blurRadius: 16, offset: Offset(0, 6))],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Log out of Partner Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Version Footer
                const Center(
                  child: Text(
                    'MilkDrop Express Partner v1.0.0 • Dedicated Delivery Heroes 🛵',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ──

  Widget _buildQuickStatCard(String value, String label, IconData icon, Color fg, Color bg, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: fg, size: 18),
              ),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF334155), letterSpacing: -0.2),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5ECE8), width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x081A2B23), blurRadius: 12, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x051A2B23), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9), indent: 68);
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconFg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF1A2B23))),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFFC0C8C4)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Interactive Modals & Handlers ──

  void _toggleDutyStatus(BuildContext context) async {
    setState(() {
      _isOnDuty = !_isOnDuty;
    });

    final driverUser = widget.state.currentUser;
    final statusStr = _isOnDuty ? 'ON_DUTY' : 'OFFLINE';

    double lat = 17.001734;
    double lng = 79.9625;
    if (driverUser != null && driverUser.latitude != 0.0) {
      lat = driverUser.latitude;
      lng = driverUser.longitude;
    }

    await ApiService.updateDriverLocation(
      latitude: lat,
      longitude: lng,
      status: statusStr,
    );

    if (driverUser != null && driverUser.id > 0) {
      await ApiService.updateDriverStatus(driverUser.id, statusStr);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _isOnDuty ? const Color(0xFF0D7C66) : const Color(0xFFEF4444),
          content: Text(
            _isOnDuty ? '🟢 Status set to ON DUTY. GPS Broadcast live on Hub map!' : '⏸️ Status set to OFF DUTY. Break mode active.',
          ),
        ),
      );
    }
  }

  void _showEditDriverProfileDialog(
    BuildContext context,
    AppState state,
    String currentName,
    String currentPhone,
    String currentVehicle,
    String currentLicense,
  ) {
    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone);
    final vehicleCtrl = TextEditingController(text: currentVehicle);
    final licenseCtrl = TextEditingController(text: currentLicense);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Color(0xFF0D7C66)),
            SizedBox(width: 8),
            Text('Edit Partner Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Partner Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Registered Mobile Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vehicleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Registered Vehicle (e.g. EV Scooter TS 09)',
                  prefixIcon: Icon(Icons.two_wheeler_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: licenseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Driving License Number',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
            onPressed: () {
              final parts = nameCtrl.text.trim().split(' ');
              final first = parts.first;
              final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';

              state.updateUserProfile(
                firstName: first,
                lastName: last,
                phone: phoneCtrl.text.trim(),
                vehicleNumber: vehicleCtrl.text.trim(),
                drivingLicense: licenseCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF0D7C66),
                  content: Text('✅ Driver partner details updated successfully!'),
                ),
              );
            },
            child: const Text('Save Details'),
          ),
        ],
      ),
    );
  }

  void _showRatingBreakdownSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 28),
                const SizedBox(width: 8),
                const Text('4.9 / 5.0 Rating Score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
                  child: const Text('TOP 1% RIDER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Customer Feedback Highlights (Last 30 Days):', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            _buildScoreRow('⚡ On-Time Doorstep Delivery', '99.8% (Excellent)'),
            _buildScoreRow('🥛 Milk Pouch Handling & Hygiene', '100% Zero Leakage'),
            _buildScoreRow('🔔 Doorstep Bag Placement', '100% Verified'),
            _buildScoreRow('💬 Polite & Professional Behavior', '4.95 ★'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close Insights'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOnTimePerformanceSheet(BuildContext context, AppState state) {
    final pending = state.deliveries.where((d) => d.status == 'PENDING').length;
    final completed = state.deliveries.where((d) => d.status == 'DELIVERED').length;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timer_rounded, color: Color(0xFF10B981), size: 28),
                SizedBox(width: 8),
                Text('On-Time Delivery Performance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _buildScoreRow('📦 Today\'s Completed Drops', '$completed Drops'),
            _buildScoreRow('⏳ Pending Drops', '$pending Drops'),
            _buildScoreRow('⏱️ Average Time Per Doorstep', '3.8 Minutes'),
            _buildScoreRow('🎯 Morning Cutoff Compliance', '99.2% (Target: 95%)'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Great! Continue Route'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSalaryDetailsSheet(BuildContext context, String salaryText, String hubName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_rounded, color: Color(0xFF0D7C66), size: 28),
                const SizedBox(width: 8),
                Text('$salaryText / Month Fixed Pay', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F5F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0D7C66).withValues(alpha: 0.3)),
              ),
              child: Text(
                '💰 Monthly driver compensation is paid directly by your assigned Hub ($hubName) on the 1st - 5th of every month.',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), height: 1.4),
              ),
            ),
            const SizedBox(height: 14),
            _buildScoreRow('💵 Fixed Monthly Base', salaryText),
            _buildScoreRow('🎁 Morning Attendance Bonus', '₹1,500 / month'),
            _buildScoreRow('⛽ Fuel & Vehicle Allowance', 'Included with EV Battery Swap'),
            _buildScoreRow('📅 Next Payout Date', '1st of upcoming month'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close Salary Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShiftTimingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.schedule_rounded, color: Color(0xFF0D7C66)),
            SizedBox(width: 8),
            Text('Shift Hours & Schedule', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⏰ Standard Morning Shift: 05:00 AM – 08:30 AM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            SizedBox(height: 8),
            Text('• 04:45 AM: Report to Hub Cold Storage Bay for crate pickup.', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
            SizedBox(height: 4),
            Text('• 05:00 AM: Start doorstep deliveries along optimized route.', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
            SizedBox(height: 4),
            Text('• 07:30 AM: Standard deliveries complete.', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
            SizedBox(height: 4),
            Text('• 08:30 AM: Final handover of empty crates at Hub Depot.', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
        ],
      ),
    );
  }

  void _showVehicleKycDialog(BuildContext context, String vehicle, String license, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.two_wheeler_rounded, color: Color(0xFF0D7C66)),
            SizedBox(width: 8),
            Text('Vehicle & License KYC', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScoreRow('🛵 Vehicle Model', vehicle),
            _buildScoreRow('🪪 Commercial License', license),
            _buildScoreRow('🛡️ Vehicle Insurance', 'Valid & Active'),
            _buildScoreRow('🔋 Battery Swap Card', 'Unlimited Partner Access'),
            const SizedBox(height: 10),
            const Text('Need to update vehicle or renewal?', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _showEditDriverProfileDialog(
                context,
                state,
                state.currentUser?.fullName ?? 'Partner',
                state.currentUser?.phone ?? '',
                vehicle,
                license,
              );
            },
            child: const Text('Update Info'),
          ),
        ],
      ),
    );
  }

  void _showDepotDetailsDialog(BuildContext context, String hubName, Map<String, dynamic>? hub) {
    final address = hub != null && hub['address'] != null ? hub['address'].toString() : 'Kodad Depot Operations, Telangana';
    final managerName = hub != null && hub['manager_name'] != null ? hub['manager_name'].toString() : 'Srinuvasa Reddy';
    final managerPhone = hub != null && hub['manager_phone'] != null ? hub['manager_phone'].toString() : '8885199878';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warehouse_rounded, color: Color(0xFF0D7C66)),
            const SizedBox(width: 8),
            Flexible(child: Text(hubName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Depot Address:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            const SizedBox(height: 2),
            Text(address, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
            const SizedBox(height: 10),
            const Text('Morning Crate Loading Bay:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            const Text('Bay #1 (Cold Storage Dispatch Bay)', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
            const SizedBox(height: 10),
            const Text('Depot Manager:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            Text('$managerName ($managerPhone)', style: const TextStyle(fontSize: 12, color: Color(0xFF0D7C66), fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: address));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📋 Depot Address copied!')));
            },
            child: const Text('Copy Address'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showManagerContactSheet(BuildContext context, String hubName, String managerName, String managerPhone) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.support_agent_rounded, color: Color(0xFFEF4444), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$managerName ($hubName Lead)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(managerPhone, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                '📞 Direct line to $hubName Operations Lead ($managerName) for route assistance, morning stock shortages, crate issues, or customer query escalation.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final clean = managerPhone.replaceAll(RegExp(r'[^0-9]'), '');
                      final uri = Uri.parse('https://wa.me/91$clean?text=${Uri.encodeComponent("Hello $managerName, I need assistance with my morning delivery route at $hubName.")}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Text('💬', style: TextStyle(fontSize: 16)),
                    label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D7C66),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final clean = managerPhone.replaceAll(' ', '');
                      final uri = Uri.parse('tel:$clean');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('Call Lead', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencySupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emergency_rounded, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text('24x7 Partner Emergency Support', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Need urgent help during your morning delivery route?', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            _buildEmergencyActionTile(
              context,
              Icons.car_crash_rounded,
              'Road Breakdown & Battery Swap Tow',
              'Immediate mobile technician dispatch',
              '+91 8919548905',
            ),
            _buildEmergencyActionTile(
              context,
              Icons.location_off_rounded,
              'Customer Address or Gate Lock Issue',
              'Central Ops address re-routing',
              '+91 8885199878',
            ),
            _buildEmergencyActionTile(
              context,
              Icons.local_hospital_rounded,
              'Medical / SOS Assistance',
              '24x7 emergency medical line',
              '108',
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyActionTile(BuildContext context, IconData icon, String title, String subtitle, String phone) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.redAccent, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
      trailing: const Icon(Icons.phone_in_talk_rounded, color: Colors.redAccent, size: 20),
      onTap: () async {
        Navigator.pop(context);
        final uri = Uri.parse('tel:$phone');
        try {
          await launchUrl(uri);
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connecting to $title: $phone')));
        }
      },
    );
  }

  void _showSafetyGuidelinesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            const Row(
              children: [
                Icon(Icons.shield_rounded, color: Color(0xFF0D7C66), size: 28),
                SizedBox(width: 8),
                Text('Delivery Partner Safety Standards', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            _buildSafetyItem('1. Insulated Milk Bag & Chiller Rules', 'Always keep milk pouches in insulated crates with ice packs. Never expose crates to direct sun.'),
            _buildSafetyItem('2. Zero Pouch Damage Policy', 'Place pouches gently inside the customer doorstep delivery bag. Never drop or throw pouches.'),
            _buildSafetyItem('3. Contactless & Silent Morning Protocol', 'Between 05:00 AM – 07:00 AM, avoid honking or ringing bells unless specified in customer notes.'),
            _buildSafetyItem('4. Doorstep Photo Proof', 'Snap a quick doorstep photo on delivery completion for zero-dispute verification.'),
            _buildSafetyItem('5. Helmet & Road Safety First', 'Always wear your MilkDrop safety helmet and reflective vest while operating your vehicle.'),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('I Agree & Understand'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  void _confirmDriverLogout(BuildContext context, AppState state, VoidCallback onLogout) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Log Out Partner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to log out of your driver partner account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              state.setRole('CUSTOMER');
              Navigator.pop(ctx);
              onLogout();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
