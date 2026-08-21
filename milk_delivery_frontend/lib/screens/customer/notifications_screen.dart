import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';

class NotificationsScreen extends StatefulWidget {
  final AppState state;

  const NotificationsScreen({super.key, required this.state});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final allNotifs = widget.state.notifications;
    final unreadCount = widget.state.unreadNotificationCount;

    final filteredNotifs = allNotifs.where((n) {
      if (_selectedFilter == 'Deliveries') return n.notificationType == 'DELIVERY';
      if (_selectedFilter == 'Wallet') return n.notificationType == 'WALLET';
      if (_selectedFilter == 'Updates') return n.notificationType == 'VACATION' || n.notificationType == 'OFFER';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: UiTone.shellBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Notifications 🔔',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$unreadCount NEW',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (allNotifs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () {
                  widget.state.markAllNotificationsRead();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read. 🧹'),
                      backgroundColor: UiTone.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF34D399)),
                label: const Text(
                  'Mark Read',
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Category Chips Bar ──
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', '👥 All (${allNotifs.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Deliveries', '🚚 Deliveries'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Wallet', '⚡ Wallet'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Updates', '📢 Offers & Updates'),
                ],
              ),
            ),
          ),

          // ── Notification Items Feed ──
          Expanded(
            child: filteredNotifs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: UiTone.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications_none_rounded, size: 48, color: UiTone.primary),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Notifications Here',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: UiTone.ink),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Morning milk dispatches, doorstep proof photos, and wallet cashback alerts will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredNotifs.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final item = filteredNotifs[idx];
                      final isDelivery = item.notificationType == 'DELIVERY';
                      final isWallet = item.notificationType == 'WALLET';

                      return Container(
                        decoration: BoxDecoration(
                          color: item.isRead ? UiTone.surface : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: item.isRead ? UiTone.surfaceBorder : UiTone.primary.withValues(alpha: 0.4),
                            width: item.isRead ? 1.0 : 1.4,
                          ),
                          boxShadow: item.isRead ? UiShadow.card : UiShadow.glowPrimary,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () {
                              if (!item.isRead) {
                                widget.state.markNotificationRead(item.id);
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Category Avatar Circle
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isDelivery
                                              ? UiTone.primary.withValues(alpha: 0.15)
                                              : (isWallet ? const Color(0xFFFEF3C7) : const Color(0xFFF3E8FF)),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isDelivery
                                              ? Icons.local_shipping_rounded
                                              : (isWallet ? Icons.account_balance_wallet_rounded : Icons.campaign_rounded),
                                          color: isDelivery
                                              ? UiTone.primary
                                              : (isWallet ? const Color(0xFFD97706) : const Color(0xFF7C3AED)),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Content Column
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.title,
                                                    style: TextStyle(
                                                      fontWeight: item.isRead ? FontWeight.w800 : FontWeight.w900,
                                                      fontSize: 14,
                                                      color: UiTone.ink,
                                                      letterSpacing: -0.2,
                                                    ),
                                                  ),
                                                ),
                                                if (!item.isRead) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      'NEW',
                                                      style: TextStyle(
                                                        color: Color(0xFFE11D48),
                                                        fontSize: 8.5,
                                                        fontWeight: FontWeight.w900,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.message,
                                              style: const TextStyle(
                                                color: Color(0xFF334155),
                                                fontSize: 12.5,
                                                height: 1.35,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF94A3B8)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  item.createdAt,
                                                  style: const TextStyle(
                                                    color: Color(0xFF94A3B8),
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Contextual Action Button
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        if (!item.isRead) {
                                          widget.state.markNotificationRead(item.id);
                                        }
                                        Navigator.maybePop(context);
                                        if (isDelivery) {
                                          widget.state.setTab(3); // Switch to Tracker
                                        } else if (isWallet) {
                                          widget.state.setTab(2); // Switch to Wallet
                                        } else {
                                          widget.state.setTab(0); // Switch to Storefront
                                        }
                                      },
                                      icon: Icon(
                                        isDelivery
                                            ? Icons.directions_bike_rounded
                                            : (isWallet ? Icons.account_balance_wallet_rounded : Icons.storefront_rounded),
                                        size: 14,
                                        color: UiTone.primary,
                                      ),
                                      label: Text(
                                        isDelivery
                                            ? 'Track Delivery 🚚'
                                            : (isWallet ? 'View Wallet 💳' : 'Explore Catalog 🥛'),
                                        style: const TextStyle(
                                          color: UiTone.primary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: UiTone.primary,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: FontWeight.w800,
        fontSize: 11.5,
      ),
      side: BorderSide(
        color: isSelected ? UiTone.primary : Colors.white.withValues(alpha: 0.2),
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = filterKey);
      },
    );
  }
}
