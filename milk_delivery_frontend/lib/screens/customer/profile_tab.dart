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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── User Profile Header Card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFF0D7C66),
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : '👤',
                        style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
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
                                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.amber),
                                ),
                                child: Text(
                                  activeSubsCount > 0 ? '👑 Active Member' : '🌱 Subscriber',
                                  style: const TextStyle(color: Colors.amber, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(email, style: TextStyle(color: Colors.grey[400], fontSize: 11.5)),
                          const SizedBox(height: 2),
                          Text(phone, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.white70, size: 22),
                      tooltip: 'Edit Personal Details',
                      onPressed: () => _showEditProfileDialog(context, fullName, email, phone),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 10),

                // Live Wallet Balance Quick Strip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF10B981), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Prepaid Wallet: ₹${walletBal.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => state.setTab(2),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Top Up +', style: TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Delivery Location & Instructions ──
          _buildSectionTitle('Delivery Location & Instructions'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_rounded, color: Color(0xFF0D7C66), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Default Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(address, style: TextStyle(color: Colors.grey[700], fontSize: 11.5)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF0D7C66), size: 18),
                        tooltip: 'Edit Address',
                        onPressed: () => _showEditAddressDialog(context, address),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                          icon: const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF10B981)),
                          label: const Text('Address Book 📍', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF10B981)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await state.requestDeviceGPS();
                            state.updateUserProfile(address: state.currentDeliveryAddress);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF10B981),
                                  content: Text('📍 Live GPS Detected: ${state.currentDeliveryAddress}'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF0F172A)),
                          label: const Text('Detect GPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.doorbell_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Doorstep Delivery Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('"$instructions"', style: TextStyle(color: Colors.grey[700], fontSize: 11.5, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF0D7C66), size: 20),
                        onPressed: () => _showEditInstructionsDialog(context, instructions),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ── Delivery Preferences ──
          _buildSectionTitle('Delivery Slot Preferences'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.access_time_filled_rounded, color: Color(0xFF0D7C66)),
                  title: const Text('Morning Delivery Time Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(slot, style: const TextStyle(fontSize: 11, color: Color(0xFF0D7C66), fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showSlotPreferenceDialog(context, slot),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.bolt_rounded, color: Color(0xFF10B981)),
                  title: const Text('Prepaid Auto-Debit on Delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Automatically deduct item cost upon photo proof upload', style: TextStyle(fontSize: 10.5)),
                  value: true,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (val) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Support & Customer Care ──
          _buildSectionTitle('Customer Care & Support'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded, color: Color(0xFF0D7C66)),
                  title: const Text('24x7 Priority Support & Live Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Live WebSocket Chat • Toll-Free Hotline • FAQs', style: TextStyle(fontSize: 10.5, color: Color(0xFF0D7C66))),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF0D7C66), size: 20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => HelpSupportScreen(state: state),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_rounded, color: Colors.indigo),
                  title: const Text('Privacy Policy & Terms of Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Log Out Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFE11D48)),
              label: const Text('Log Out of Account', style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 13.5)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE11D48)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
    );
  }

  void _showEditProfileDialog(BuildContext context, String currentName, String currentEmail, String currentPhone) {
    final nameCtrl = TextEditingController(text: currentName);
    final emailCtrl = TextEditingController(text: currentEmail);
    final phoneCtrl = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                        final res = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (c) => MapLocationPickerScreen(state: state),
                          ),
                        );
                        if (res == true) {
                          setDlgState(() {
                            ctrl.text = state.currentDeliveryAddress;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
