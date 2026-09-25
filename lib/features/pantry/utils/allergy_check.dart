import 'package:wai_life_assistant/core/utils/ingredient_normalizer.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';

/// One family member's allergy that a meal appears to contain.
class AllergyHit {
  final String memberName;
  final String memberEmoji;
  final String allergy;
  const AllergyHit(this.memberName, this.memberEmoji, this.allergy);
}

final _word = RegExp(r'[a-z0-9஀-௿]+');
final _parenthetical = RegExp(r'\(.*?\)');

/// Normalized word sequence, space-padded so a phrase match can't start or
/// end mid-word ("nut" must not match inside "coconut").
String _phrase(String raw) {
  final words = _word
      .allMatches(raw.toLowerCase())
      .map((m) => normalizeIngredientName(m.group(0)!))
      .where((w) => w.isNotEmpty);
  return ' ${words.join(' ')} ';
}

/// Everything a meal is made of that an allergy could show up in: its name,
/// its own ingredients, and the name + ingredients of each linked recipe.
List<String> mealAllergyTexts(MealEntry meal, List<RecipeModel> recipes) {
  final linked = recipes.where((r) => meal.recipeIds.contains(r.id));
  return [
    meal.name,
    ...meal.ingredients,
    for (final r in linked) ...[r.name, ...r.ingredients],
  ];
}

/// Allergies from [prefs] found in [texts]. A term matches as a whole word
/// or phrase after the same normalization Pantry uses for ingredients
/// ("Peanuts" ↔ "peanut"), or when a whole ingredient resolves to the same
/// canonical name through the alias table ("Eggplant" ↔ "Brinjal").
/// A parenthetical note on the allergy ("Milk (lactose)") is ignored.
///
/// It's a text match, not a food database — "Nuts" won't flag "cashew".
List<AllergyHit> findAllergyHits(
  List<String> texts,
  List<MemberFoodPrefs> prefs,
) {
  final phrases = texts.map(_phrase).toList();
  final canonical = texts.map(canonicalIngredientName).toSet();
  final hits = <AllergyHit>[];
  for (final p in prefs) {
    for (final allergy in p.allergies) {
      final term = allergy.replaceAll(_parenthetical, '');
      final termPhrase = _phrase(term);
      if (termPhrase.trim().isEmpty) continue;
      if (phrases.any((s) => s.contains(termPhrase)) ||
          canonical.contains(canonicalIngredientName(term))) {
        hits.add(AllergyHit(p.memberName, p.memberEmoji, allergy));
      }
    }
  }
  return hits;
}

/// "Peanuts (Amma, Riya) · Milk (Appa)" — hits grouped by allergy.
String describeAllergyHits(List<AllergyHit> hits) {
  final byAllergy = <String, List<String>>{};
  for (final h in hits) {
    byAllergy.putIfAbsent(h.allergy, () => []).add(h.memberName);
  }
  return byAllergy.entries
      .map((e) => '${e.key} (${e.value.join(', ')})')
      .join(' · ');
}
