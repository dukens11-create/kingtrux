import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fuel_card.dart';

/// Persists enrolled [FuelCard]s to device storage via [SharedPreferences].
///
/// Security notes:
/// - Full card PANs are **never** stored; the service only persists the last
///   four digits ([FuelCard.lastFour]) together with non-sensitive metadata.
/// - Card data is stored under a single JSON blob key so it can be wiped
///   atomically (e.g. on account sign-out).
class FuelCardService {
  static const _key = 'fuel_enrolled_cards';

  /// Load the list of enrolled cards.
  ///
  /// Returns an empty list when nothing has been persisted yet or on any error.
  Future<List<FuelCard>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      return fuelCardsFromJson(raw);
    } catch (_) {
      return [];
    }
  }

  /// Persist [cards] to device storage, replacing any previously saved list.
  Future<void> save(List<FuelCard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, fuelCardsToJson(cards));
  }

  /// Add [card] to the persisted list and return the updated list.
  ///
  /// If a card with the same [FuelCard.id] already exists it is replaced.
  Future<List<FuelCard>> addCard(FuelCard card) async {
    final cards = await load();
    final updated = [
      ...cards.where((c) => c.id != card.id),
      card,
    ];
    await save(updated);
    return updated;
  }

  /// Remove the card identified by [cardId] from the persisted list.
  ///
  /// Returns the updated list.  If no card with [cardId] exists, the list is
  /// returned unchanged.
  Future<List<FuelCard>> removeCard(String cardId) async {
    final cards = await load();
    final updated = cards.where((c) => c.id != cardId).toList();
    await save(updated);
    return updated;
  }

  /// Remove all enrolled cards from device storage.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
