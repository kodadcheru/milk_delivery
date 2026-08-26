import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/app_state.dart';
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
    
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Part 1: Hero Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF044E3A), Color(0xFF0D7C66), Color(0xFF059669)],
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
                // a. Top row
                Row(
                  children: [
                    const Text('Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showEditProfileDialog(context, state, fullName, email, phone),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text('Edit profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // c. Avatar stack
                Center(
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
                        child: Center(
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor: const Color(0xFF0D7C66),
                            child: Text(
                              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'C',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
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
                        child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // e. Name row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 20, color: Color(0xFF38BDF8)),
                  ],
                ),
                const SizedBox(height: 6),
                
                // g. Phone pill
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_iphone_rounded, size: 14, color: Colors.white.withValues(alpha: 0.70)),
                        const SizedBox(width: 6),
                        Text(
                          phone,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Part 2: Scrollable Menu List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // ── 1. Hero 24/7 Live Chat & Support Card ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF044E3A), Color(0xFF0D7C66)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Color(0x200D7C66), blurRadius: 14, offset: Offset(0, 6)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text('💬', style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  '24/7 Live Support & Chat',
                                  style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('ONLINE', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Instant help with morning drops, subscriptions & wallet',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => HelpSupportScreen(state: state)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0D7C66),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Chat ⚡', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Group 1: Core Account & Orders
                _buildCardGroup([
                  _buildMenuTile(
                    icon: Icons.calendar_today_rounded,
                    iconBg: const Color(0xFFE8F2FE),
                    iconFg: const Color(0xFF2563EB),
                    label: 'Your orders',
                    onTap: () => state.setTab(3),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.location_on_rounded,
                    iconBg: const Color(0xFFE6F5F0),
                    iconFg: const Color(0xFF0D7C66),
                    label: 'Address book',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddressBookScreen(state: state))),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.schedule_rounded,
                    iconBg: const Color(0xFFE0F7F3),
                    iconFg: const Color(0xFF0D9488),
                    label: 'Delivery preferences',
                    onTap: () {
                      final slot = user?.deliverySlotPreference.isNotEmpty == true
                          ? user!.deliverySlotPreference
                          : '05:30 AM - 07:00 AM';
                      _showSlotPreferenceDialog(context, state, slot);
                    },
                  ),
                ]),
                
                const SizedBox(height: 16),
                
                // Group 2
                _buildCardGroup([
                  _buildMenuTile(
                    icon: Icons.headset_mic_rounded,
                    iconBg: const Color(0xFFFFF3E6),
                    iconFg: const Color(0xFFE67E22),
                    label: 'Help & FAQs',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HelpSupportScreen(state: state))),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.share_rounded,
                    iconBg: const Color(0xFFE8F2FE),
                    iconFg: const Color(0xFF2563EB),
                    label: 'Share App',
                    onTap: () async {
                      await Clipboard.setData(const ClipboardData(text: 'https://milkdrop.com/app'));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied!')));
                      }
                    },
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.info_outline_rounded,
                    iconBg: const Color(0xFFF1F5F9),
                    iconFg: const Color(0xFF475569),
                    label: 'About us',
                    onTap: () => showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('About Us'), content: const Text('MilkDrop Express is a farm-to-home fresh milk delivery service.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))])),
                  ),
                  _buildDivider(),
                  _buildMenuTile(
                    icon: Icons.shield_outlined,
                    iconBg: const Color(0xFFE0F7F3),
                    iconFg: const Color(0xFF0D9488),
                    label: 'Privacy & Terms',
                    onTap: () => showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Privacy & Terms'), content: const Text('By using this app, you agree to our terms of service.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))])),
                  ),
                ]),
                
                const SizedBox(height: 20),
                
                // Logout Button
                GestureDetector(
                  onTap: () => _confirmLogout(context, onLogout),
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
                        Text('Log out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Version Footer
                const Center(
                  child: Text(
                    'MilkDrop Express v1.0.0 • Farm Fresh Daily 🥛',
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
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF1F5F9),
      indent: 70,
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String label,
    required VoidCallback onTap,
    String? trailingBadge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A2B23)),
                ),
              ),
              if (trailingBadge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F5F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF0D7C66).withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    trailingBadge,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0D7C66)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFFC0C8C4)),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Standalone Dialog Methods
// ──────────────────────────────────────────────

void _showEditProfileDialog(BuildContext context, AppState state, String currentName, String currentEmail, String currentPhone) {
  final nameCtrl = TextEditingController(text: currentName);
  final emailCtrl = TextEditingController(text: currentEmail);
  final phoneCtrl = TextEditingController(text: currentPhone);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(Icons.edit_rounded, color: Color(0xFF0D7C66)),
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
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
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
              const SnackBar(backgroundColor: Color(0xFF0D7C66), content: Text('✅ Profile details updated successfully!')),
            );
          },
          child: const Text('Save Details'),
        ),
      ],
    ),
  );
}



void _showSlotPreferenceDialog(BuildContext context, AppState state, String currentSlot) {
  String selected = currentSlot.isNotEmpty ? currentSlot : '05:30 AM - 07:00 AM';
  final customCtrl = TextEditingController(text: selected);

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delivery Time Slot Preference ⏰', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Quick Preset or Type Custom Slot:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                '05:30 AM - 07:00 AM',
                '07:00 AM - 08:30 AM',
                '05:00 PM - 07:00 PM',
                '06:30 PM - 08:30 PM',
              ].map((s) {
                final isSel = selected == s;
                final isEve = s.toUpperCase().contains('PM');
                final icon = isEve ? '🌙 ' : '☀️ ';
                return ChoiceChip(
                  label: Text(icon + s, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: isSel ? Colors.white : const Color(0xFF0F172A))),
                  selected: isSel,
                  selectedColor: isEve ? const Color(0xFF7C3AED) : const Color(0xFF0D7C66),
                  backgroundColor: const Color(0xFFF1F5F9),
                  showCheckmark: false,
                  onSelected: (sel) {
                    if (sel) {
                      setDialogState(() {
                        selected = s;
                        customCtrl.text = s;
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
                setDialogState(() {
                  selected = val.trim().isNotEmpty ? val.trim() : '05:30 AM - 07:00 AM';
                });
              },
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Type Custom Slot (e.g. 06:00 AM - 07:30 AM)',
                labelStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                prefixIcon: const Icon(Icons.edit_calendar_rounded, size: 16, color: Color(0xFF0D7C66)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0D7C66), width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
            onPressed: () {
              final finalSlot = customCtrl.text.trim().isNotEmpty ? customCtrl.text.trim() : selected;
              state.updateUserProfile(slotPreference: finalSlot);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(backgroundColor: const Color(0xFF0D7C66), content: Text('⏱️ Preferred slot saved: $finalSlot')),
              );
            },
            child: const Text('Save Slot'),
          ),
        ],
      ),
    ),
  );
}

void _confirmLogout(BuildContext context, VoidCallback onLogout) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(Icons.logout_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: const Text('Are you sure you want to log out of your account? You can log back in anytime with your phone number.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () {
            Navigator.of(ctx).pop();
            onLogout();
          },
          child: const Text('Yes, Log Out'),
        ),
      ],
    ),
  );
}
