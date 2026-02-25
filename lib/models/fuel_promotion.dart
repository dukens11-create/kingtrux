import 'fuel_card.dart';

/// A fuel discount or promotional offer available at participating truck stops.
class FuelPromotion {
  const FuelPromotion({
    required this.id,
    required this.title,
    required this.description,
    required this.discountCentsPerGallon,
    this.expiresAt,
    this.applicableCardTypes = const [],
    this.participatingBrands = const [],
  });

  /// Unique identifier for this promotion.
  final String id;

  /// Short promotional title shown in the app, e.g. `'5¢ off per gallon'`.
  final String title;

  /// Detailed description of the promotion terms.
  final String description;

  /// Discount amount in US cents per gallon (e.g. `5` = $0.05/gal).
  ///
  /// A value of `0` means the promotion applies a non-monetary benefit
  /// (e.g. free coffee).
  final int discountCentsPerGallon;

  /// Optional expiry date/time after which the promotion is no longer valid.
  final DateTime? expiresAt;

  /// Card types that unlock this promotion.
  ///
  /// An empty list means the promotion is available to all drivers regardless
  /// of enrolled cards.
  final List<FuelCardType> applicableCardTypes;

  /// Truck-stop brand names (display names) where this promotion is valid.
  ///
  /// An empty list means the promotion is valid at all participating locations.
  final List<String> participatingBrands;

  /// `true` when the promotion has not expired relative to [now].
  bool isActive({DateTime? now}) {
    if (expiresAt == null) return true;
    final today = now ?? DateTime.now();
    return today.isBefore(expiresAt!);
  }

  /// `true` when [cardType] qualifies for this promotion, or when the
  /// promotion is open to all card types.
  bool isApplicableToCard(FuelCardType cardType) {
    if (applicableCardTypes.isEmpty) return true;
    return applicableCardTypes.contains(cardType);
  }

  /// Serialize to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'discountCentsPerGallon': discountCentsPerGallon,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        'applicableCardTypes':
            applicableCardTypes.map((t) => t.name).toList(),
        'participatingBrands': participatingBrands,
      };

  /// Deserialize from a JSON-compatible map.
  factory FuelPromotion.fromJson(Map<String, dynamic> json) {
    final rawTypes =
        (json['applicableCardTypes'] as List<dynamic>? ?? []).cast<String>();
    final cardTypes = rawTypes
        .map(
          (n) => FuelCardType.values.firstWhere(
            (t) => t.name == n,
            orElse: () => FuelCardType.creditDebit,
          ),
        )
        .toList();

    return FuelPromotion(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      discountCentsPerGallon: json['discountCentsPerGallon'] as int,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      applicableCardTypes: cardTypes,
      participatingBrands:
          (json['participatingBrands'] as List<dynamic>? ?? []).cast<String>(),
    );
  }
}
