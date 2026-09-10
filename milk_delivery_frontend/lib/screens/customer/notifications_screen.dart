import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../models/notification_model.dart';
import '../../services/notification_router.dart';
import '../../widgets/ui_kit/ui_empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  final AppState state;

  const NotificationsScreen({super.key, required this.state});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _showUnreadOnly = false;
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final allNotifs = widget.state.notifications;
    final unreadCount = widget.state.unreadNotificationCount;

    final filteredNotifs = allNotifs.where((n) {
      if (_showUnreadOnly && n.isRead) return false;
      if (_selectedCategory == 'Deliveries' && n.notificationType != 'DELIVERY') return false;
      if (_selectedCategory == 'Wallet' && n.notificationType != 'WALLET') return false;
      if (_selectedCategory == 'Offers' && n.notificationType != 'OFFER') return false;
      if (_selectedCategory == 'System' && n.notificationType != 'VACATION') return false;
      return true;
    }).toList();

    final groups = _groupNotifications(filteredNotifs);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.maybePop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                fontSize: 18,
              ),
            ),
            Text(
              unreadCount > 0 ? '$unreadCount unread update(s)' : 'You are all caught up',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Color(0xFF0D7C66)),
            tooltip: 'Mark all read',
            onPressed: () {
              widget.state.markAllNotificationsRead();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFE2E8F0),
            height: 1.0,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0D7C66),
        strokeWidth: 2.5,
        onRefresh: () async {
          await widget.state.reloadAllData(silent: true);
        },
        child: Builder(
          builder: (context) {
            final items = <dynamic>[
              'info_banner',
              'spacer_16',
              'toggle_pill',
              'spacer_16',
              'category_chips',
              'spacer_16',
            ];
            
            if (filteredNotifs.isEmpty) {
              items.add('empty_state');
            } else {
              if (groups['Today']!.isNotEmpty) {
                items.add({'header': 'Today'});
                items.addAll(groups['Today']!);
                items.add('spacer_8');
              }
              if (groups['Yesterday']!.isNotEmpty) {
                items.add({'header': 'Yesterday'});
                items.addAll(groups['Yesterday']!);
                items.add('spacer_8');
              }
              if (groups['Earlier']!.isNotEmpty) {
                items.add({'header': 'Earlier'});
                items.addAll(groups['Earlier']!);
                items.add('spacer_8');
              }
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 42),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (item == 'info_banner') return _buildInfoBanner();
                if (item == 'spacer_16') return const SizedBox(height: 16);
                if (item == 'spacer_8') return const SizedBox(height: 8);
                if (item == 'toggle_pill') return _buildTogglePill(allNotifs.length, unreadCount);
                if (item == 'category_chips') return _buildCategoryChips();
                if (item == 'empty_state') {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: _buildEmptyState(),
                  );
                }
                if (item is Map && item.containsKey('header')) {
                  return _buildSectionHeader(item['header']!);
                }
                if (item is NotificationModel) {
                  return _buildNotificationTile(item);
                }
                return const SizedBox.shrink();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6F1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCBE7DB)),
        boxShadow: const [
          BoxShadow(color: Color(0x050F172A), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stay on top of every delivery',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Delivery confirmations, wallet updates, and important reminders appear here.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
              height: 1.3,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTogglePill(int allCount, int unreadCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showUnreadOnly = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_showUnreadOnly ? const Color(0xFFE6F5F0) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'All ($allCount)',
                  style: TextStyle(
                    color: !_showUnreadOnly ? const Color(0xFF0D7C66) : const Color(0xFF475569),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showUnreadOnly = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _showUnreadOnly ? const Color(0xFFE6F5F0) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Unread ($unreadCount)',
                  style: TextStyle(
                    color: _showUnreadOnly ? const Color(0xFF0D7C66) : const Color(0xFF475569),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = ['All', 'Deliveries', 'Wallet', 'Offers', 'System'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          IconData? icon;
          if (cat == 'Deliveries') icon = Icons.local_shipping_rounded;
          else if (cat == 'Wallet') icon = Icons.account_balance_wallet_outlined;
          else if (cat == 'Offers') icon = Icons.local_offer_outlined;
          else if (cat == 'System') icon = Icons.info_outline_rounded;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0D7C66) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF0F172A)),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      cat,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0, left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildNotificationTile(NotificationModel item) {
    Color catColor = const Color(0xFF2563EB);
    IconData catIcon = Icons.notifications_active_rounded;
    if (item.notificationType == 'DELIVERY') {
      catColor = const Color(0xFF0D7C66);
      catIcon = Icons.local_shipping_rounded;
    } else if (item.notificationType == 'WALLET') {
      catColor = const Color(0xFFD97706);
      catIcon = Icons.account_balance_wallet_rounded;
    } else if (item.notificationType == 'OFFER') {
      catColor = const Color(0xFF16A34A);
      catIcon = Icons.local_offer_rounded;
    }

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
      ),
      onDismissed: (direction) {
        widget.state.dismissNotification(item.id);
      },
      child: GestureDetector(
        onTap: () {
          NotificationRouter.navigate(context, item, widget.state);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: item.isRead ? Colors.white : const Color(0xFFF5FFFA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: item.isRead ? const Color(0xFFE2E8F0).withValues(alpha: 0.7) : const Color(0xFFCFEBDD),
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x050F172A), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(catIcon, color: catColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.isRead ? FontWeight.w700 : FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        height: 1.28,
                        fontSize: 14,
                      ),
                    ),
                    if (item.message.isNotEmpty && item.message != item.title) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.message,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF334155),
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          item.createdAt,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Tap to view ➔',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: catColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!item.isRead) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B766),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFFC0C8C4), size: 22),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const UiEmptyState(
      emoji: '🔔',
      title: 'All Caught Up!',
      message: 'No new notifications. We\'ll keep you posted on deliveries and offers.',
    );
  }

  Map<String, List<NotificationModel>> _groupNotifications(List<NotificationModel> notifs) {
    final Map<String, List<NotificationModel>> groups = {
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    for (final n in notifs) {
      final dt = DateTime.tryParse(n.createdAt);
      if (dt != null) {
        final date = DateTime(dt.year, dt.month, dt.day);
        if (date == today) {
          groups['Today']!.add(n);
        } else if (date == yesterday) {
          groups['Yesterday']!.add(n);
        } else {
          groups['Earlier']!.add(n);
        }
      } else {
        final lower = n.createdAt.toLowerCase();
        if (lower.contains('today') || lower.contains('just now') || lower.contains('mins') || lower.contains('hour')) {
           groups['Today']!.add(n);
        } else if (lower.contains('yesterday')) {
           groups['Yesterday']!.add(n);
        } else {
           groups['Earlier']!.add(n);
        }
      }
    }
    return groups;
  }
}
