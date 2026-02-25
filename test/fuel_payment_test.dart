import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/fuel_card.dart';
import 'package:kingtrux/models/fuel_promotion.dart';
import 'package:kingtrux/services/fuel_card_service.dart';
import 'package:kingtrux/services/fuel_promotion_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // FuelCardType
  // ---------------------------------------------------------------------------
  group('FuelCardType', () {
    test('has the six expected values', () {
      expect(FuelCardType.values, hasLength(6));
      expect(
        FuelCardType.values,
        containsAll([
          FuelCardType.efs,
          FuelCardType.comdata,
          FuelCardType.wex,
          FuelCardType.fleetOne,
          FuelCardType.creditDebit,
          FuelCardType.loyalty,
        ]),
      );
    });

    test('displayName is non-empty for every value', () {
      for (final t in FuelCardType.values) {
        expect(t.displayName, isNotEmpty, reason: '$t has an empty displayName');
      }
    });

    test('fleet card display names are correct', () {
      expect(FuelCardType.efs.displayName, 'EFS');
      expect(FuelCardType.comdata.displayName, 'Comdata');
      expect(FuelCardType.wex.displayName, 'WEX');
      expect(FuelCardType.fleetOne.displayName, 'Fleet One');
    });
  });

  // ---------------------------------------------------------------------------
  // FuelCard – construction & masking
  // ---------------------------------------------------------------------------
  group('FuelCard construction', () {
    FuelCard _card({
      String id = 'card-1',
      FuelCardType type = FuelCardType.efs,
      String lastFour = '5678',
      String name = 'J. Doe',
      int month = 6,
      int year = 2030,
      String? programName,
    }) =>
        FuelCard(
          id: id,
          type: type,
          lastFour: lastFour,
          cardholderName: name,
          expiryMonth: month,
          expiryYear: year,
          programName: programName,
        );

    test('maskedNumber shows only last four digits', () {
      final card = _card(lastFour: '9999');
      expect(card.maskedNumber, '**** 9999');
    });

    test('isValid returns true before expiry', () {
      final card = _card(month: 12, year: 2099);
      expect(card.isValid(now: DateTime(2024, 1, 1)), isTrue);
    });

    test('isValid returns false after expiry', () {
      // Card expires end of January 2020; today is February 2020.
      final card = _card(month: 1, year: 2020);
      expect(card.isValid(now: DateTime(2020, 2, 1)), isFalse);
    });

    test('isValid returns true on the last day of the expiry month', () {
      // An expiry of 06/2030 is valid through June 30, 2030.
      final card = _card(month: 6, year: 2030);
      expect(card.isValid(now: DateTime(2030, 6, 30)), isTrue);
    });

    test('isValid returns false on the first day of the following month', () {
      final card = _card(month: 6, year: 2030);
      expect(card.isValid(now: DateTime(2030, 7, 1)), isFalse);
    });

    test('programName is null by default', () {
      expect(_card().programName, isNull);
    });

    test('loyalty card can store a programName', () {
      final card = _card(
        type: FuelCardType.loyalty,
        programName: 'Pilot MyRewards',
      );
      expect(card.programName, 'Pilot MyRewards');
    });
  });

  // ---------------------------------------------------------------------------
  // FuelCard – copyWith
  // ---------------------------------------------------------------------------
  group('FuelCard.copyWith', () {
    test('overrides only specified fields', () {
      const original = FuelCard(
        id: 'c1',
        type: FuelCardType.wex,
        lastFour: '1111',
        cardholderName: 'Alice',
        expiryMonth: 3,
        expiryYear: 2025,
      );
      final copy = original.copyWith(lastFour: '2222', expiryYear: 2028);
      expect(copy.id, 'c1');
      expect(copy.type, FuelCardType.wex);
      expect(copy.lastFour, '2222');
      expect(copy.cardholderName, 'Alice');
      expect(copy.expiryMonth, 3);
      expect(copy.expiryYear, 2028);
    });
  });

  // ---------------------------------------------------------------------------
  // FuelCard – JSON serialization round-trip
  // ---------------------------------------------------------------------------
  group('FuelCard JSON', () {
    test('toJson / fromJson round-trips a basic card', () {
      const card = FuelCard(
        id: 'abc-123',
        type: FuelCardType.comdata,
        lastFour: '4321',
        cardholderName: 'Bob Smith',
        expiryMonth: 9,
        expiryYear: 2026,
      );
      final json = card.toJson();
      final restored = FuelCard.fromJson(json);

      expect(restored.id, card.id);
      expect(restored.type, card.type);
      expect(restored.lastFour, card.lastFour);
      expect(restored.cardholderName, card.cardholderName);
      expect(restored.expiryMonth, card.expiryMonth);
      expect(restored.expiryYear, card.expiryYear);
      expect(restored.programName, isNull);
    });

    test('round-trips a loyalty card with programName', () {
      const card = FuelCard(
        id: 'loyalty-1',
        type: FuelCardType.loyalty,
        lastFour: '0000',
        cardholderName: 'Carol',
        expiryMonth: 12,
        expiryYear: 2027,
        programName: "Love's Rewards",
      );
      final restored = FuelCard.fromJson(card.toJson());
      expect(restored.programName, "Love's Rewards");
    });

    test('full JSON string round-trip via fuelCardsToJson/fuelCardsFromJson', () {
      final cards = [
        const FuelCard(
          id: 'e1',
          type: FuelCardType.efs,
          lastFour: '1234',
          cardholderName: 'Driver One',
          expiryMonth: 1,
          expiryYear: 2028,
        ),
        const FuelCard(
          id: 'f1',
          type: FuelCardType.fleetOne,
          lastFour: '5678',
          cardholderName: 'Driver Two',
          expiryMonth: 6,
          expiryYear: 2029,
        ),
      ];
      final jsonStr = fuelCardsToJson(cards);
      final restored = fuelCardsFromJson(jsonStr);

      expect(restored, hasLength(2));
      expect(restored[0].id, 'e1');
      expect(restored[0].type, FuelCardType.efs);
      expect(restored[1].id, 'f1');
      expect(restored[1].type, FuelCardType.fleetOne);
    });

    test('unknown type name falls back to creditDebit', () {
      final raw = jsonEncode([
        {
          'id': 'x1',
          'type': 'unknownFutureType',
          'lastFour': '9999',
          'cardholderName': 'X',
          'expiryMonth': 1,
          'expiryYear': 2030,
        }
      ]);
      final cards = fuelCardsFromJson(raw);
      expect(cards.first.type, FuelCardType.creditDebit);
    });
  });

  // ---------------------------------------------------------------------------
  // FuelCardService – persistence
  // ---------------------------------------------------------------------------
  group('FuelCardService', () {
    late FuelCardService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = FuelCardService();
    });

    test('load returns empty list when nothing is persisted', () async {
      final cards = await service.load();
      expect(cards, isEmpty);
    });

    test('save and load round-trips a list of cards', () async {
      const card = FuelCard(
        id: 's1',
        type: FuelCardType.wex,
        lastFour: '1111',
        cardholderName: 'Test Driver',
        expiryMonth: 5,
        expiryYear: 2031,
      );
      await service.save([card]);
      final loaded = await service.load();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, 's1');
      expect(loaded.first.type, FuelCardType.wex);
    });

    test('addCard appends a new card', () async {
      const c1 = FuelCard(
        id: 'a1',
        type: FuelCardType.efs,
        lastFour: '0001',
        cardholderName: 'A',
        expiryMonth: 1,
        expiryYear: 2030,
      );
      const c2 = FuelCard(
        id: 'a2',
        type: FuelCardType.comdata,
        lastFour: '0002',
        cardholderName: 'B',
        expiryMonth: 2,
        expiryYear: 2030,
      );
      await service.addCard(c1);
      final after = await service.addCard(c2);
      expect(after, hasLength(2));
    });

    test('addCard replaces a card with the same id', () async {
      const original = FuelCard(
        id: 'dup',
        type: FuelCardType.efs,
        lastFour: '0001',
        cardholderName: 'Old Name',
        expiryMonth: 1,
        expiryYear: 2030,
      );
      const updated = FuelCard(
        id: 'dup',
        type: FuelCardType.efs,
        lastFour: '0001',
        cardholderName: 'New Name',
        expiryMonth: 1,
        expiryYear: 2030,
      );
      await service.addCard(original);
      final after = await service.addCard(updated);
      expect(after, hasLength(1));
      expect(after.first.cardholderName, 'New Name');
    });

    test('removeCard removes only the matching card', () async {
      const c1 = FuelCard(
        id: 'r1',
        type: FuelCardType.efs,
        lastFour: '1111',
        cardholderName: 'A',
        expiryMonth: 1,
        expiryYear: 2030,
      );
      const c2 = FuelCard(
        id: 'r2',
        type: FuelCardType.comdata,
        lastFour: '2222',
        cardholderName: 'B',
        expiryMonth: 2,
        expiryYear: 2030,
      );
      await service.save([c1, c2]);
      final after = await service.removeCard('r1');
      expect(after, hasLength(1));
      expect(after.first.id, 'r2');
    });

    test('removeCard with unknown id leaves list unchanged', () async {
      const c1 = FuelCard(
        id: 'keep',
        type: FuelCardType.loyalty,
        lastFour: '9999',
        cardholderName: 'K',
        expiryMonth: 12,
        expiryYear: 2035,
      );
      await service.save([c1]);
      final after = await service.removeCard('no-such-id');
      expect(after, hasLength(1));
    });

    test('clear removes all cards from storage', () async {
      const card = FuelCard(
        id: 'cl1',
        type: FuelCardType.wex,
        lastFour: '3333',
        cardholderName: 'C',
        expiryMonth: 3,
        expiryYear: 2030,
      );
      await service.save([card]);
      await service.clear();
      final loaded = await service.load();
      expect(loaded, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // FuelPromotion – construction & helpers
  // ---------------------------------------------------------------------------
  group('FuelPromotion', () {
    test('isActive returns true when expiresAt is null', () {
      const p = FuelPromotion(
        id: 'p1',
        title: 'Free Promo',
        description: 'No expiry',
        discountCentsPerGallon: 5,
      );
      expect(p.isActive(), isTrue);
    });

    test('isActive returns true before expiresAt', () {
      final p = FuelPromotion(
        id: 'p2',
        title: 'Summer Sale',
        description: 'Summer promo',
        discountCentsPerGallon: 10,
        expiresAt: DateTime(2099, 12, 31),
      );
      expect(p.isActive(now: DateTime(2024, 1, 1)), isTrue);
    });

    test('isActive returns false after expiresAt', () {
      final p = FuelPromotion(
        id: 'p3',
        title: 'Expired',
        description: 'Old promo',
        discountCentsPerGallon: 3,
        expiresAt: DateTime(2020, 1, 1),
      );
      expect(p.isActive(now: DateTime(2024, 6, 1)), isFalse);
    });

    test('isApplicableToCard returns true for matching card type', () {
      final p = FuelPromotion(
        id: 'p4',
        title: 'EFS deal',
        description: 'For EFS holders',
        discountCentsPerGallon: 8,
        applicableCardTypes: [FuelCardType.efs],
      );
      expect(p.isApplicableToCard(FuelCardType.efs), isTrue);
      expect(p.isApplicableToCard(FuelCardType.wex), isFalse);
    });

    test('isApplicableToCard returns true for any card when list is empty', () {
      const p = FuelPromotion(
        id: 'p5',
        title: 'Universal',
        description: 'For everyone',
        discountCentsPerGallon: 2,
      );
      for (final t in FuelCardType.values) {
        expect(p.isApplicableToCard(t), isTrue);
      }
    });

    test('discountCentsPerGallon can be zero', () {
      const p = FuelPromotion(
        id: 'p6',
        title: 'Free coffee',
        description: 'Non-monetary benefit',
        discountCentsPerGallon: 0,
      );
      expect(p.discountCentsPerGallon, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // FuelPromotion – JSON serialization
  // ---------------------------------------------------------------------------
  group('FuelPromotion JSON', () {
    test('round-trips a simple promotion without optional fields', () {
      const p = FuelPromotion(
        id: 'j1',
        title: 'Test Promo',
        description: 'A test',
        discountCentsPerGallon: 7,
      );
      final restored = FuelPromotion.fromJson(p.toJson());
      expect(restored.id, p.id);
      expect(restored.title, p.title);
      expect(restored.discountCentsPerGallon, 7);
      expect(restored.expiresAt, isNull);
      expect(restored.applicableCardTypes, isEmpty);
      expect(restored.participatingBrands, isEmpty);
    });

    test('round-trips a promotion with all optional fields', () {
      final p = FuelPromotion(
        id: 'j2',
        title: 'Full Promo',
        description: 'All fields',
        discountCentsPerGallon: 15,
        expiresAt: DateTime(2030, 6, 30),
        applicableCardTypes: [FuelCardType.efs, FuelCardType.wex],
        participatingBrands: ['Pilot', "Love's"],
      );
      final restored = FuelPromotion.fromJson(p.toJson());
      expect(restored.expiresAt, DateTime(2030, 6, 30));
      expect(
        restored.applicableCardTypes,
        containsAll([FuelCardType.efs, FuelCardType.wex]),
      );
      expect(restored.participatingBrands, containsAll(['Pilot', "Love's"]));
    });
  });

  // ---------------------------------------------------------------------------
  // FuelPromotionService – filtering
  // ---------------------------------------------------------------------------
  group('FuelPromotionService', () {
    final now = DateTime(2025, 6, 1);

    final activePromo = FuelPromotion(
      id: 'active',
      title: 'Active Promo',
      description: 'Still running',
      discountCentsPerGallon: 5,
      expiresAt: DateTime(2099, 12, 31),
      applicableCardTypes: [FuelCardType.efs],
      participatingBrands: ['Pilot'],
    );

    final expiredPromo = FuelPromotion(
      id: 'expired',
      title: 'Expired Promo',
      description: 'Ended',
      discountCentsPerGallon: 3,
      expiresAt: DateTime(2020, 1, 1),
      applicableCardTypes: [FuelCardType.efs],
    );

    final universalPromo = FuelPromotion(
      id: 'universal',
      title: 'Universal Promo',
      description: 'For all',
      discountCentsPerGallon: 2,
    );

    final efsCard = const FuelCard(
      id: 'e1',
      type: FuelCardType.efs,
      lastFour: '0001',
      cardholderName: 'Driver',
      expiryMonth: 12,
      expiryYear: 2099,
    );

    final wexCard = const FuelCard(
      id: 'w1',
      type: FuelCardType.wex,
      lastFour: '0002',
      cardholderName: 'Driver',
      expiryMonth: 12,
      expiryYear: 2099,
    );

    test('activePromotions filters out expired promotions', () {
      final result = FuelPromotionService.activePromotions(
        [activePromo, expiredPromo, universalPromo],
        now: now,
      );
      expect(result.map((p) => p.id), containsAll(['active', 'universal']));
      expect(result.map((p) => p.id), isNot(contains('expired')));
    });

    test('promotionsForCards includes promos matching enrolled card types', () {
      final result = FuelPromotionService.promotionsForCards(
        [activePromo, expiredPromo, universalPromo],
        [efsCard],
        now: now,
      );
      // activePromo (efs) + universalPromo (empty types) — expiredPromo excluded
      expect(result.map((p) => p.id), containsAll(['active', 'universal']));
      expect(result.map((p) => p.id), isNot(contains('expired')));
    });

    test('promotionsForCards excludes promos not matching any enrolled card', () {
      final result = FuelPromotionService.promotionsForCards(
        [activePromo],  // efs only
        [wexCard],      // driver has WEX, not EFS
        now: now,
      );
      expect(result, isEmpty);
    });

    test('universalPromo returned even with no matching specific card', () {
      final result = FuelPromotionService.promotionsForCards(
        [universalPromo],
        [wexCard],
        now: now,
      );
      expect(result, hasLength(1));
      expect(result.first.id, 'universal');
    });

    test('promotionsAtBrand filters by brand name', () {
      final result = FuelPromotionService.promotionsAtBrand(
        [activePromo, universalPromo],
        [efsCard],
        'Pilot',
        now: now,
      );
      // activePromo is Pilot-specific; universalPromo has empty brands → both
      expect(result.map((p) => p.id), containsAll(['active', 'universal']));
    });

    test('promotionsAtBrand excludes promos at a different brand', () {
      final result = FuelPromotionService.promotionsAtBrand(
        [activePromo],  // Pilot only
        [efsCard],
        "Love's",       // driver is at Love's
        now: now,
      );
      expect(result, isEmpty);
    });

    test('totalDiscountCentsPerGallon sums all discounts', () {
      final promos = [
        const FuelPromotion(
          id: 'd1',
          title: '',
          description: '',
          discountCentsPerGallon: 5,
        ),
        const FuelPromotion(
          id: 'd2',
          title: '',
          description: '',
          discountCentsPerGallon: 3,
        ),
      ];
      expect(FuelPromotionService.totalDiscountCentsPerGallon(promos), 8);
    });

    test('totalDiscountCentsPerGallon returns 0 for empty list', () {
      expect(FuelPromotionService.totalDiscountCentsPerGallon([]), 0);
    });
  });
}
