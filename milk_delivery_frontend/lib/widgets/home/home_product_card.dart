import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product_model.dart';
import '../../providers/app_state.dart';
import '../../services/pack_pricing.dart';
import '../../theme/ui_format.dart';
import '../../theme/ui_tokens.dart';
import '../buy_once_sheet.dart';
import '../cart/pack_size_selector_sheet.dart';
import '../floating_cart_bar.dart'; // ignore: unused_import
import '../product_detail_sheet.dart';
import 'home_location_sheet.dart';
import '../ui_kit/ui_kit.dart';

/// Product card shared by the home grid and the category products screen.
///
/// Tap the body to open the lightweight [BuyOnceSheet] (pick a pack size); the
/// trailing control adds the base pack straight to the cart and then becomes an
/// inline −/N/+ stepper so a second delivery never requires opening a sheet.
class HomeProductCard extends StatefulWidget {
  final AppState state;
  final ProductModel item;

  const HomeProductCard({
    super.key,
    required this.state,
    required this.item,
  });

  @override
  State<HomeProductCard> createState() => _HomeProductCardState();
}

class _HomeProductCardState extends State<HomeProductCard> with SingleTickerProviderStateMixin {
  late AnimationController _addBounceController;
  late Animation<double> _addBounceAnimation;

  @override
  void initState() {
    super.initState();
    _addBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _addBounceAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _addBounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _addBounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final item = widget.item;
    final isCovered = state.isLocationCovered;
    final packOptions = PackPricing.packOptionsFor(item);
    final hasMultipleSizes = packOptions.length > 1;
    final inCartQty = hasMultipleSizes
        ? state.totalCartQtyForProductId(item.id)
        : state.cartQtyOf(item);

    Widget card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(UiRadius.lg),
        boxShadow: UiShadow.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(UiRadius.lg),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isCovered
                ? () => BuyOnceSheet.show(context, item, state)
                : () => _showOutOfZoneSheet(context),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Full-bleed image or emoji fallback
                Hero(
                  tag: 'product_image_${item.id}',
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildEmojiFallback(),
                        )
                      : _buildEmojiFallback(),
                ),

