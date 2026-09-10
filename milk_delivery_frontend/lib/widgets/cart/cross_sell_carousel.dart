import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/ui_tokens.dart';
import '../../models/product_model.dart';
import '../../providers/app_state.dart';

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
        const Text(
          '✨ Frequently Bought Together',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: UiTone.ink),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final product = products[index];
              return Container(
                width: 110,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: product.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.imageUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Text(product.icon, style: const TextStyle(fontSize: 24)),
                            )
                          : Text(product.icon, style: const TextStyle(fontSize: 24)),
                    ),
                    Text(
                      product.name,
                      style: const TextStyle(fontSize: 12, color: UiTone.ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${product.pricePerUnit.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: UiTone.ink),
                        ),
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            state.addToCart(product);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: UiTone.primary),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              '+ ADD',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: UiTone.primary),
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
