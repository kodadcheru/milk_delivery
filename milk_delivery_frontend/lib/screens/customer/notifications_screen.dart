import 'package:flutter/material.dart';
import '../../providers/app_state.dart';

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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          children: [
            const Text('Notifications 🔔', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount New',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (allNotifs.isNotEmpty)
            TextButton(
              onPressed: () {
                widget.state.markAllNotificationsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications marked as read.')),
                );
              },
              child: const Text('Mark All Read', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Category Chips
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'All (${allNotifs.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Deliveries', '🚚 Deliveries'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Wallet', '⚡ Wallet'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Updates', '📢 Updates & Offers'),
                ],
              ),
            ),
          ),

          Expanded(
            child: filteredNotifs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey),
                          SizedBox(height: 14),
                          Text('No Notifications in this Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 6),
                          Text('Daily delivery proofs, morning dispatches, and wallet top-up alerts will appear here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
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

                      return Card(
                        elevation: item.isRead ? 0.5 : 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        color: item.isRead ? Colors.white : const Color(0xFFF0FDF4),
                        child: InkWell(
                          onTap: () {
                            if (!item.isRead) {
                              widget.state.markNotificationRead(item.id);
                            }
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isDelivery
                                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                            : (isWallet ? Colors.amber.withValues(alpha: 0.2) : Colors.purple.withValues(alpha: 0.2)),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isDelivery ? Icons.local_shipping_rounded : (isWallet ? Icons.account_balance_wallet_rounded : Icons.campaign_rounded),
                                        color: isDelivery ? const Color(0xFF0D7C66) : (isWallet ? Colors.amber[900] : Colors.purple[700]),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
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
                                                    fontWeight: item.isRead ? FontWeight.bold : FontWeight.w900,
                                                    fontSize: 14,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              if (!item.isRead)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text('NEW', style: TextStyle(color: Color(0xFFE11D48), fontSize: 9, fontWeight: FontWeight.bold)),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.message,
                                            style: TextStyle(color: Colors.grey[800], fontSize: 12, height: 1.3),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            item.createdAt,
                                            style: TextStyle(color: Colors.grey[500], fontSize: 10),
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
                                        widget.state.setTab(1); // Switch to Tracker
                                      } else if (isWallet) {
                                        widget.state.setTab(2); // Switch to Wallet
                                      } else {
                                        widget.state.setTab(0); // Switch to Storefront
                                      }
                                    },
                                    icon: Icon(
                                      isDelivery ? Icons.directions_bike_rounded : (isWallet ? Icons.account_balance_wallet_rounded : Icons.storefront_rounded),
                                      size: 14,
                                      color: const Color(0xFF0D7C66),
                                    ),
                                    label: Text(
                                      isDelivery ? 'Track Delivery 🚚' : (isWallet ? 'View Wallet 💳' : 'Explore Catalog 🥛'),
                                      style: const TextStyle(color: Color(0xFF0D7C66), fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ),
                              ],
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
      selectedColor: const Color(0xFF0D7C66),
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      side: BorderSide(color: isSelected ? const Color(0xFF0D7C66) : Colors.transparent),
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = filterKey);
      },
    );
  }
}
