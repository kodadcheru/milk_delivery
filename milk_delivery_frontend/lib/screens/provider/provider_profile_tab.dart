import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_state.dart';
import '../driver/morning_batch_screen.dart';

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
    final activeHub = widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null;
    final hubName = activeHub != null ? (activeHub['name'] ?? 'Central Dairy Depot') : 'Central Dairy Depot';
    final hubAddress = activeHub != null ? (activeHub['address'] ?? 'Central Depot Operations, Main Road, Kodad') : 'Central Depot Operations, Main Road, Kodad';
    final fssai = activeHub != null ? (activeHub['fssai_license'] ?? '13621014000342') : '13621014000342';
    final managerPhone = activeHub != null && activeHub['manager_phone'] != null && activeHub['manager_phone'].toString().isNotEmpty
        ? activeHub['manager_phone'].toString()
        : '+91 8919548905';

    final bankAcc = activeHub != null && activeHub['bank_account'] != null && activeHub['bank_account'].toString().isNotEmpty
        ? activeHub['bank_account'].toString()
        : 'HDFC Bank • A/C ending in 8421';

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
                colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0D7C66)],
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
                      'Hub Depot Profile',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const Spacer(),
                    // Depot Active Toggle
                    GestureDetector(
                      onTap: () => _toggleDepotStatus(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _isDepotActive
                              ? const Color(0xFF10B981).withValues(alpha: 0.25)
                              : Colors.amber.withValues(alpha: 0.25),
                          border: Border.all(
                            color: _isDepotActive ? const Color(0xFF34D399) : Colors.amberAccent,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isDepotActive ? Icons.storefront_rounded : Icons.store_mall_directory_outlined,
                              size: 13,
                              color: _isDepotActive ? const Color(0xFF34D399) : Colors.amberAccent,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isDepotActive ? 'Depot Active' : 'Depot Paused',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Edit Hub Info Action
                    GestureDetector(
                      onTap: () => _showEditHubDialog(context, hubName, hubAddress, managerPhone),
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
                    onTap: () => _showEditHubDialog(context, hubName, hubAddress, managerPhone),
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
                              backgroundColor: Color(0xFF0F172A),
                              child: Text('🏬', style: TextStyle(fontSize: 36)),
                            ),
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.check, size: 12, color: Colors.white),
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
                    Text(
                      hubName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 20, color: Color(0xFF38BDF8)),
                  ],
                ),
                const SizedBox(height: 6),

                // FSSAI & ID pill
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
                        const Icon(Icons.security_rounded, size: 14, color: Color(0xFF34D399)),
                        const SizedBox(width: 6),
                        Text(
                          'Verified FSSAI License #$fssai',
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
                      '100%',
                      'Dispatch Rate',
                      Icons.check_circle_rounded,
                      const Color(0xFF10B981),
                      const Color(0xFFD1FAE5),
                      () => _showDispatchPerformanceSheet(context, widget.state),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickStatCard(
                      '5.0 km',
                      'Coverage Area',
                      Icons.radar_rounded,
                      const Color(0xFF2563EB),
                      const Color(0xFFDBEAFE),
                      () => _showCoverageAreaSheet(context, hubName),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickStatCard(
                      'Daily',
                      'Auto Payouts',
                      Icons.account_balance_rounded,
                      const Color(0xFF0D7C66),
                      const Color(0xFFE6F5F0),
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
                    iconBg: const Color(0xFFE8F2FE),
                    iconFg: const Color(0xFF2563EB),
                    label: 'Depot Address',
                    subtitle: hubAddress,
                    onTap: () => _showDepotAddressDialog(context, hubName, hubAddress),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.schedule_rounded,
                    iconBg: const Color(0xFFE0F7F3),
                    iconFg: const Color(0xFF0D9488),
                    label: 'Morning Dispatch Window',
                    subtitle: _dispatchWindow,
                    onTap: () => _showDispatchWindowConfigDialog(context),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.account_balance_rounded,
                    iconBg: const Color(0xFFFFF3E6),
                    iconFg: const Color(0xFFE67E22),
                    label: 'Settlement Bank Account',
                    subtitle: bankAcc,
                    onTap: () => _showBankDetailsDialog(context, bankAcc),
                  ),
                ]),

                const SizedBox(height: 20),

                // Section 2: Fleet & Quality Controls
                _buildSectionHeader('Fleet & Quality Management'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _buildMenuTile(
                    icon: Icons.inventory_2_rounded,
                    iconBg: const Color(0xFFEEF2FF),
                    iconFg: const Color(0xFF4F46E5),
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
                    iconBg: const Color(0xFFE6F5F0),
                    iconFg: const Color(0xFF0D7C66),
                    label: 'Cold Storage & FSSAI Standards',
                    subtitle: 'Grade-A chillers & dairy freshness audit (3.8°C avg)',
                    onTap: () => _showQualityAuditDialog(context, fssai),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.support_agent_rounded,
                    iconBg: const Color(0xFFFEF2F2),
                    iconFg: const Color(0xFFEF4444),
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
                    iconBg: const Color(0xFFF1F5F9),
                    iconFg: const Color(0xFF475569),
                    label: 'Provider Merchant Agreement',
                    subtitle: 'Fulfillment terms & commission structure',
                    onTap: () => _showMerchantAgreementSheet(context),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.headset_mic_rounded,
                    iconBg: const Color(0xFFFFF3E6),
                    iconFg: const Color(0xFFE67E22),
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
                      gradient: const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFE11D48)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Color(0x28E11D48), blurRadius: 16, offset: Offset(0, 6))],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Log out of Provider Portal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Version Footer
                const Center(
                  child: Text(
                    'MilkDrop Hub Portal v1.0.0 • Powering Fresh Milk Logistics 🏬',
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

  void _toggleDepotStatus(BuildContext context) {
    setState(() {
      _isDepotActive = !_isDepotActive;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _isDepotActive ? const Color(0xFF0D7C66) : const Color(0xFFF59E0B),
        content: Text(
          _isDepotActive
              ? '🟢 Location Hub is ACTIVE and receiving morning orders!'
              : '⏸️ Location Hub is PAUSED for maintenance.',
        ),
      ),
    );
  }

  void _showEditHubDialog(BuildContext context, String currentName, String currentAddress, String currentPhone) {
    final nameCtrl = TextEditingController(text: currentName);
    final addrCtrl = TextEditingController(text: currentAddress);
    final phoneCtrl = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.store_rounded, color: Color(0xFF0D7C66)),
            SizedBox(width: 8),
            Text('Edit Hub Depot Details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
            onPressed: () {
              if (widget.state.locationHubs.isNotEmpty) {
                widget.state.locationHubs.first['name'] = nameCtrl.text.trim();
                widget.state.locationHubs.first['address'] = addrCtrl.text.trim();
                widget.state.locationHubs.first['manager_phone'] = phoneCtrl.text.trim();
              }
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF0D7C66),
                  content: Text('✅ Hub Depot operational details updated successfully!'),
                ),
              );
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                SizedBox(width: 8),
                Text('100% On-Time Dispatch SLA', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close Performance Stats'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCoverageAreaSheet(BuildContext context, String hubName) {
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
                Icon(Icons.radar_rounded, color: Color(0xFF2563EB), size: 28),
                SizedBox(width: 8),
                Text('5.0 km Micro-Cluster Coverage', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
              ),
              child: Text(
                '📍 $hubName serves all households within a 5.0 km geofenced radius in the municipal cluster.',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E3A8A), height: 1.4),
              ),
            ),
            const SizedBox(height: 14),
            _buildScoreRow('🗺️ Operating Sector', 'Kodad Central, Bank Colony, Main Road'),
            _buildScoreRow('📮 Pincode Cluster', '508206 & surrounding zones'),
            _buildScoreRow('⚡ Morning Drop Cutoff', '07:00 AM Guaranteed'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayoutSettlementSheet(BuildContext context, String bankAcc) {
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
                Icon(Icons.account_balance_rounded, color: Color(0xFF0D7C66), size: 28),
                SizedBox(width: 8),
                Text('Daily Automated Bank Payouts', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.place_rounded, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Flexible(child: Text(hubName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fulfillment Depot Address:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(address, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
            const SizedBox(height: 12),
            const Text('Operating Hub Hours:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Text('04:00 AM – 11:00 AM & 04:00 PM – 08:00 PM', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
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

  void _showDispatchWindowConfigDialog(BuildContext context) {
    String selected = _dispatchWindow;
    final customCtrl = TextEditingController(text: selected);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.schedule_rounded, color: Color(0xFF0D9488)),
              SizedBox(width: 8),
              Text('Dispatch Window Hours', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Standard Slot or Set Custom Window:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  '04:30 AM – 07:00 AM',
                  '05:00 AM – 07:30 AM',
                  '05:30 AM – 08:00 AM',
                ].map((s) {
                  final isSel = selected.contains(s);
                  return ChoiceChip(
                    label: Text(s, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isSel ? Colors.white : const Color(0xFF0F172A))),
                    selected: isSel,
                    selectedColor: const Color(0xFF0D7C66),
                    backgroundColor: const Color(0xFFF1F5F9),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  _dispatchWindow = customCtrl.text.trim().isNotEmpty ? customCtrl.text.trim() : selected;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: const Color(0xFF0D7C66), content: Text('⏱️ Dispatch window saved: $_dispatchWindow')),
                );
              },
              child: const Text('Save Window'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBankDetailsDialog(BuildContext context, String bankAcc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_rounded, color: Color(0xFFE67E22)),
            SizedBox(width: 8),
            Text('Settlement Bank Account', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScoreRow('🏦 Bank Name', 'HDFC Bank Ltd.'),
            _buildScoreRow('💳 Account Number', '50100482918421'),
            _buildScoreRow('🏛️ IFSC Code', 'HDFC0001842'),
            _buildScoreRow('📲 Linked UPI ID', 'milkdrop.kodad@hdfcbank'),
            _buildScoreRow('✅ Payout Verification', 'Verified & Active'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('To update bank details, please contact Central Operations verification desk.')),
              );
            },
            child: const Text('Request Change'),
          ),
        ],
      ),
    );
  }

  void _showQualityAuditDialog(BuildContext context, String fssai) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.sanitizer_rounded, color: Color(0xFF0D7C66)),
            SizedBox(width: 8),
            Text('Cold Chain & FSSAI Audit', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
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
                      const Text('Central Operations Desk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(managerPhone, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Color(0xFFE6F5F0), shape: BoxShape.circle),
                child: const Icon(Icons.phone, color: Color(0xFF0D7C66)),
              ),
              title: const Text('Call Central Operations Directly', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
                decoration: const BoxDecoration(color: Color(0xFFE8F2FE), shape: BoxShape.circle),
                child: const Icon(Icons.copy_rounded, color: Color(0xFF2563EB)),
              ),
              title: const Text('Copy Contact Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
                Icon(Icons.description_outlined, color: Color(0xFF0D7C66), size: 28),
                SizedBox(width: 8),
                Text('Provider Merchant Agreement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            _buildAgreementItem('1. Micro-Fulfillment & Cold Chain SLA', 'The hub agrees to maintain milk below 4°C in commercial chillers and ensure 100% on-time crate handover by 05:00 AM.'),
            _buildAgreementItem('2. Daily Payout & Commission Structure', 'Commission per liter fulfilled is settled automatically on T+0 daily basis to the registered bank account.'),
            _buildAgreementItem('3. Delivery Partner Coordination', 'Assigned delivery drivers will report to the hub loading bay. Hub manager will facilitate morning pack distribution.'),
            _buildAgreementItem('4. Quality & Milk Freshness Guarantee', 'Only certified A2 / Pure Farm fresh milk tested for purity shall be packaged and dispatched.'),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.headset_mic_rounded, color: Color(0xFFE67E22), size: 28),
                SizedBox(width: 8),
                Text('Hub Partner Escalation Desk', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Dedicated supply chain & operations desk for Location Hubs:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            _buildSupportTile(context, Icons.local_shipping_rounded, 'Milk Supply Shortfall / Excess Request', '+91 8919548905'),
            _buildSupportTile(context, Icons.shopping_bag_outlined, 'Packaging Pouches & Crates Reorder', '+91 8885199878'),
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
        decoration: const BoxDecoration(color: Color(0xFFFFF3E6), shape: BoxShape.circle),
        child: Icon(icon, color: const Color(0xFFE67E22), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
      trailing: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF0D7C66), size: 20),
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

  void _confirmProviderLogout(BuildContext context, AppState state, VoidCallback onLogout) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Log Out Provider', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to log out of the Location Hub provider portal?'),
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
