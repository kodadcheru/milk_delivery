import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import 'address_book_screen.dart';
import 'map_location_picker_screen.dart';
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
        : 'Customer';
    final email = user?.email.isNotEmpty == true ? user!.email : 'No email linked';
    final phone = user?.phone.isNotEmpty == true ? user!.phone : 'No phone number';
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
      color: const Color(0xFF0D7C66),
      onRefresh: () => state.reloadAllData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. NEXT-GEN HERO PROFILE CARD ──
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0D7C66)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D7C66).withValues(alpha: 0.25),
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
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Avatar with Active Member Ring Glow
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF38BDF8)],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: CircleAvatar(
                                    radius: 30,
                                    backgroundColor: const Color(0xFF0F172A),
                                    child: Text(
                                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '👤',
                                      style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    width: 13,
                                    height: 13,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF0F172A), width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          fullName,
                                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                                        ),
                                        child: Text(
                                          activeSubsCount > 0 ? '👑 VIP Member' : '🌱 Fresh Member',
                                          style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(email, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5)),
                                  const SizedBox(height: 2),
                                  Text(phone, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                              ),
                              tooltip: 'Edit Profile Details',
                              onPressed: () => _showEditProfileDialog(context, fullName, email, phone),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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

            // ── 2. QUICK ACTIONS BAR ──
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

            // ── 3. DELIVERY LOCATION & INSTRUCTIONS ──
            _buildSectionHeader('Delivery Location & Doorstep Note', Icons.location_on_rounded, const Color(0xFF0D7C66)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.home_work_rounded, color: Color(0xFF0D7C66), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Default Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                            const SizedBox(height: 3),
                            Text(address, style: TextStyle(color: Colors.grey[700], fontSize: 12, height: 1.3)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF0D7C66), size: 18),
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
                          icon: const Icon(Icons.menu_book_rounded, size: 15, color: Color(0xFF10B981)),
                          label: const Text('Manage Address Book', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF10B981)),
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
                                    backgroundColor: const Color(0xFF10B981),
                                    content: Text('📍 Live GPS Synced: ${state.currentDeliveryAddress}'),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.my_location_rounded, size: 15, color: Color(0xFF0F172A)),
                          label: const Text('Sync Live GPS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.doorbell_rounded, color: Color(0xFFF59E0B), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Doorstep Delivery Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                            const SizedBox(height: 3),
                            Text('"$instructions"', style: TextStyle(color: Colors.grey[700], fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF0D7C66), size: 20),
                        onPressed: () => _showEditInstructionsDialog(context, instructions),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Quick Doorstep Instruction Preset Chips
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.access_time_filled_rounded, color: Color(0xFF0D7C66), size: 20),
                    ),
                    title: const Text('Morning Delivery Time Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                    subtitle: Text(slot, style: const TextStyle(fontSize: 11.5, color: Color(0xFF0D7C66), fontWeight: FontWeight.w700)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF0D7C66)),
                    onTap: () => _showSlotPreferenceDialog(context, slot),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                    title: const Text('Auto-Debit Prepaid Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                    subtitle: const Text('Automatically deduct item cost upon photo proof upload', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    value: true,
                    activeThumbColor: const Color(0xFF10B981),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.headset_mic_rounded, color: Color(0xFF0D7C66), size: 20),
                    ),
                    title: const Text('24x7 Priority Support & Live Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                    subtitle: const Text('Live WebSocket Chat • FAQs • Order Queries', style: TextStyle(fontSize: 11, color: Color(0xFF0D7C66), fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF0D7C66)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => HelpSupportScreen(state: state)),
                      );
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.privacy_tip_rounded, color: Colors.indigo, size: 20),
                    ),
                    title: const Text('Privacy Policy & Terms of Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                    subtitle: const Text('MilkDrop Express Guarantee & Security', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.grey),
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
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFE11D48), size: 18),
                label: const Text('Log Out of Account', style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w800, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF1F2),
                  side: const BorderSide(color: Color(0xFFFECDD3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Center(
              child: Text(
                'MilkDrop Express v1.0.0 • Farm Fresh Daily 🥛',
                style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),
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
                Icon(icon, color: const Color(0xFF10B981), size: 14),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
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
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.2),
        ),
      ],
    );
  }

  Widget _buildPresetChip(BuildContext context, String presetText) {
    return InkWell(
      onTap: () {
        state.updateUserProfile(deliveryInstructions: presetText);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D7C66),
            content: Text('Saved instruction: $presetText'),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          presetText,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 10.5, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFE11D48)),
            SizedBox(width: 8),
            Text('Log Out?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text('Are you sure you want to log out of MilkDrop Express?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
            onPressed: () {
              Navigator.pop(ctx);
              onLogout();
            },
            child: const Text('Log Out'),
          ),
        ],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Personal Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              state.updateUserProfile(
                firstName: nameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile details updated & synced with DB!')));
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Delivery Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter complete house number & street address',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final res = await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (c) => MapLocationPickerScreen(state: state),
                          ),
                        );
                        if (res != null && res['formatted'] != null) {
                          setDlgState(() {
                            ctrl.text = res['formatted'] as String;
                          });
                        }
                      },
                      icon: const Icon(Icons.map_rounded, size: 14, color: Color(0xFF0284C7)),
                      label: const Text('Pick on Map 🗺️', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await state.requestDeviceGPS();
                        if (ok) {
                          setDlgState(() {
                            ctrl.text = state.currentDeliveryAddress;
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF0D7C66),
                                content: Text('📍 Auto-detected: ${state.currentDeliveryAddress}'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.my_location_rounded, size: 14, color: Color(0xFF0D7C66)),
                      label: const Text('Use GPS 📍', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0D7C66))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        side: const BorderSide(color: Color(0xFF0D7C66)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                state.updateUserProfile(
                  address: ctrl.text.trim(),
                  latitude: state.currentLat,
                  longitude: state.currentLon,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address & GPS coordinates updated & synced!')),
                );
              },
              child: const Text('Save Address'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditInstructionsDialog(BuildContext context, String currentInst) {
    final ctrl = TextEditingController(text: currentInst);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Doorstep Delivery Note', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'e.g. Leave in milk container near door'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              state.updateUserProfile(deliveryInstructions: ctrl.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doorstep instructions saved!')));
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  void _showSlotPreferenceDialog(BuildContext context, String currentSlot) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Select Delivery Time Slot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                currentSlot.contains('05:30') ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: const Color(0xFF0D7C66),
              ),
              title: const Text('05:30 AM - 07:00 AM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Early Morning Express Slot', style: TextStyle(fontSize: 10.5)),
              onTap: () {
                state.updateUserProfile(slotPreference: '05:30 AM - 07:00 AM');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery slot updated to 05:30 AM - 07:00 AM!')));
              },
            ),
            ListTile(
              leading: Icon(
                currentSlot.contains('07:00') ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: const Color(0xFF0D7C66),
              ),
              title: const Text('07:00 AM - 08:30 AM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Standard Morning Slot', style: TextStyle(fontSize: 10.5)),
              onTap: () {
                state.updateUserProfile(slotPreference: '07:00 AM - 08:30 AM');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery slot updated to 07:00 AM - 08:30 AM!')));
              },
            ),
          ],
        ),
      ),
    );
  }
}
