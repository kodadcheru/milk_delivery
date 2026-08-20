import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';
import 'address_book_screen.dart';
import 'help_support_screen.dart';

class ProfileTab extends StatelessWidget {
  final AppState state;
  final VoidCallback onLogout;

  const ProfileTab({
    super.key,
    required this.state,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final user = state.currentUser;
    final fullName = user != null && (user.firstName.isNotEmpty || user.lastName.isNotEmpty)
        ? '${user.firstName} ${user.lastName}'.trim()
        : (user?.username.isNotEmpty == true ? user!.username : 'Customer');
    final email = user?.email.isNotEmpty == true ? user!.email : 'No email linked';
    final phone = user?.phone.isNotEmpty == true ? user!.phone : '+91 8885199878';
    final address = user?.address.isNotEmpty == true ? user!.address : 'Add delivery address';
    final instructions = user?.deliveryInstructions.isNotEmpty == true
        ? user!.deliveryInstructions
        : 'Leave near doorstep box';
    final slot = user?.deliverySlotPreference.isNotEmpty == true
        ? user!.deliverySlotPreference
        : '05:30 AM - 07:00 AM';
    final walletBal = user?.walletBalance ?? 0.0;
    final activeSubsCount = state.subscriptions.where((s) => s.status == 'ACTIVE').length;
    final savedAddrCount = state.savedAddresses.length;

    return RefreshIndicator(
      color: UiTone.primary,
      onRefresh: () => state.reloadAllData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. SERVICE-MOBILE HERO PROFILE HEADER ──
            Container(
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
                children: [
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      children: [
                        // Header bar title & Edit Profile button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Profile',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showEditProfileDialog(context, fullName, email, phone),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.35),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Edit profile',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Avatar with Edit Badge & Glow
                        GestureDetector(
                          onTap: () => _showEditProfileDialog(context, fullName, email, phone),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: <Color>[
                                      Colors.white.withValues(alpha: 0.95),
                                      Colors.white.withValues(alpha: 0.40),
                                    ],
                                  ),
                                  boxShadow: const <BoxShadow>[
                                    BoxShadow(
                                      color: Color(0x30000000),
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.white,
                                  child: Text(
                                    fullName.isNotEmpty ? fullName[0].toUpperCase() : '👤',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0D7C66),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Full Name + Verified Checkmark Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              size: 20,
                              color: Color(0xFF38BDF8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Phone Pill Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phone_iphone_rounded,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                phone,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Stats Summary Row (Wallet, Active Subs, Saved Addresses)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('₹${walletBal.toStringAsFixed(0)}', 'Prepaid Wallet', Icons.account_balance_wallet_rounded, () => state.setTab(2)),
                              Container(width: 1, height: 28, color: Colors.white12),
                              _buildStatItem('$activeSubsCount', 'Active Subs', Icons.autorenew_rounded, () => state.setTab(1)),
                              Container(width: 1, height: 28, color: Colors.white12),
                              _buildStatItem('$savedAddrCount', 'Addresses', Icons.location_on_rounded, () {
                                Navigator.push(context, MaterialPageRoute(builder: (ctx) => AddressBookScreen(state: state)));
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── 2. QUICK ACTION TILES BAR ──
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionTile(
                    context,
                    icon: Icons.add_card_rounded,
                    label: 'Top Up Wallet',
                    color: const Color(0xFF10B981),
                    onTap: () => state.setTab(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildQuickActionTile(
                    context,
                    icon: Icons.menu_book_rounded,
                    label: 'Address Book',
                    color: const Color(0xFF0284C7),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AddressBookScreen(state: state))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildQuickActionTile(
                    context,
                    icon: Icons.support_agent_rounded,
                    label: '24/7 Support',
                    color: const Color(0xFFF59E0B),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => HelpSupportScreen(state: state))),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── 3. DELIVERY LOCATION & DOORSTEP NOTE ──
            _buildSectionHeader('Delivery Location & Doorstep Note', Icons.location_on_rounded, const Color(0xFF0D7C66)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: UiTone.surface,
                borderRadius: BorderRadius.circular(UiRadius.md),
                border: Border.all(color: UiTone.surfaceBorder),
                boxShadow: UiShadow.card,
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: UiTone.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.home_work_rounded, color: UiTone.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Default Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: UiTone.ink)),
                            const SizedBox(height: 3),
                            Text(address, style: const TextStyle(color: UiTone.softText, fontSize: 12, height: 1.3)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: UiTone.primary, size: 18),
                        onPressed: () => _showEditAddressDialog(context, address),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (c) => AddressBookScreen(state: state)),
                            );
                          },
                          icon: const Icon(Icons.menu_book_rounded, size: 15, color: UiTone.primary),
                          label: const Text('Manage Address Book', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: UiTone.primary)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: UiTone.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await state.requestDeviceGPS();
                            if (ok) {
                              state.updateUserProfile(address: state.currentDeliveryAddress);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: UiTone.primary,
                                    content: Text('📍 Live GPS Synced: ${state.currentDeliveryAddress}'),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.my_location_rounded, size: 15, color: UiTone.ink),
                          label: const Text('Sync Live GPS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: UiTone.ink)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: UiTone.surfaceBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: UiTone.surfaceMuted),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: UiTone.warningSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.doorbell_rounded, color: UiTone.warning, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Doorstep Delivery Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: UiTone.ink)),
                            const SizedBox(height: 3),
                            Text('"$instructions"', style: const TextStyle(color: UiTone.softText, fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: UiTone.primary, size: 20),
                        onPressed: () => _showEditInstructionsDialog(context, instructions),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildPresetChip(context, '🔔 Ring Bell'),
                      _buildPresetChip(context, '📦 Leave at Doorstep'),
                      _buildPresetChip(context, '🤫 Silent Drop (No Ring)'),
                      _buildPresetChip(context, '📞 Call Before Drop'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── 4. DELIVERY PREFERENCES ──
            _buildSectionHeader('Morning Delivery Schedule & Auto-Debit', Icons.schedule_rounded, const Color(0xFF0284C7)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: UiTone.surface,
                borderRadius: BorderRadius.circular(UiRadius.md),
                border: Border.all(color: UiTone.surfaceBorder),
                boxShadow: UiShadow.card,
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: UiTone.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.access_time_filled_rounded, color: UiTone.primary, size: 20),
                    ),
                    title: const Text('Morning Delivery Time Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: UiTone.ink)),
                    subtitle: Text(slot, style: const TextStyle(fontSize: 11.5, color: UiTone.primary, fontWeight: FontWeight.w700)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: UiTone.primary),
                    onTap: () => _showSlotPreferenceDialog(context, slot),
                  ),
                  const Divider(height: 1, color: UiTone.surfaceMuted),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: UiTone.successSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt_rounded, color: UiTone.success, size: 20),
                    ),
                    title: const Text('Auto-Debit Prepaid Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: UiTone.ink)),
                    subtitle: const Text('Automatically deduct item cost upon photo proof upload', style: TextStyle(fontSize: 11, color: UiTone.softText)),
                    value: true,
                    activeThumbColor: UiTone.secondary,
                    onChanged: (val) {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── 5. SUPPORT & LEGAL ──
            _buildSectionHeader('Help & App Info', Icons.help_outline_rounded, const Color(0xFFF59E0B)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: UiTone.surface,
                borderRadius: BorderRadius.circular(UiRadius.md),
                border: Border.all(color: UiTone.surfaceBorder),
                boxShadow: UiShadow.card,
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: UiTone.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.headset_mic_rounded, color: UiTone.primary, size: 20),
                    ),
                    title: const Text('24x7 Priority Support & Live Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: UiTone.ink)),
                    subtitle: const Text('Live WebSocket Chat • FAQs • Order Queries', style: TextStyle(fontSize: 11, color: UiTone.primary, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: UiTone.primary),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => HelpSupportScreen(state: state)),
                      );
                    },
                  ),
                  const Divider(height: 1, color: UiTone.surfaceMuted),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: UiTone.infoSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.privacy_tip_rounded, color: UiTone.accentBlue, size: 20),
                    ),
                    title: const Text('Privacy Policy & Terms of Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: UiTone.ink)),
                    subtitle: const Text('MilkDrop Express Guarantee & Security', style: TextStyle(fontSize: 11, color: UiTone.softText)),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: UiTone.softText),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🔒 MilkDrop Express Terms & Privacy Policy are active.')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── 6. LOG OUT BUTTON ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout_rounded, color: UiTone.error, size: 18),
                label: const Text('Log Out of Account', style: TextStyle(color: UiTone.error, fontWeight: FontWeight.w800, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: UiTone.errorSoft,
                  side: BorderSide(color: UiTone.error.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Center(
              child: Text(
                'MilkDrop Express v1.0.0 • Farm Fresh Daily 🥛',
                style: TextStyle(color: UiTone.softText, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String val, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: const Color(0xFF38BDF8), size: 14),
                const SizedBox(width: 4),
                Text(
                  val,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: UiTone.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: UiTone.surfaceBorder),
          boxShadow: UiShadow.card,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: UiTone.ink, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: UiTone.ink,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(BuildContext context, String text) {
    return InkWell(
      onTap: () {
        final cleanText = text.replaceAll(RegExp(r'[^a-zA-Z0-9 ()\-]'), '').trim();
        state.updateUserProfile(deliveryInstructions: cleanText);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: UiTone.primary,
            content: Text('👍 Note preset saved: "$cleanText"'),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: UiTone.shellBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: UiTone.surfaceBorder),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 10.5, color: UiTone.ink, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, String currentName, String currentEmail, String currentPhone) {
    final nameCtrl = TextEditingController(text: currentName);
    final emailCtrl = TextEditingController(text: currentEmail);
    final phoneCtrl = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: UiTone.primary),
            SizedBox(width: 8),
            Text('Edit Profile Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
            onPressed: () {
              final parts = nameCtrl.text.trim().split(' ');
              final first = parts.first;
              final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
              state.updateUserProfile(
                firstName: first,
                lastName: last,
                email: emailCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(backgroundColor: UiTone.primary, content: Text('✅ Profile details updated successfully!')),
              );
            },
            child: const Text('Save Details'),
          ),
        ],
      ),
    );
  }

  void _showEditAddressDialog(BuildContext context, String currentAddress) {
    final ctrl = TextEditingController(text: currentAddress);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: const Text('Update Delivery Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Enter complete doorstep address...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                state.updateUserProfile(address: ctrl.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: UiTone.primary, content: Text('📍 Delivery address updated!')),
                );
              }
            },
            child: const Text('Save Address'),
          ),
        ],
      ),
    );
  }

  void _showEditInstructionsDialog(BuildContext context, String currentNote) {
    final ctrl = TextEditingController(text: currentNote);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: const Text('Doorstep Delivery Note', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'e.g., Leave near doorstep box, ring bell once...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
            onPressed: () {
              state.updateUserProfile(deliveryInstructions: ctrl.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(backgroundColor: UiTone.primary, content: Text('📝 Doorstep delivery note updated!')),
              );
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  void _showSlotPreferenceDialog(BuildContext context, String currentSlot) {
    String selected = currentSlot;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
          title: const Text('Morning Delivery Time Slot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('05:30 AM - 07:00 AM (Peak Early Morning)', style: TextStyle(fontSize: 12.5)),
                value: '05:30 AM - 07:00 AM',
                groupValue: selected,
                activeColor: UiTone.primary,
                onChanged: (v) => setDialogState(() => selected = v!),
              ),
              RadioListTile<String>(
                title: const Text('07:00 AM - 08:30 AM (Standard Morning)', style: TextStyle(fontSize: 12.5)),
                value: '07:00 AM - 08:30 AM',
                groupValue: selected,
                activeColor: UiTone.primary,
                onChanged: (v) => setDialogState(() => selected = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
              onPressed: () {
                state.updateUserProfile(slotPreference: selected);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: UiTone.primary, content: Text('⏱️ Preferred slot saved: $selected')),
                );
              },
              child: const Text('Save Slot'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: UiTone.error),
            SizedBox(width: 8),
            Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to log out of your account? You can log back in anytime with your phone number.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UiTone.error, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              onLogout();
            },
            child: const Text('Yes, Log Out'),
          ),
        ],
      ),
    );
  }
}
