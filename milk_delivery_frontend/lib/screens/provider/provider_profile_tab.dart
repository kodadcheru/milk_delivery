import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../driver/morning_batch_screen.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';
import '../../widgets/ui_kit/ui_kit.dart';

class ProviderProfileTab extends StatefulWidget {
  final AppState state;
  final VoidCallback onLogout;

  const ProviderProfileTab({
    super.key,
    required this.state,
    required this.onLogout,
  });

  @override
  State<ProviderProfileTab> createState() => _ProviderProfileTabState();
}

class _ProviderProfileTabState extends State<ProviderProfileTab> {
  bool _isDepotActive = true;
  String _dispatchWindow = '04:30 AM (Cold Storage) – 07:00 AM Complete';

  @override
  Widget build(BuildContext context) {
    final activeHub = widget.state.nearestCoveringHub ?? (widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null);
    final hubCode = activeHub != null ? (activeHub['hub_code'] ?? activeHub['id'] ?? 'HUB-DEFAULT').toString() : 'HUB-DEFAULT';
    final hubName = activeHub != null ? (activeHub['name']?.toString() ?? AppConfig.defaultHubName) : AppConfig.defaultHubName;
    final hubAddress = activeHub != null ? (activeHub['address']?.toString() ?? AppConfig.defaultHubAddress) : AppConfig.defaultHubAddress;
    final fssai = activeHub != null ? (activeHub['fssai_license']?.toString() ?? AppConfig.defaultFssai) : AppConfig.defaultFssai;
    final managerName = activeHub != null ? (activeHub['manager_name']?.toString() ?? 'Hub Operations Lead') : 'Hub Operations Lead';
    final managerPhone = activeHub != null && activeHub['manager_phone'] != null && activeHub['manager_phone'].toString().isNotEmpty
        ? activeHub['manager_phone'].toString()
        : AppConfig.supportPhone;

    final coverageRadius = (activeHub != null && activeHub['coverage_radius_km'] != null)
        ? (double.tryParse(activeHub['coverage_radius_km'].toString()) ?? 8.5)
        : 8.5;

    final bankName = activeHub != null ? (activeHub['bank_name']?.toString() ?? 'Primary Bank Account') : 'Primary Bank Account';
    final bankAccountNumber = activeHub != null ? (activeHub['bank_account_number']?.toString() ?? '') : '';
    final bankIfsc = activeHub != null ? (activeHub['bank_ifsc']?.toString() ?? '') : '';
    final bankAccountHolder = activeHub != null ? (activeHub['bank_account_holder']?.toString() ?? managerName) : managerName;
    final upiId = activeHub != null ? (activeHub['upi_id']?.toString() ?? '') : '';
    final bankAcc = bankAccountNumber.isNotEmpty
        ? '$bankName • A/C ending in ${bankAccountNumber.length >= 4 ? bankAccountNumber.substring(bankAccountNumber.length - 4) : bankAccountNumber}'
        : '$bankName • Details Pending Verification';

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
                        'Hub Depot Profile',
                        style: UiText.h1.copyWith(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const Spacer(),
                      // Depot Active Toggle
                      GestureDetector(
                        onTap: () => _toggleDepotStatus(context),
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
                                _isDepotActive ? Icons.storefront_rounded : Icons.store_mall_directory_outlined,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isDepotActive ? 'Depot Active' : 'Depot Paused',
                                style: UiText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Edit Hub Info Action
                      GestureDetector(
                        onTap: () => _showEditHubDialog(context, hubCode, hubName, hubAddress, managerPhone),
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
                      onTap: () => _showEditHubDialog(context, hubCode, hubName, hubAddress, managerPhone),
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
                            child: const Center(child: Text('🏬', style: TextStyle(fontSize: 40))),
                          ),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: UiTone.primary, width: 2),
                            ),
                            child: const Icon(Icons.check, size: 12, color: UiTone.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Hub Name row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          hubName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UiText.h1.copyWith(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, size: 20, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // FSSAI & ID pill
                  Center(
                    child: UiHeroGlass(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.security_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Verified FSSAI License #$fssai',
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
                      '100%',
                      'Dispatch Rate',
                      Icons.check_circle_rounded,
                      UiTone.success,
                      () => _showDispatchPerformanceSheet(context, widget.state),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickStatCard(
                      '${coverageRadius.toStringAsFixed(1)} km',
                      'Coverage Area',
                      Icons.radar_rounded,
                      UiTone.accentBlue,
                      () => _showCoverageAreaSheet(context, hubCode, hubName, coverageRadius),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickStatCard(
                      'Daily',
                      'Auto Payouts',
                      Icons.account_balance_rounded,
                      UiTone.primary,
                      () => _showPayoutSettlementSheet(context, bankAcc),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section 1: Depot Operations
                _buildSectionHeader('Depot Operations & Logistics'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildMenuTile(
                    icon: Icons.place_rounded,
                    accent: UiTone.accentBlue,
                    label: 'Depot Address',
                    subtitle: hubAddress,
                    onTap: () => _showDepotAddressDialog(context, hubName, hubAddress),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.radar_rounded,
                    accent: UiTone.accentBlue,
                    label: 'Delivery Coverage Area',
                    subtitle: '${coverageRadius.toStringAsFixed(1)} km Municipal Geofenced Radius',
                    onTap: () => _showCoverageAreaSheet(context, hubCode, hubName, coverageRadius),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.schedule_rounded,
                    accent: UiTone.primary,
                    label: 'Morning Dispatch Window',
                    subtitle: _dispatchWindow,
                    onTap: () => _showDispatchWindowConfigDialog(context),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.account_balance_rounded,
                    accent: UiTone.warning,
                    label: 'Settlement Bank Account',
                    subtitle: bankAcc,
                    onTap: () => _showBankDetailsDialog(
                      context,
                      hubCode,
                      hubName,
                      bankName,
                      bankAccountNumber,
                      bankIfsc,
                      bankAccountHolder,
                      upiId,
                    ),
                  ),
                ]),

                const SizedBox(height: 20),

                // Section 2: Fleet & Quality Controls
                _buildSectionHeader('Fleet & Quality Management'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildMenuTile(
                    icon: Icons.inventory_2_rounded,
                    accent: UiTone.accentPurple,
                    label: 'Morning Batch Packing Crates',
                    subtitle: 'Manage crate breakdowns & packet counts',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MorningBatchScreen(state: widget.state)),
                    ),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.sanitizer_rounded,
                    accent: UiTone.primary,
                    label: 'Cold Storage & FSSAI Standards',
                    subtitle: 'Grade-A chillers & dairy freshness audit (3.8°C avg)',
                    onTap: () => _showQualityAuditDialog(context, fssai),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.support_agent_rounded,
                    accent: UiTone.error,
                    label: 'Central Operations Desk',
                    subtitle: managerPhone,
                    onTap: () => _showCentralOpsContactSheet(context, managerPhone),
                  ),
                ]),

                const SizedBox(height: 20),

                // Section 3: Legal & Support
                _buildSectionHeader('Depot Agreements & Compliance'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildMenuTile(
                    icon: Icons.description_outlined,
                    accent: UiTone.softText,
                    label: 'Provider Merchant Agreement',
                    subtitle: 'Fulfillment terms & commission structure',
                    onTap: () => _showMerchantAgreementSheet(context),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.headset_mic_rounded,
                    accent: UiTone.warning,
                    label: 'Hub Partner Support',
                    subtitle: 'Milk supply replacement & packaging desk',
                    onTap: () => _showHubSupportSheet(context),
                  ),
                ]),

                const SizedBox(height: 24),

                // Logout Action
                GestureDetector(
                  onTap: () => _confirmProviderLogout(context, widget.state, widget.onLogout),
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
                        Text('Log out of Provider Portal', style: UiText.bodyStrong.copyWith(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Version Footer
                Center(
                  child: Text(
                    'Pamba Hub Portal v1.0.0 • Powering Fresh Milk Logistics 🏬',
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

  void _toggleDepotStatus(BuildContext context) {
    setState(() {
      _isDepotActive = !_isDepotActive;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _isDepotActive ? UiTone.primary : UiTone.warning,
        content: Text(
          _isDepotActive
              ? '🟢 Location Hub is ACTIVE and receiving morning orders!'
              : '⏸️ Location Hub is PAUSED for maintenance.',
        ),
      ),
    );
  }

  void _showEditHubDialog(BuildContext context, String hubCode, String currentName, String currentAddress, String currentPhone) {
    final nameCtrl = TextEditingController(text: currentName);
    final addrCtrl = TextEditingController(text: currentAddress);
    final phoneCtrl = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: Row(
          children: [
            const Icon(Icons.store_rounded, color: UiTone.primary),
            const SizedBox(width: 8),
            Text('Edit Hub Depot Details', style: UiText.h2.copyWith(fontSize: 17)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Hub Depot Name', prefixIcon: Icon(Icons.business_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addrCtrl,
                decoration: const InputDecoration(labelText: 'Physical Depot Address', prefixIcon: Icon(Icons.place_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Manager Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newAddr = addrCtrl.text.trim();
              final newPhone = phoneCtrl.text.trim();

              if (widget.state.locationHubs.isNotEmpty) {
                widget.state.locationHubs.first['name'] = newName;
                widget.state.locationHubs.first['address'] = newAddr;
                widget.state.locationHubs.first['manager_phone'] = newPhone;
              }
              Navigator.pop(ctx);
              setState(() {});

              final ok = await ApiService.updateHubDetails(
                hubCode: hubCode,
                name: newName,
                address: newAddr,
                managerPhone: newPhone,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: ok ? UiTone.primary : UiTone.warning,
                    content: Text(ok
                        ? '✅ Hub Depot operational details updated & synced!'
                        : '⚠️ Saved locally. Network sync pending.'),
                  ),
                );
              }
            },
            child: const Text('Save Hub Info'),
          ),
        ],
      ),
    );
  }

  void _showDispatchPerformanceSheet(BuildContext context, AppState state) {
    final activeDeliveries = state.deliveries.length;
    final morningVolume = state.totalDailyMilkVolume;

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
                const Icon(Icons.check_circle_rounded, color: UiTone.success, size: 28),
                const SizedBox(width: 8),
                Text('100% On-Time Dispatch SLA', style: UiText.h2.copyWith(fontSize: 17)),
              ],
            ),
            const SizedBox(height: 14),
            _buildScoreRow('📦 Active Deliveries in Queue', '$activeDeliveries Orders'),
            _buildScoreRow('🥛 Morning Milk Volume Packaged', '${morningVolume.toStringAsFixed(1)} Litres'),
            _buildScoreRow('🛵 Assigned Delivery Drivers', '3 Active Partners'),
            _buildScoreRow('⏱️ Average Pack & Crate Time', '14 Minutes'),
            _buildScoreRow('⭐ Quality Satisfaction Index', '99.9% Zero Returns'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close Performance Stats'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCoverageAreaSheet(BuildContext context, String hubCode, String hubName, double currentRadius) {
    double radius = currentRadius;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.radar_rounded, color: UiTone.accentBlue, size: 28),
                  const SizedBox(width: 8),
                  Text('${radius.toStringAsFixed(1)} km Geofence Coverage', style: UiText.h2.copyWith(fontSize: 17)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: UiTone.infoSoft,
                  borderRadius: BorderRadius.circular(UiRadius.sm),
                  border: Border.all(color: UiTone.accentBlue.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '📍 $hubName accepts orders and dispatches morning delivery routes within a ${radius.toStringAsFixed(1)} km operating radius.',
                  style: UiText.body.copyWith(fontSize: 12.5, color: UiTone.accentBlue, height: 1.4),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Adjust Operating Radius:', style: UiText.bodyStrong.copyWith(fontSize: 13)),
                  Text('${radius.toStringAsFixed(1)} km', style: UiText.bodyStrong.copyWith(fontWeight: FontWeight.w900, color: UiTone.accentBlue, fontSize: 15)),
                ],
              ),
              Slider(
                value: radius.clamp(1.0, 30.0),
                min: 1.0,
                max: 30.0,
                divisions: 58,
                activeColor: UiTone.accentBlue,
                onChanged: (val) {
                  setModalState(() => radius = val);
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [3.0, 5.0, 8.5, 12.0, 15.0, 20.0].map((r) {
                  final isSelected = (radius - r).abs() < 0.2;
                  return ChoiceChip(
                    label: Text('${r.toStringAsFixed(r % 1 == 0 ? 0 : 1)} km'),
                    selected: isSelected,
                    selectedColor: UiTone.accentBlue,
                    labelStyle: UiText.label.copyWith(
                      color: isSelected ? Colors.white : UiTone.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                    onSelected: (_) => setModalState(() => radius = r),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UiTone.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (widget.state.locationHubs.isNotEmpty) {
                      widget.state.locationHubs.first['coverage_radius_km'] = radius;
                    }
                    setState(() {});

                    final ok = await ApiService.updateHubDetails(
                      hubCode: hubCode,
                      coverageRadiusKm: radius,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: ok ? UiTone.primary : UiTone.warning,
                          content: Text(ok
                              ? '✅ Coverage radius updated to ${radius.toStringAsFixed(1)} km! Synced with Admin Console.'
                              : '⚠️ Saved locally. Network sync pending.'),
                        ),
                      );
                    }
                  },
                  child: Text('Save Coverage Area', style: UiText.bodyStrong.copyWith(fontSize: 14, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPayoutSettlementSheet(BuildContext context, String bankAcc) {
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
                const Icon(Icons.account_balance_rounded, color: UiTone.primary, size: 28),
                const SizedBox(width: 8),
                Text('Daily Automated Bank Payouts', style: UiText.h2.copyWith(fontSize: 17)),
              ],
            ),
            const SizedBox(height: 14),
            _buildScoreRow('🏦 Linked Settlement Account', bankAcc),
            _buildScoreRow('⚡ Payout Frequency', 'Daily at 11:59 PM (T+0)'),
            _buildScoreRow('💵 Fulfillment Commission', 'Directly credited per Litre'),
            _buildScoreRow('📊 GST & Tax Invoices', 'Auto-generated monthly'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close Settlement Info'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDepotAddressDialog(BuildContext context, String hubName, String address) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: Row(
          children: [
            const Icon(Icons.place_rounded, color: UiTone.accentBlue),
            const SizedBox(width: 8),
            Flexible(child: Text(hubName, overflow: TextOverflow.ellipsis, style: UiText.h2.copyWith(fontSize: 17))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fulfillment Depot Address:', style: UiText.bodyStrong.copyWith(fontSize: 13)),
            const SizedBox(height: 4),
            Text(address, style: UiText.body.copyWith(fontSize: 12.5)),
            const SizedBox(height: 12),
            Text('Operating Hub Hours:', style: UiText.bodyStrong.copyWith(fontSize: 13)),
            Text('04:00 AM – 11:00 AM & 04:00 PM – 08:00 PM', style: UiText.body.copyWith(fontSize: 12.5)),
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

  void _showDispatchWindowConfigDialog(BuildContext context) {
    String selected = _dispatchWindow;
    final customCtrl = TextEditingController(text: selected);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
          title: Row(
            children: [
              const Icon(Icons.schedule_rounded, color: UiTone.primary),
              const SizedBox(width: 8),
              Text('Dispatch Window Hours', style: UiText.h2.copyWith(fontSize: 16.5)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Standard Slot or Set Custom Window:', style: UiText.body.copyWith(fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  '☀️ 05:00 AM – 07:30 AM',
                  '☀️ 05:30 AM – 08:00 AM',
                  '🌙 05:00 PM – 07:30 PM',
                  '🌙 06:00 PM – 08:30 PM',
                  '⚡ Dual: 05:30 AM & 06:00 PM',
                ].map((s) {
                  final isSel = selected.contains(s.replaceAll('☀️ ', '').replaceAll('🌙 ', '').replaceAll('⚡ ', ''));
                  final isEve = s.contains('🌙');
                  return ChoiceChip(
                    label: Text(s, style: UiText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.bold, color: isSel ? Colors.white : UiTone.ink)),
                    selected: isSel,
                    selectedColor: isEve ? const Color(0xFF7C3AED) : UiTone.primary,
                    backgroundColor: UiTone.surfaceMuted,
                    showCheckmark: false,
                    onSelected: (sel) {
                      if (sel) {
                        setDlgState(() {
                          selected = '$s (Cold Storage)';
                          customCtrl.text = selected;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: customCtrl,
                onChanged: (val) {
                  setDlgState(() => selected = val);
                },
                decoration: const InputDecoration(labelText: 'Custom Dispatch Window', prefixIcon: Icon(Icons.edit_calendar)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  _dispatchWindow = customCtrl.text.trim().isNotEmpty ? customCtrl.text.trim() : selected;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: UiTone.primary, content: Text('⏱️ Dispatch window saved: $_dispatchWindow')),
                );
              },
              child: const Text('Save Window'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBankDetailsDialog(
    BuildContext context,
    String hubCode,
    String hubName,
    String currentBankName,
    String currentAccountNum,
    String currentIfsc,
    String currentHolder,
    String currentUpi,
  ) {
    final bankNameCtrl = TextEditingController(text: currentBankName);
    final accountNumCtrl = TextEditingController(text: currentAccountNum);
    final ifscCtrl = TextEditingController(text: currentIfsc);
    final holderCtrl = TextEditingController(text: currentHolder);
    final upiCtrl = TextEditingController(text: currentUpi);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: Row(
          children: [
            const Icon(Icons.account_balance_rounded, color: UiTone.warning),
            const SizedBox(width: 8),
            Text('Settlement Bank Account', style: UiText.h2.copyWith(fontSize: 16.5)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bankNameCtrl,
                decoration: const InputDecoration(labelText: 'Bank Name', prefixIcon: Icon(Icons.account_balance_outlined)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: accountNumCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Bank Account Number', prefixIcon: Icon(Icons.credit_card_outlined)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ifscCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'IFSC Code', prefixIcon: Icon(Icons.pin_outlined)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: holderCtrl,
                decoration: const InputDecoration(labelText: 'Account Holder Name', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: upiCtrl,
                decoration: const InputDecoration(labelText: 'Linked UPI ID', prefixIcon: Icon(Icons.qr_code_outlined)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final newBank = bankNameCtrl.text.trim();
              final newAcc = accountNumCtrl.text.trim();
              final newIfsc = ifscCtrl.text.trim().toUpperCase();
              final newHolder = holderCtrl.text.trim();
              final newUpi = upiCtrl.text.trim();

              if (newBank.isEmpty || newAcc.isEmpty || newIfsc.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: UiTone.error, content: Text('Please enter Bank Name, Account Number, and IFSC Code.')),
                );
                return;
              }

              Navigator.pop(ctx);

              if (widget.state.locationHubs.isNotEmpty) {
                widget.state.locationHubs.first['bank_name'] = newBank;
                widget.state.locationHubs.first['bank_account_number'] = newAcc;
                widget.state.locationHubs.first['bank_ifsc'] = newIfsc;
                widget.state.locationHubs.first['bank_account_holder'] = newHolder;
                widget.state.locationHubs.first['upi_id'] = newUpi;
                widget.state.locationHubs.first['bank_account'] = '$newBank • A/C ending in ${newAcc.length >= 4 ? newAcc.substring(newAcc.length - 4) : newAcc}';
              }
              setState(() {});

              final ok = await ApiService.updateHubDetails(
                hubCode: hubCode,
                bankName: newBank,
                bankAccountNumber: newAcc,
                bankIfsc: newIfsc,
                bankAccountHolder: newHolder,
                upiId: newUpi,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: ok ? UiTone.primary : UiTone.warning,
                    content: Text(ok
                        ? '✅ Settlement bank account saved! Synced with Admin Console.'
                        : '⚠️ Saved locally. Network sync pending.'),
                  ),
                );
              }
            },
            child: const Text('Save Bank Details'),
          ),
        ],
      ),
    );
  }

  void _showQualityAuditDialog(BuildContext context, String fssai) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: Row(
          children: [
            const Icon(Icons.sanitizer_rounded, color: UiTone.primary),
            const SizedBox(width: 8),
            Text('Cold Chain & FSSAI Audit', style: UiText.h2.copyWith(fontSize: 16.5)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScoreRow('🛡️ FSSAI License #', fssai),
            _buildScoreRow('❄️ Chiller Temp Log', '3.8°C (Optimal: <4.0°C)'),
            _buildScoreRow('🥛 Milk Purity Score', '4.2% Fat • 8.5% SNF'),
            _buildScoreRow('🧪 Adulteration Check', '100% Pure (0 Negatives)'),
            _buildScoreRow('🧽 Depot Sanitization', 'Daily 03:30 AM Verified'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCentralOpsContactSheet(BuildContext context, String managerPhone) {
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
                      Text('Central Operations Desk', style: UiText.h2.copyWith(fontSize: 16)),
                      Text(managerPhone, style: UiText.body.copyWith(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: UiTone.primarySoft, shape: BoxShape.circle),
                child: const Icon(Icons.phone, color: UiTone.primary),
              ),
              title: Text('Call Central Operations Directly', style: UiText.bodyStrong.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(managerPhone),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse('tel:$managerPhone');
                try {
                  await launchUrl(uri);
                } catch (_) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calling: $managerPhone')));
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: UiTone.infoSoft, shape: BoxShape.circle),
                child: const Icon(Icons.copy_rounded, color: UiTone.accentBlue),
              ),
              title: Text('Copy Contact Number', style: UiText.bodyStrong.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: managerPhone));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📋 Ops Phone copied!')));
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showMerchantAgreementSheet(BuildContext context) {
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
                const Icon(Icons.description_outlined, color: UiTone.primary, size: 28),
                const SizedBox(width: 8),
                Text('Provider Merchant Agreement', style: UiText.h2.copyWith(fontSize: 17)),
              ],
            ),
            const SizedBox(height: 14),
            _buildAgreementItem('1. Micro-Fulfillment & Cold Chain SLA', 'The hub agrees to maintain milk below 4°C in commercial chillers and ensure 100% on-time crate handover by 05:00 AM.'),
            _buildAgreementItem('2. Daily Payout & Commission Structure', 'Commission per liter fulfilled is settled automatically on T+0 daily basis to the registered bank account.'),
            _buildAgreementItem('3. Delivery Partner Coordination', 'Assigned delivery drivers will report to the hub loading bay. Hub manager will facilitate morning pack distribution.'),
            _buildAgreementItem('4. Quality & Milk Freshness Guarantee', 'Only certified A2 / Pure Farm fresh milk tested for purity shall be packaged and dispatched.'),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close Agreement'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHubSupportSheet(BuildContext context) {
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
                const Icon(Icons.headset_mic_rounded, color: UiTone.warning, size: 28),
                const SizedBox(width: 8),
                Text('Hub Partner Escalation Desk', style: UiText.h2.copyWith(fontSize: 17)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Dedicated supply chain & operations desk for Location Hubs:', style: UiText.body.copyWith(fontSize: 13)),
            const SizedBox(height: 14),
            _buildSupportTile(context, Icons.local_shipping_rounded, 'Milk Supply Shortfall / Excess Request', '+91 8919548905'),
            _buildSupportTile(context, Icons.shopping_bag_outlined, 'Packaging Pouches & Crates Reorder', AppConfig.supportPhone),
            _buildSupportTile(context, Icons.build_rounded, 'Chiller Equipment & Maintenance SOS', '+91 8919548905'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportTile(BuildContext context, IconData icon, String title, String phone) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: UiTone.warning.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: UiTone.warning, size: 20),
      ),
      title: Text(title, style: UiText.bodyStrong.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.phone_in_talk_rounded, color: UiTone.primary, size: 20),
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

  Widget _buildAgreementItem(String title, String desc) {
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

  void _confirmProviderLogout(BuildContext context, AppState state, VoidCallback onLogout) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: UiTone.error),
            const SizedBox(width: 8),
            Text('Log Out Provider', style: UiText.h2.copyWith(fontSize: 16)),
          ],
        ),
        content: const Text('Are you sure you want to log out of the Location Hub provider portal?'),
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
