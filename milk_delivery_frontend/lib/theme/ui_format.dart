/// Currency + discount formatting — the single source of truth for how prices
/// render across the shop (product cards, sheets, cart, checkout).
///
/// The struck-through "original" price is intentionally cosmetic: it is derived
/// from the live price by a fixed markup so every surface tells the same
/// discount story. Centralising it here keeps the markup in exactly one place
/// (previously each widget inlined its own `* 1.12`).
class UiFormat {
  UiFormat._();

  /// Fixed markup behind the struck-through "original" price. Cosmetic only.
  static const double _strikeMarkup = 1.12;

  /// `₹129` — whole rupees, no decimals. Matches every price label in the shop.
  static String price(num value) => '₹${value.toStringAsFixed(0)}';

  /// The struck-through "original" price value shown beside the live price.
  static double strikeValue(num livePrice) => livePrice * _strikeMarkup;

  /// Convenience: the formatted struck-through "original" price string.
  static String strike(num livePrice) => price(strikeValue(livePrice));

  /// Whole-percent "savings" implied by the markup (e.g. 11 for a 12% markup),
  /// for an optional "SAVE X%" badge. Derived from the same markup so the badge
  /// and the struck-through price can never disagree.
  static int get discountPercent =>
      (((_strikeMarkup - 1) / _strikeMarkup) * 100).round();
}
