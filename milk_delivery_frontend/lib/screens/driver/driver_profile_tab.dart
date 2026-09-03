import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_format.dart';
import '../../widgets/ui_kit/ui_kit.dart';
import '../customer/help_support_screen.dart';
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

    final activeHub = widget.state.driverAssignedHub;
    final hubName = widget.state.driverHubName;
    final managerName = activeHub != null && activeHub['manager_name'] != null && activeHub['manager_name'].toString().isNotEmpty
        ? activeHub['manager_name'].toString()
        : 'Hub Operations Manager';
    final managerPhone = activeHub != null && activeHub['manager_phone'] != null && activeHub['manager_phone'].toString().isNotEmpty
        ? activeHub['manager_phone'].toString()
        : AppConfig.supportPhone;

    final salaryText = (driverUser != null && driverUser.monthlySalary > 0)
        ? UiFormat.price(driverUser.monthlySalary)
        : '₹15,000';

    final vehicleText = (driverUser != null && driverUser.vehicleNumber.isNotEmpty)
        ? driverUser.vehicleNumber
        : 'EV Scooter (Tap to Register)';
    final licenseText = (driverUser != null && driverUser.drivingLicense.isNotEmpty)
        ? driverUser.drivingLicense
        : 'DL Verified (Tap to Update)';

    final totalStops = widget.state.deliveries.length;
    final completedStops = widget.state.deliveries.where((d) => d.status == 'DELIVERED').length;
    final onTimePct = totalStops > 0 ? ((completedStops / totalStops) * 100).toStringAsFixed(1) : '100.0';

    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: UiTone.shellBackground,
      body: Column(
        children: [
          // ── Part 1: Hero Header ──
          Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 0),
            child: UiHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row
                  Row(
                    children: [
                      Text(
                        'Driver Profile',
                        style: UiText.h1.copyWith(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const Spacer(),
                      // Interactive Duty Status Toggle
                      GestureDetector(
                        onTap: () => _toggleDutyStatus(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.40)),
                            borderRadius: BorderRadius.circular(UiRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isOnDuty ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isOnDuty ? 'On Duty' : 'Off Duty',
                                style: UiText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
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
                  const SizedBox(height: 18),

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
                              color: Colors.white.withValues(alpha: 0.18),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 2),
                            ),
                            child: const Center(child: Text('🛵', style: TextStyle(fontSize: 40))),
                          ),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: UiTone.primary, width: 2),
                            ),
                            child: const Icon(Icons.edit, size: 12, color: UiTone.primary),
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
                      Flexible(
                        child: Text(
                          driverName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UiText.h1.copyWith(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, size: 20, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Phone & ID pill
                  Center(
                    child: UiHeroGlass(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.badge_outlined, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Verified Delivery Partner • ID #$driverId',
                            style: UiText.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
                      UiTone.warning,
                      () => _showRatingBreakdownSheet(context),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickStatCard(
                      '$onTimePct%',
                      'On-Time Drops',
                      Icons.timer_rounded,
                      UiTone.success,
                      () => _showOnTimePerformanceSheet(context, widget.state),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickStatCard(
                      salaryText,
                      'Monthly Salary',
                      Icons.payments_rounded,
                      UiTone.primary,
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
                    accent: UiTone.accentBlue,
                    label: 'Live Route Map • $hubName',
                    subtitle: 'Turn-by-turn doorstep navigation & GPS route',
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
                    accent: UiTone.primary,
                    label: 'Shift: ☀️ Morning & 🌙 Evening Drops',
                    subtitle: '05:00 AM – 08:30 AM & 05:00 PM – 08:30 PM',
                    onTap: () => _showShiftTimingDialog(context),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.two_wheeler_rounded,
                    accent: UiTone.warning,
                    label: 'Vehicle & License KYC',
                    subtitle: '$vehicleText • $licenseText',
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
                    accent: UiTone.primary,
                    label: 'Dispatch Depot: $hubName',
                    subtitle: 'Cold storage loading bay & operations desk',
                    onTap: () => _showDepotDetailsDialog(context, hubName, activeHub),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.wb_sunny_rounded,
                    accent: const Color(0xFFF59E0B),
                    label: '☀️ Morning Batch Packing Crates',
                    subtitle: '05:30 AM morning drop crate checklist',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MorningBatchScreen(
                          state: widget.state,
                          shiftName: 'Morning Batch ☀️',
                          slotFilter: 'MORNING',
                        ),
                      ),
                    ),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.nights_stay_rounded,
                    accent: const Color(0xFF7C3AED),
                    label: '🌙 Evening Batch Packing Crates',
                    subtitle: '05:00 PM evening drop crate checklist',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MorningBatchScreen(
                          state: widget.state,
                          shiftName: 'Evening Batch 🌙',
                          slotFilter: 'EVENING',
                        ),
                      ),
                    ),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.support_agent_rounded,
                    accent: UiTone.error,
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
                    icon: Icons.chat_bubble_outline_rounded,
                    accent: UiTone.primary,
                    label: 'Live Support & Hub Desk Chat',
                    subtitle: 'Direct 24/7 help with delivery routes & drops',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HelpSupportScreen(state: widget.state, initialTopic: 'Delivery Partner Route Assistance'))),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.headset_mic_rounded,
                    accent: UiTone.warning,
                    label: 'Emergency Delivery Support',
                    subtitle: '24x7 Driver SOS & road breakdown hotline',
                    onTap: () => _showEmergencySupportSheet(context),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.shield_outlined,
                    accent: UiTone.softText,
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
                      color: UiTone.error,
                      borderRadius: BorderRadius.circular(UiRadius.lg),
                      boxShadow: UiShadow.elevated,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('Log out of Partner Account', style: UiText.bodyStrong.copyWith(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Version Footer
                Center(
                  child: Text(
                    'Pamba Express Partner v1.0.0 • Dedicated Delivery Heroes 🛵',
                    style: UiText.caption.copyWith(fontSize: 12),
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

  Widget _buildQuickStatCard(String value, String label, IconData icon, Color accent, VoidCallback onTap) {
    return Expanded(
      child: UiStatCard(
        value: value,
        label: label,
        icon: icon,
        accent: accent,
        onTap: onTap,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: UiText.bodyStrong.copyWith(fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: -0.2),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(UiRadius.lg),
        border: Border.all(color: UiTone.surfaceBorder, width: 1),
        boxShadow: UiShadow.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, color: UiTone.surfaceMuted, indent: 68);
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color accent,
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
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(UiRadius.sm),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: UiText.bodyStrong.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: UiText.body.copyWith(fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: UiText.muted),
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
          backgroundColor: _isOnDuty ? UiTone.primary : UiTone.error,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: UiTone.primary),
            const SizedBox(width: 8),
            Text('Edit Partner Profile', style: UiText.h2.copyWith(fontSize: 17)),
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
            style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
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
                  backgroundColor: UiTone.primary,
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded, color: UiTone.warning, size: 28),
                const SizedBox(width: 8),
                Text('4.9 / 5.0 Rating Score', style: UiText.h2.copyWith(fontSize: 18)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: UiTone.warningSoft, borderRadius: BorderRadius.circular(UiRadius.sm)),
                  child: Text('TOP 1% RIDER', style: UiText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w800, color: UiTone.warning)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Customer Feedback Highlights (Last 30 Days):', style: UiText.body.copyWith(fontSize: 13)),
            const SizedBox(height: 12),
            _buildScoreRow('⚡ On-Time Doorstep Delivery', '99.8% (Excellent)'),
            _buildScoreRow('🥛 Milk Pouch Handling & Hygiene', '100% Zero Leakage'),
            _buildScoreRow('🔔 Doorstep Bag Placement', '100% Verified'),
            _buildScoreRow('💬 Polite & Professional Behavior', '4.95 ★'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_rounded, color: UiTone.success, size: 28),
                const SizedBox(width: 8),
                Text('On-Time Delivery Performance', style: UiText.h2.copyWith(fontSize: 17)),
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
                style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_rounded, color: UiTone.primary, size: 28),
                const SizedBox(width: 8),
                Text('$salaryText / Month Fixed Pay', style: UiText.h2.copyWith(fontSize: 17)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: UiTone.primarySoft,
                borderRadius: BorderRadius.circular(UiRadius.sm),
                border: Border.all(color: UiTone.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                '💰 Monthly driver compensation is paid directly by your assigned Hub ($hubName) on the 1st - 5th of every month.',
                style: UiText.body.copyWith(fontSize: 12.5, color: UiTone.ink, height: 1.4),
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
                style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: UiTone.primary),
            const SizedBox(width: 8),
            Text('Daily Shift Windows', style: UiText.h2.copyWith(fontSize: 17)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Morning Shift
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(UiRadius.sm),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wb_sunny_rounded, color: Color(0xFFF59E0B), size: 16),
                        const SizedBox(width: 6),
                        Text('☀️ Morning Dispatch (05:00 AM – 08:30 AM)', style: UiText.bodyStrong.copyWith(fontSize: 13, color: const Color(0xFFD97706))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('• 04:45 AM: Cold storage crate loading at Hub Depot.', style: UiText.body.copyWith(fontSize: 12)),
                    Text('• 05:00 AM: Start morning doorstep run (Slots: 05:30 AM & 07:00 AM).', style: UiText.body.copyWith(fontSize: 12)),
                    Text('• 08:30 AM: Morning run completed & empty crates handover.', style: UiText.body.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Evening Shift
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(UiRadius.sm),
                  border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.nights_stay_rounded, color: Color(0xFF7C3AED), size: 16),
                        const SizedBox(width: 6),
                        Text('🌙 Evening Dispatch (05:00 PM – 08:30 PM)', style: UiText.bodyStrong.copyWith(fontSize: 13, color: const Color(0xFF7C3AED))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('• 04:45 PM: Evening batch crate loading at Hub Depot.', style: UiText.body.copyWith(fontSize: 12)),
                    Text('• 05:00 PM: Start evening doorstep run (Slots: 05:00 PM & 06:30 PM).', style: UiText.body.copyWith(fontSize: 12)),
                    Text('• 08:30 PM: Evening run completed & return to Hub.', style: UiText.body.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: Row(
          children: [
            const Icon(Icons.two_wheeler_rounded, color: UiTone.primary),
            const SizedBox(width: 8),
            Text('Vehicle & License KYC', style: UiText.h2.copyWith(fontSize: 17)),
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
            Text('Need to update vehicle or renewal?', style: UiText.caption.copyWith(fontSize: 11.5)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
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
    final address = hub != null && hub['address'] != null ? hub['address'].toString() : AppConfig.defaultHubAddress;
    final managerName = hub != null && hub['manager_name'] != null ? hub['manager_name'].toString() : 'Hub Operations Manager';
    final managerPhone = hub != null && hub['manager_phone'] != null ? hub['manager_phone'].toString() : AppConfig.supportPhone;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: Row(
          children: [
            const Icon(Icons.warehouse_rounded, color: UiTone.primary),
            const SizedBox(width: 8),
            Flexible(child: Text(hubName, overflow: TextOverflow.ellipsis, style: UiText.h2.copyWith(fontSize: 17))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Depot Address:', style: UiText.bodyStrong.copyWith(fontSize: 12.5)),
            const SizedBox(height: 2),
            Text(address, style: UiText.body.copyWith(fontSize: 12)),
            const SizedBox(height: 10),
            Text('Morning Crate Loading Bay:', style: UiText.bodyStrong.copyWith(fontSize: 12.5)),
            Text('Bay #1 (Cold Storage Dispatch Bay)', style: UiText.body.copyWith(fontSize: 12)),
            const SizedBox(height: 10),
            Text('Depot Manager:', style: UiText.bodyStrong.copyWith(fontSize: 12.5)),
            Text('$managerName ($managerPhone)', style: UiText.bodyStrong.copyWith(fontSize: 12, color: UiTone.primary)),
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
            style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.support_agent_rounded, color: UiTone.error, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$managerName ($hubName Lead)', style: UiText.h2.copyWith(fontSize: 16)),
                      Text(managerPhone, style: UiText.body.copyWith(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: UiTone.errorSoft,
                borderRadius: BorderRadius.circular(UiRadius.sm),
                border: Border.all(color: UiTone.error.withValues(alpha: 0.4)),
              ),
              child: Text(
                '📞 Direct line to $hubName Operations Lead ($managerName) for route assistance, morning stock shortages, crate issues, or customer query escalation.',
                style: UiText.body.copyWith(fontSize: 12, color: UiTone.error, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: UiTone.success,
                      side: const BorderSide(color: UiTone.success),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                    ),
                    onPressed: () async {
                      final clean = managerPhone.replaceAll(RegExp(r'[^0-9]'), '');
                      final uri = Uri.parse('https://wa.me/91$clean?text=${Uri.encodeComponent("Hello $managerName, I need assistance with my morning delivery route at $hubName.")}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Text('💬', style: TextStyle(fontSize: 16)),
                    label: Text('WhatsApp', style: UiText.bodyStrong.copyWith(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UiTone.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                    ),
                    onPressed: () async {
                      final clean = managerPhone.replaceAll(' ', '');
                      final uri = Uri.parse('tel:$clean');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text('Call Lead', style: UiText.bodyStrong.copyWith(fontSize: 14, color: Colors.white)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emergency_rounded, color: UiTone.error, size: 28),
                const SizedBox(width: 8),
                Text('24x7 Partner Emergency Support', style: UiText.h2.copyWith(fontSize: 17)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Need urgent help during your morning delivery route?', style: UiText.body.copyWith(fontSize: 13)),
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
              AppConfig.supportPhone,
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
        decoration: BoxDecoration(color: UiTone.error.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: UiTone.error, size: 20),
      ),
      title: Text(title, style: UiText.bodyStrong.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: UiText.caption.copyWith(fontSize: 11.5)),
      trailing: const Icon(Icons.phone_in_talk_rounded, color: UiTone.error, size: 20),
      onTap: () async {
        Navigator.pop(context);
        final uri = Uri.parse('tel:$phone');
        try {
          await launchUrl(uri);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connecting to $title: $phone')));
          }
        }
      },
    );
  }

  void _showSafetyGuidelinesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const Icon(Icons.shield_rounded, color: UiTone.primary, size: 28),
                const SizedBox(width: 8),
                Text('Delivery Partner Safety Standards', style: UiText.h2.copyWith(fontSize: 17)),
              ],
            ),
            const SizedBox(height: 14),
            _buildSafetyItem('1. Insulated Milk Bag & Chiller Rules', 'Always keep milk pouches in insulated crates with ice packs. Never expose crates to direct sun.'),
            _buildSafetyItem('2. Zero Pouch Damage Policy', 'Place pouches gently inside the customer doorstep delivery bag. Never drop or throw pouches.'),
            _buildSafetyItem('3. Contactless & Silent Morning Protocol', 'Between 05:00 AM – 07:00 AM, avoid honking or ringing bells unless specified in customer notes.'),
            _buildSafetyItem('4. Doorstep Photo Proof', 'Snap a quick doorstep photo on delivery completion for zero-dispute verification.'),
            _buildSafetyItem('5. Helmet & Road Safety First', 'Always wear your Pamba safety helmet and reflective vest while operating your vehicle.'),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
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
          Text(title, style: UiText.bodyStrong.copyWith(fontSize: 13)),
          const SizedBox(height: 2),
          Text(desc, style: UiText.body.copyWith(fontSize: 12, height: 1.3)),
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
          Text(label, style: UiText.body.copyWith(fontSize: 13)),
          Text(value, style: UiText.bodyStrong.copyWith(fontSize: 13)),
        ],
      ),
    );
  }

  void _confirmDriverLogout(BuildContext context, AppState state, VoidCallback onLogout) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: UiTone.error),
            const SizedBox(width: 8),
            Text('Log Out Partner', style: UiText.h2.copyWith(fontSize: 16)),
          ],
        ),
        content: const Text('Are you sure you want to log out of your driver partner account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UiTone.error, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              onLogout();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
