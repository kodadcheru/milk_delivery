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
    final phone = user?.phone.isNotEmpty == true ? user!.phone : 'No phone linked';
    
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

                // ── Language Selection Switcher Card ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.language_rounded, color: Color(0xFF9333EA), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.tr('language'),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                            Text(
                              state.isTelugu ? 'తెలుగు ఎంచుకోబడింది (Telugu)' : 'English (Selected)',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // 1-Tap Toggle Pill
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => state.setLanguage('en'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: !state.isTelugu ? const Color(0xFF0D7C66) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'English',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: !state.isTelugu ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => state.setLanguage('te'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: state.isTelugu ? const Color(0xFF0D7C66) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'తెలుగు',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: state.isTelugu ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
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
                      await Clipboard.setData(const ClipboardData(text: 'https://pamba.in/app'));
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
                    onTap: () => showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('About Us'), content: const Text('Pamba Fresh is a farm-to-home pure milk and dairy delivery service.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))])),
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
                    'Pamba v1.0.0 • Farm Fresh Daily 🥛',
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
// Standalone Modal Sheets & Dialogs
// ──────────────────────────────────────────────

void _showEditProfileDialog(
  BuildContext context,
  AppState state,
  String currentName,
  String currentEmail,
  String currentPhone,
) {
  final user = state.currentUser;
  final nameParts = currentName.trim().split(' ');
  final initialFirst = user?.firstName.isNotEmpty == true
      ? user!.firstName
      : (nameParts.isNotEmpty ? nameParts.first : '');
  final initialLast = user?.lastName.isNotEmpty == true
      ? user!.lastName
      : (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');

  final firstNameCtrl = TextEditingController(text: initialFirst);
  final lastNameCtrl = TextEditingController(text: initialLast);
  final emailCtrl = TextEditingController(text: currentEmail == 'No email linked' ? '' : currentEmail);
  final phoneCtrl = TextEditingController(text: currentPhone);
  String selectedSlot = user?.deliverySlotPreference.isNotEmpty == true
      ? user!.deliverySlotPreference
      : '05:30 AM - 07:00 AM';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final maxHeight = MediaQuery.of(ctx).size.height * 0.88;
        final avatarChar = firstNameCtrl.text.trim().isNotEmpty
            ? firstNameCtrl.text.trim()[0].toUpperCase()
            : 'C';

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -6)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F5F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_rounded, color: Color(0xFF0D7C66), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Profile Details',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Keep your delivery contact details up to date',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0D7C66), Color(0xFF059669)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0D7C66).withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    avatarChar,
                                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.verified, size: 12, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStyledInput(
                                controller: firstNameCtrl,
                                label: 'First Name',
                                hint: 'e.g. Rahul',
                                icon: Icons.badge_outlined,
                                onChanged: (_) => setSheetState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStyledInput(
                                controller: lastNameCtrl,
                                label: 'Last Name',
                                hint: 'e.g. Reddy',
                                icon: Icons.person_outline_rounded,
                                onChanged: (_) => setSheetState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildStyledInput(
                          controller: phoneCtrl,
                          label: 'Phone Number (Primary Contact)',
                          hint: '+91 9876543210',
                          icon: Icons.phone_iphone_rounded,
                          keyboardType: TextInputType.phone,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F5F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF0D7C66)),
                                SizedBox(width: 4),
                                Text(
                                  'OTP Verified',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0D7C66)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildStyledInput(
                          controller: emailCtrl,
                          label: 'Email Address (Invoices & Receipts)',
                          hint: 'name@example.com',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Default Morning Delivery Slot ☀️',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            '05:30 AM - 07:00 AM',
                            '07:00 AM - 08:30 AM',
                            '05:00 PM - 07:00 PM',
                          ].map((slot) {
                            final isSel = selectedSlot == slot;
                            final isEve = slot.contains('PM');
                            return GestureDetector(
                              onTap: () => setSheetState(() => selectedSlot = slot),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? const Color(0xFF0D7C66)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel
                                        ? const Color(0xFF0D7C66)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(isEve ? '🌙 ' : '☀️ ', style: const TextStyle(fontSize: 12)),
                                    Text(
                                      slot,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSel ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () async {
                              final first = firstNameCtrl.text.trim();
                              final last = lastNameCtrl.text.trim();
                              final email = emailCtrl.text.trim();
                              final phone = phoneCtrl.text.trim();

                              if (first.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Colors.redAccent,
                                    content: Text('⚠️ Please enter your First Name.'),
                                  ),
                                );
                                return;
                              }

                              await state.updateUserProfile(
                                firstName: first,
                                lastName: last,
                                email: email,
                                phone: phone,
                                slotPreference: selectedSlot,
                              );

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                HapticFeedback.mediumImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Color(0xFF0D7C66),
                                    content: Text('✅ Profile details updated successfully!'),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D7C66),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Save Profile Changes',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget _buildStyledInput({
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData icon,
  TextInputType keyboardType = TextInputType.text,
  Widget? trailing,
  ValueChanged<String>? onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
      ),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF0D7C66)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                onChanged: onChanged,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing,
            ],
          ],
        ),
      ),
    ],
  );
}

void _showSlotPreferenceDialog(BuildContext context, AppState state, String currentSlot) {
  String selected = currentSlot.isNotEmpty ? currentSlot : '05:30 AM - 07:00 AM';
  final customCtrl = TextEditingController(text: selected);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final maxHeight = MediaQuery.of(ctx).size.height * 0.85;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: Color(0xFF0D7C66), size: 24),
                      SizedBox(width: 10),
                      Text('Delivery Time Slot Preference ⏰', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Choose when you want our delivery executive to arrive:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            '05:30 AM - 07:00 AM',
                            '07:00 AM - 08:30 AM',
                            '05:00 PM - 07:00 PM',
                            '06:30 PM - 08:30 PM',
                          ].map((s) {
                            final isSel = selected == s;
                            final isEve = s.toUpperCase().contains('PM');
                            final icon = isEve ? '🌙 ' : '☀️ ';
                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  selected = s;
                                  customCtrl.text = s;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFF0D7C66) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isSel ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  icon + s,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSel ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        _buildStyledInput(
                          controller: customCtrl,
                          label: 'Or Specify Custom Slot Window',
                          hint: 'e.g. 06:00 AM - 07:30 AM',
                          icon: Icons.edit_calendar_rounded,
                          onChanged: (val) {
                            setDialogState(() {
                              selected = val.trim().isNotEmpty ? val.trim() : '05:30 AM - 07:00 AM';
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D7C66),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              final finalSlot = customCtrl.text.trim().isNotEmpty ? customCtrl.text.trim() : selected;
                              state.updateUserProfile(slotPreference: finalSlot);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(backgroundColor: const Color(0xFF0D7C66), content: Text('⏱️ Preferred slot saved: $finalSlot')),
                              );
                            },
                            child: const Text('Save Slot Preference', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

void _confirmLogout(BuildContext context, VoidCallback onLogout) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.logout_rounded, color: Color(0xFFE11D48)),
          SizedBox(width: 10),
          Text('Log Out', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ],
      ),
      content: const Text(
        'Are you sure you want to log out of your account? You can log back in anytime with your phone number.',
        style: TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.4),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE11D48),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            Navigator.of(ctx).pop();
            onLogout();
          },
          child: const Text('Yes, Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
