import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/ui_tokens.dart';
import '../../models/product_model.dart';
import '../../providers/app_state.dart';
import '../../services/pack_pricing.dart';
import 'pack_size_selector_sheet.dart';

class CrossSellCarousel extends StatelessWidget {
  final List<ProductModel> products;
  final AppState state;

  const CrossSellCarousel({
    super.key,
    required this.products,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                state.isTelugu ? '✨ ఎక్కువగా కొనుగోలు చేసేవి' : '✨ Frequently Added Together',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: UiTone.ink,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 154,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final product = products[index];
              final packOptions = PackPricing.packOptionsFor(product);
              final hasMultipleSizes = packOptions.length > 1;
              final inCartQty = hasMultipleSizes
                  ? state.totalCartQtyForProductId(product.id)
                  : state.cartQtyOf(product);

              return Container(
                width: 120,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(UiRadius.md),
                  border: Border.all(color: UiTone.surfaceBorder, width: 0.8),
                  boxShadow: UiShadow.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image
                    Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: product.imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: product.imageUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Center(
                                    child: Text(product.icon, style: const TextStyle(fontSize: 24)),
                                  ),
                                )
                              : Center(
                                  child: Text(product.icon, style: const TextStyle(fontSize: 24)),
                                ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      product.localizedName(state.currentLanguage),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: UiTone.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      product.unitQuantity,
                      style: const TextStyle(fontSize: 10, color: UiTone.softText),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '₹${product.pricePerUnit.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: UiTone.ink,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            PackSizeSelectorSheet.show(context, product: product, state: state);
                          },
                          borderRadius: BorderRadius.circular(UiRadius.pill),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: inCartQty > 0 ? UiTone.primary : Colors.white,
                              borderRadius: BorderRadius.circular(UiRadius.pill),
                              border: Border.all(
                                color: UiTone.primary,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              inCartQty > 0
                                  ? (state.isTelugu ? '$inCartQty చేర్చబడింది' : '$inCartQty IN')
                                  : (state.isTelugu ? '+ చేర్చండి' : '+ ADD'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: inCartQty > 0 ? Colors.white : UiTone.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
