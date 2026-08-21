class StorefrontConfigModel {
  final int id;
  final String bannerImageUrl;
  final String? rawBannerImageUrl;
  final String headline;
  final String subtitle;
  final String dispatchTag;
  final String promoChip;
  final String ctaText;
  final bool isActive;

  const StorefrontConfigModel({
    this.id = 1,
    this.bannerImageUrl = 'https://images.unsplash.com/photo-1527153857715-3908f2bae5e8?auto=format&fit=crop&w=1200&q=80',
    this.rawBannerImageUrl,
    this.headline = 'Order by 11PM Tonight →',
    this.subtitle = '❄️ 4°C Cold Chain • Farm to Doorstep • Kodad Hub',
    this.dispatchTag = 'MORNING DROP 05:30 AM ☀️',
    this.promoChip = '🥛 FRESH TODAY',
    this.ctaText = 'SUBSCRIBE NOW ➔',
    this.isActive = true,
  });

  factory StorefrontConfigModel.fromJson(Map<String, dynamic> json) {
    return StorefrontConfigModel(
      id: json['id'] as int? ?? 1,
      bannerImageUrl: (json['banner_image_url'] as String?)?.isNotEmpty == true
          ? json['banner_image_url'] as String
          : 'https://images.unsplash.com/photo-1527153857715-3908f2bae5e8?auto=format&fit=crop&w=1200&q=80',
      rawBannerImageUrl: json['raw_banner_image_url'] as String?,
      headline: (json['headline'] as String?)?.isNotEmpty == true
          ? json['headline'] as String
          : 'Order by 11PM Tonight →',
      subtitle: (json['subtitle'] as String?)?.isNotEmpty == true
          ? json['subtitle'] as String
          : '❄️ 4°C Cold Chain • Farm to Doorstep • Kodad Hub',
      dispatchTag: (json['dispatch_tag'] as String?)?.isNotEmpty == true
          ? json['dispatch_tag'] as String
          : 'MORNING DROP 05:30 AM ☀️',
      promoChip: (json['promo_chip'] as String?)?.isNotEmpty == true
          ? json['promo_chip'] as String
          : '🥛 FRESH TODAY',
      ctaText: (json['cta_text'] as String?)?.isNotEmpty == true
          ? json['cta_text'] as String
          : 'SUBSCRIBE NOW ➔',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'banner_image_url': bannerImageUrl,
    'raw_banner_image_url': rawBannerImageUrl,
    'headline': headline,
    'subtitle': subtitle,
    'dispatch_tag': dispatchTag,
    'promo_chip': promoChip,
    'cta_text': ctaText,
    'is_active': isActive,
  };
}