                // 2. Bottom gradient overlay — covers lower 55%
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.88),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),

                // 3. Top-left category badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(UiRadius.xs),
                    ),
                    child: Text(
                      item.localizedBadgeText(state.currentLanguage).isNotEmpty
                          ? item.localizedBadgeText(state.currentLanguage)
                          : item.localizedCategory(state.currentLanguage),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: UiTone.primary,
                      ),
                    ),
                  ),
                ),

                // 4. Top-right prominent Quick Subscribe / Out of Zone Badge
                if (item.isSubscriptionEnabled)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                    onTap: isCovered
                        ? () => ProductDetailSheet.show(context, item, state)
                        : () => _showOutOfZoneSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isCovered ? null : const Color(0xFF334155),
                        gradient: isCovered
                            ? const LinearGradient(
                                colors: [Color(0xFF0E784D), Color(0xFF044E32)],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(UiRadius.pill),
                        border: Border.all(
                          color: isCovered ? const Color(0xFF34D399) : const Color(0xFF64748B),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCovered ? Icons.repeat_rounded : Icons.location_off_rounded,
                            size: 11,
                            color: isCovered ? const Color(0xFF34D399) : const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isCovered ? 'SUBSCRIBE' : 'OUT OF ZONE',
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 5. Out of stock overlay
                if (item.isOutOfStock)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.55),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                          ),
                          borderRadius: BorderRadius.circular(UiRadius.xs),
                        ),
                        child: const Text(
                          'SOLD OUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 6. Bottom content — aligned to bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Product name (Localized)
                        Text(
                          item.localizedName(state.currentLanguage),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 2),

                        // Unit
                        Row(
                          children: [
                            Icon(Icons.scale, size: 10, color: Colors.white.withValues(alpha: 0.7)),
                            const SizedBox(width: 3),
                            Text(
                              item.unitQuantity,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Price row + cart / subscribe control
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Price
                            Flexible(
                              child: Text(
                                UiFormat.price(item.pricePerUnit),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            // Controls: Subscribe + ADD
                            if (!item.isOutOfStock) _buildCartControl(context, inCartQty, hasMultipleSizes),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!isCovered) {
      card = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      0.82, 0,
        ]),
        child: card,
      );
    }

    return card;
  }

  Widget _buildCartControl(BuildContext context, int inCartQty, bool hasMultipleSizes) {
    final state = widget.state;
    final item = widget.item;
    if (!state.isLocationCovered) {
      return GestureDetector(
        onTap: () => _showOutOfZoneSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(UiRadius.pill),
            border: Border.all(color: const Color(0xFF64748B), width: 0.8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_rounded, size: 10, color: Color(0xFFCBD5E1)),
              SizedBox(width: 4),
              Text(
                'UNAVAILABLE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE2E8F0),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (inCartQty == 0 && item.isSubscriptionEnabled)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () => ProductDetailSheet.show(context, item, state),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E784D),
                  borderRadius: BorderRadius.circular(UiRadius.pill),
                  border: Border.all(color: const Color(0xFF34D399), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat_rounded, size: 11, color: Color(0xFF34D399)),
                    SizedBox(width: 2),
                    Text(
                      'SUB',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: inCartQty == 0 ? Colors.white : UiTone.primary,
            borderRadius: BorderRadius.circular(UiRadius.pill),
            boxShadow: inCartQty > 0 ? UiShadow.glowPrimary : null,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axis: Axis.horizontal,
                  child: child,
                ),
              );
            },
            child: inCartQty == 0
                ? ScaleTransition(
                    key: const ValueKey('add'),
                    scale: _addBounceAnimation,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        _addBounceController.forward().then((_) => _addBounceController.reverse());
                        PackSizeSelectorSheet.show(context, product: item, state: state);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: const Text(
                          'ADD +',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: UiTone.primary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  )
                : (hasMultipleSizes
                    ? GestureDetector(
                        key: ValueKey('in_cart_multi_$inCartQty'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          PackSizeSelectorSheet.show(context, product: item, state: state);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$inCartQty',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.arrow_drop_down_rounded, size: 14, color: Colors.white),
                            ],
                          ),
                        ),
                      )
                    : Row(
                        key: ValueKey('stepper_$inCartQty'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _stepButton(Icons.remove_rounded, () => state.decreaseCartQty(item)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                              child: Text(
                                '$inCartQty',
                                key: ValueKey<int>(inCartQty),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          _stepButton(Icons.add_rounded, () => state.addToCart(item)),
                        ],
                      )),
          ),
        ),
      ],
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _buildEmojiFallback() {
    final item = widget.item;
    // Category-based pastel background
    Color bgStart;
    Color bgEnd;
    switch (item.category) {
      case 'MILK':
        bgStart = const Color(0xFFE6F5F0);
        bgEnd = const Color(0xFFD1FAE5);
        break;
      case 'MEAT':
        bgStart = const Color(0xFFFDE8E8);
        bgEnd = const Color(0xFFFFE4E6);
        break;
      case 'EGGS':
        bgStart = const Color(0xFFFFF3E6);
        bgEnd = const Color(0xFFFEF3C7);
        break;
      case 'WATER_CAN':
        bgStart = const Color(0xFFE8F2FE);
        bgEnd = const Color(0xFFDBEAFE);
        break;
      default:
        bgStart = const Color(0xFFF8FAFC);
        bgEnd = const Color(0xFFE2E8F0);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgStart, bgEnd],
        ),
      ),
      child: Center(
        child: Text(
          item.icon,
          style: const TextStyle(fontSize: 44),
        ),
      ),
    );
  }

  void _showOutOfZoneSheet(BuildContext context) {
    final state = widget.state;
    final item = widget.item;
    final hubName = state.primaryHub['name'] ?? 'Kodad Hub';
    final radius = state.primaryHub['coverage_radius_km'] ?? '8.5';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_off_rounded, color: Color(0xFFD97706), size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              '${item.name} is Unavailable in Current Area',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Our daily early morning (05:30 AM) delivery is active within the $hubName service zone ($radius km radius). You can switch your delivery location to an operational area, or submit interest to request expansion.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  HomeLocationSheet.show(context, state);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: UiTone.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.location_on_rounded, size: 18),
                label: const Text('📍 Switch Delivery Location', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await state.requestCoverageExpansion();
                  if (context.mounted) {
                    PambaToast.show(
                      context,
                      message: '🔔 Interest recorded for ${state.currentCityOrTown}! We will notify you.',
                      type: ToastType.info,
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: UiTone.primary, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.notifications_active_rounded, size: 16, color: UiTone.primary),
                label: const Text('Notify Me When We Launch Here', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: UiTone.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
