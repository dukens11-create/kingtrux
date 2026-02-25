import '../models/fuel_card.dart';
import '../models/fuel_promotion.dart';

/// Pure-Dart helper for filtering and matching [FuelPromotion]s against a
/// driver's enrolled cards and current route context.
///
/// All methods are static so the class is lightweight and easy to unit-test
/// without any platform dependencies.
class FuelPromotionService {
  const FuelPromotionService._();

  /// Return only the promotions from [promotions] that are currently active
  /// (not expired) relative to [now].
  ///
  /// [now] defaults to [DateTime.now()] when omitted.
  static List<FuelPromotion> activePromotions(
    List<FuelPromotion> promotions, {
    DateTime? now,
  }) =>
      promotions.where((p) => p.isActive(now: now)).toList();

  /// Return promotions that are applicable to **at least one** of the supplied
  /// [enrolledCards].
  ///
  /// A promotion with an empty [FuelPromotion.applicableCardTypes] list is
  /// always returned (open to all cards).
  ///
  /// Only active (non-expired) promotions are included.
  static List<FuelPromotion> promotionsForCards(
    List<FuelPromotion> promotions,
    List<FuelCard> enrolledCards, {
    DateTime? now,
  }) {
    final cardTypes = enrolledCards.map((c) => c.type).toSet();
    return activePromotions(promotions, now: now).where((p) {
      if (p.applicableCardTypes.isEmpty) return true;
      return p.applicableCardTypes.any(cardTypes.contains);
    }).toList();
  }

  /// Return promotions valid at a truck stop identified by [brandDisplayName].
  ///
  /// A promotion with an empty [FuelPromotion.participatingBrands] list is
  /// considered valid at all locations.
  ///
  /// Only active promotions applicable to the driver's enrolled cards are
  /// returned.
  static List<FuelPromotion> promotionsAtBrand(
    List<FuelPromotion> promotions,
    List<FuelCard> enrolledCards,
    String brandDisplayName, {
    DateTime? now,
  }) {
    return promotionsForCards(promotions, enrolledCards, now: now).where((p) {
      if (p.participatingBrands.isEmpty) return true;
      return p.participatingBrands.contains(brandDisplayName);
    }).toList();
  }

  /// Return the total discount (in cents per gallon) a driver would receive
  /// by stacking all applicable [promotions].
  ///
  /// Promotions are not deduplicated — callers should supply only the
  /// promotions relevant to a single stop (e.g. via [promotionsAtBrand]).
  static int totalDiscountCentsPerGallon(List<FuelPromotion> promotions) =>
      promotions.fold(0, (sum, p) => sum + p.discountCentsPerGallon);
}
