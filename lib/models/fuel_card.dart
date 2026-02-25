import 'dart:convert';

/// The type of payment or loyalty card a driver can enroll.
enum FuelCardType {
  /// EFS fleet/fuel card (fleet).
  efs,

  /// Comdata fleet/fuel card (fleet).
  comdata,

  /// WEX fleet/fuel card (fleet).
  wex,

  /// Fleet One fleet/fuel card (fleet).
  fleetOne,

  /// Standard credit or debit card.
  creditDebit,

  /// Truck-stop or fuel loyalty / rewards card.
  loyalty,
}

/// Human-readable label for each [FuelCardType].
extension FuelCardTypeLabel on FuelCardType {
  String get displayName {
    switch (this) {
      case FuelCardType.efs:
        return 'EFS';
      case FuelCardType.comdata:
        return 'Comdata';
      case FuelCardType.wex:
        return 'WEX';
      case FuelCardType.fleetOne:
        return 'Fleet One';
      case FuelCardType.creditDebit:
        return 'Credit / Debit';
      case FuelCardType.loyalty:
        return 'Loyalty / Rewards';
    }
  }
}

/// A payment or loyalty card enrolled by the driver.
///
/// Full card numbers are **never** stored.  Only the last four digits are kept
/// (as [lastFour]) so the app can display a masked identifier such as
/// `**** **** **** 1234` without retaining sensitive PAN data.
class FuelCard {
  const FuelCard({
    required this.id,
    required this.type,
    required this.lastFour,
    required this.cardholderName,
    required this.expiryMonth,
    required this.expiryYear,
    this.programName,
  });

  /// Unique identifier for this card enrollment (UUID).
  final String id;

  /// Category of card.
  final FuelCardType type;

  /// Last four digits of the card number (e.g. `'1234'`).
  ///
  /// Combined with mask prefix for display: `**** 1234`.
  final String lastFour;

  /// Name of the cardholder as it appears on the card.
  final String cardholderName;

  /// Expiry month (1–12).
  final int expiryMonth;

  /// Expiry year (four-digit, e.g. 2027).
  final int expiryYear;

  /// Optional program or network name (e.g. `'Pilot MyRewards'`).
  ///
  /// Typically used for [FuelCardType.loyalty] cards.
  final String? programName;

  /// Display string showing the masked card number, e.g. `'**** 1234'`.
  String get maskedNumber => '**** $lastFour';

  /// `true` when the card has not expired relative to [now].
  bool isValid({DateTime? now}) {
    final today = now ?? DateTime.now();
    final expiry = DateTime(expiryYear, expiryMonth + 1); // first day after expiry
    return today.isBefore(expiry);
  }

  /// Serialize to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'lastFour': lastFour,
        'cardholderName': cardholderName,
        'expiryMonth': expiryMonth,
        'expiryYear': expiryYear,
        if (programName != null) 'programName': programName,
      };

  /// Deserialize from a JSON-compatible map.
  factory FuelCard.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String;
    final type = FuelCardType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => FuelCardType.creditDebit,
    );
    return FuelCard(
      id: json['id'] as String,
      type: type,
      lastFour: json['lastFour'] as String,
      cardholderName: json['cardholderName'] as String,
      expiryMonth: json['expiryMonth'] as int,
      expiryYear: json['expiryYear'] as int,
      programName: json['programName'] as String?,
    );
  }

  /// Return a copy with the specified fields overridden.
  FuelCard copyWith({
    String? id,
    FuelCardType? type,
    String? lastFour,
    String? cardholderName,
    int? expiryMonth,
    int? expiryYear,
    String? programName,
  }) {
    return FuelCard(
      id: id ?? this.id,
      type: type ?? this.type,
      lastFour: lastFour ?? this.lastFour,
      cardholderName: cardholderName ?? this.cardholderName,
      expiryMonth: expiryMonth ?? this.expiryMonth,
      expiryYear: expiryYear ?? this.expiryYear,
      programName: programName ?? this.programName,
    );
  }
}

/// Encode a list of [FuelCard]s to a JSON string.
String fuelCardsToJson(List<FuelCard> cards) =>
    jsonEncode(cards.map((c) => c.toJson()).toList());

/// Decode a list of [FuelCard]s from a JSON string.
List<FuelCard> fuelCardsFromJson(String source) {
  final list = jsonDecode(source) as List<dynamic>;
  return list
      .map((e) => FuelCard.fromJson(e as Map<String, dynamic>))
      .toList();
}
