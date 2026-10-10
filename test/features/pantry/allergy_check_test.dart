import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/core/utils/ingredient_normalizer.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import 'package:wai_life_assistant/features/pantry/utils/allergy_check.dart';

MemberFoodPrefs prefs(String name, List<String> allergies) => MemberFoodPrefs(
      id: 'fp_$name',
      memberId: name,
      memberName: name,
      memberEmoji: '👤',
      walletId: 'w1',
      allergies: allergies,
    );

void main() {
  tearDown(() => setIngredientAliases(const {}));

  group('findAllergyHits', () {
    test('matches plural/singular and case', () {
      final hits = findAllergyHits(
        ['Peanut chutney'],
        [prefs('Amma', ['Peanuts'])],
      );
      expect(hits.single.memberName, 'Amma');
      expect(hits.single.allergy, 'Peanuts');
    });

    test('matches inside an ingredient with a quantity', () {
      final hits = findAllergyHits(
        ['Dosa', 'Milk (500 ml)'],
        [prefs('Appa', ['milk'])],
      );
      expect(hits, hasLength(1));
    });

    test('does not match part of another word', () {
      expect(
        findAllergyHits(['Coconut chutney'], [prefs('Riya', ['Nut'])]),
        isEmpty,
      );
    });

    test('multi-word allergy matches as a phrase only', () {
      final p = [prefs('Riya', ['Soy sauce'])];
      expect(findAllergyHits(['Fried rice', 'soy sauce'], p), hasLength(1));
      expect(findAllergyHits(['Soy milk', 'hot sauce'], p), isEmpty);
    });

    test('ignores a parenthetical note on the allergy', () {
      final hits = findAllergyHits(
        ['Paneer', 'milk'],
        [prefs('Appa', ['Milk (lactose)'])],
      );
      expect(hits, hasLength(1));
    });

    test('resolves ingredient aliases', () {
      setIngredientAliases({'eggplant': 'brinjal'});
      final hits = findAllergyHits(
        ['Curry', 'Brinjal'],
        [prefs('Amma', ['Eggplant'])],
      );
      expect(hits, hasLength(1));
    });

    test('reports every affected member', () {
      final hits = findAllergyHits(
        ['Egg curry'],
        [prefs('Amma', ['egg']), prefs('Riya', ['Eggs', 'fish'])],
      );
      expect(hits.map((h) => h.memberName), ['Amma', 'Riya']);
    });

    test('blank allergy never matches', () {
      expect(findAllergyHits(['Idli'], [prefs('Amma', ['  ', '()'])]), isEmpty);
    });
  });

  group('mealAllergyTexts', () {
    test('includes linked recipe name and ingredients only', () {
      final meal = MealEntry(
        id: 'm1',
        name: 'Lunch',
        mealTime: MealTime.lunch,
        date: DateTime(2026, 9, 25),
        walletId: 'w1',
        recipeIds: const ['r1'],
        ingredients: const ['rice'],
      );
      RecipeModel recipe(String id, String name, List<String> ing) =>
          RecipeModel(
            id: id,
            name: name,
            emoji: '🍲',
            cuisine: CuisineType.values.first,
            suitableFor: const [],
            ingredients: ing,
          );
      final texts = mealAllergyTexts(meal, [
        recipe('r1', 'Sambar', ['toor dal']),
        recipe('r2', 'Kheer', ['milk']),
      ]);
      expect(texts, ['Lunch', 'rice', 'Sambar', 'toor dal']);
    });
  });

  group('splitPrefItems', () {
    test('splits a comma list with a trailing "and"', () {
      expect(splitPrefItems('mutton, chicken and egg'), ['mutton', 'chicken', 'egg']);
      expect(splitPrefItems('Prawns; crab & lobster'), ['Prawns', 'crab', 'lobster']);
      expect(splitPrefItems('Milk, curd, and ghee'), ['Milk', 'curd', 'ghee']);
    });

    test('keeps a single dish with "and" whole', () {
      expect(splitPrefItems('Bread and butter'), ['Bread and butter']);
    });

    test('ignores commas inside brackets and empty pieces', () {
      expect(splitPrefItems('Milk (morning, evening)'), ['Milk (morning, evening)']);
      expect(splitPrefItems(' Egg , , '), ['Egg']);
    });
  });

  test('a saved combined entry still matches each item', () {
    final hits = findAllergyHits(
      ['Egg curry'],
      [prefs('Amma', ['Mutton, chicken and egg'])],
    );
    expect(hits.single.allergy, 'egg');
  });

  group('findPrefHits — likes / dislikes', () {
    final family = [
      MemberFoodPrefs(
        id: 'fp_appa', memberId: 'appa', memberName: 'Appa', memberEmoji: '👤',
        walletId: 'w1', dislikes: ['Brinjal'], likes: ['Dosa'],
      ),
      MemberFoodPrefs(
        id: 'fp_riya', memberId: 'riya', memberName: 'Riya', memberEmoji: '👤',
        walletId: 'w1', likes: ['Dosa'], allergies: ['Peanut'],
      ),
    ];

    test('matches dislikes only from the dislikes list', () {
      final hits = findPrefHits(['Brinjal curry', 'Dosa'], family, (p) => p.dislikes);
      expect(hits.map((h) => '${h.memberName}:${h.allergy}'), ['Appa:Brinjal']);
    });

    test('matches likes for every member who likes it', () {
      final hits = findPrefHits(['Masala Dosa'], family, (p) => p.likes);
      expect(describeAllergyHits(hits), 'Dosa (Appa, Riya)');
    });

    test('no likes/dislikes hit when nothing matches', () {
      expect(findPrefHits(['Idli'], family, (p) => p.likes), isEmpty);
      expect(findPrefHits(['Idli'], family, (p) => p.dislikes), isEmpty);
    });
  });

  test('describeAllergyHits groups members by allergy', () {
    final text = describeAllergyHits(const [
      AllergyHit('Amma', '👤', 'Peanuts'),
      AllergyHit('Riya', '👤', 'Peanuts'),
      AllergyHit('Appa', '👤', 'Milk'),
    ]);
    expect(text, 'Peanuts (Amma, Riya) · Milk (Appa)');
  });
}
