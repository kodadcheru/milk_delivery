class StorefrontConfigModel {
  final int id;
  final String bannerImageUrl;
  final String? rawBannerImageUrl;
  final String headline;
  final String subtitle;
  final String dispatchTag;
  final String promoChip;
  final String ctaText;
  final bool isCodEnabled;
  final bool isWalletEnabled;
  final bool isOnlinePaymentEnabled;
  final bool isActive;
  final double platformFee;
  final double taxPercentage;
  final double deliveryFee;
  final double freeDeliveryThreshold;

  const StorefrontConfigModel({
    this.id = 1,
    this.bannerImageUrl = 'https://images.unsplash.com/photo-1527153857715-3908f2bae5e8?auto=format&fit=crop&w=1200&q=80',
    this.rawBannerImageUrl,
    this.headline = 'Order by 11PM Tonight →',
    this.subtitle = '❄️ 4°C Cold Chain • Farm to Doorstep • Kodad Hub',
    this.dispatchTag = 'MORNING DROP 05:30 AM ☀️',
    this.promoChip = '🥛 FRESH TODAY',
    this.ctaText = 'SUBSCRIBE NOW ➔',
    this.isCodEnabled = true,
    this.isWalletEnabled = true,
    this.isOnlinePaymentEnabled = true,
    this.isActive = true,
    this.platformFee = 0.0,
    this.taxPercentage = 0.0,
    this.deliveryFee = 0.0,
    this.freeDeliveryThreshold = 0.0,
  });

  factory StorefrontConfigModel.fromJson(Map<String, dynamic> json) {
    return StorefrontConfigModel(
      id: json['id'] as int? ?? 1,
      bannerImageUrl: (json['banner_image_url'] as String?)?.isNotEmpty == true
          ? json['banner_image_url'] as String
          : 'https://images.unsplash.com/photo-1527153857715-3908f2bae5e8?auto=format&fit=crop&w=1200&q=80',
      rawBannerImageUrl: json['raw_banner_image_url'] as String?,
      headline: json['headline'] != null ? (json['headline'] as String) : 'Order by 11PM Tonight →',
      subtitle: json['subtitle'] != null ? (json['subtitle'] as String) : '❄️ 4°C Cold Chain • Farm to Doorstep • Kodad Hub',
      dispatchTag: json['dispatch_tag'] != null ? (json['dispatch_tag'] as String) : 'MORNING DROP 05:30 AM ☀️',
      promoChip: json['promo_chip'] != null ? (json['promo_chip'] as String) : '🥛 FRESH TODAY',
      ctaText: json['cta_text'] != null ? (json['cta_text'] as String) : 'SUBSCRIBE NOW ➔',
      isCodEnabled: json['is_cod_enabled'] as bool? ?? true,
      isWalletEnabled: json['is_wallet_enabled'] as bool? ?? true,
      isOnlinePaymentEnabled: json['is_online_payment_enabled'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      platformFee: (json['platform_fee'] as num?)?.toDouble() ?? 0.0,
      taxPercentage: (json['tax_percentage'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      freeDeliveryThreshold: (json['free_delivery_threshold'] as num?)?.toDouble() ?? 0.0,
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
    'is_cod_enabled': isCodEnabled,
    'is_wallet_enabled': isWalletEnabled,
    'is_online_payment_enabled': isOnlinePaymentEnabled,
    'is_active': isActive,
    'platform_fee': platformFee,
    'tax_percentage': taxPercentage,
    'delivery_fee': deliveryFee,
    'free_delivery_threshold': freeDeliveryThreshold,
  };

  StorefrontConfigModel copyWith({
    int? id,
    String? bannerImageUrl,
    String? rawBannerImageUrl,
    String? headline,
    String? subtitle,
    String? dispatchTag,
    String? promoChip,
    String? ctaText,
    bool? isCodEnabled,
    bool? isWalletEnabled,
    bool? isOnlinePaymentEnabled,
    bool? isActive,
    double? platformFee,
    double? taxPercentage,
    double? deliveryFee,
    double? freeDeliveryThreshold,
  }) {
    return StorefrontConfigModel(
      id: id ?? this.id,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      rawBannerImageUrl: rawBannerImageUrl ?? this.rawBannerImageUrl,
      headline: headline ?? this.headline,
      subtitle: subtitle ?? this.subtitle,
      dispatchTag: dispatchTag ?? this.dispatchTag,
      promoChip: promoChip ?? this.promoChip,
      ctaText: ctaText ?? this.ctaText,
      isCodEnabled: isCodEnabled ?? this.isCodEnabled,
      isWalletEnabled: isWalletEnabled ?? this.isWalletEnabled,
      isOnlinePaymentEnabled: isOnlinePaymentEnabled ?? this.isOnlinePaymentEnabled,
      isActive: isActive ?? this.isActive,
      platformFee: platformFee ?? this.platformFee,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      freeDeliveryThreshold: freeDeliveryThreshold ?? this.freeDeliveryThreshold,
    );
  }
}
