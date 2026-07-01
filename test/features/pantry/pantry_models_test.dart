import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. MealReaction.fromMap / copyWith
  // ═══════════════════════════════════════════════════════════════════════════
  group('MealReaction.fromMap', () {
    test('parses all fields', () {
      final r = MealReaction.fromMap({
        'id': 'rxn1',
        'member_name': 'Priya',
        'reaction_emoji': '😋',
        'comment': 'Loved it!',
        'reply_to': 'Mom',
      });
      expect(r.id, 'rxn1');
      expect(r.memberName, 'Priya');
      expect(r.reactionEmoji, '😋');
      expect(r.comment, 'Loved it!');
      expect(r.replyTo, 'Mom');
    });

    test('optional fields default to null', () {
      final r = MealReaction.fromMap({
        'member_name': 'Arjun',
        'reaction_emoji': '👍',
      });
      expect(r.id, isNull);
      expect(r.comment, isNull);
      expect(r.replyTo, isNull);
    });

    test('all reaction emojis parse without error', () {
      for (final emoji in ['👍', '😋', '🤔', '❌', '🔄']) {
        final r = MealReaction.fromMap({
          'member_name': 'Me',
          'reaction_emoji': emoji,
        });
        expect(r.reactionEmoji, emoji);
      }
    });
  });

  group('MealReaction.copyWith', () {
    final base = MealReaction(
      id: 'r1',
      memberName: 'Priya',
      reactionEmoji: '👍',
      comment: 'Nice',
      replyTo: 'Mom',
    );

    test('no-op copyWith returns same field values', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.memberName, base.memberName);
      expect(copy.reactionEmoji, base.reactionEmoji);
      expect(copy.comment, base.comment);
      expect(copy.replyTo, base.replyTo);
    });

    test('overrides individual fields', () {
      final copy = base.copyWith(reactionEmoji: '😋', comment: 'Amazing!');
      expect(copy.reactionEmoji, '😋');
      expect(copy.comment, 'Amazing!');
      expect(copy.memberName, 'Priya'); // unchanged
    });

    test('can set comment to null via copyWith', () {
      final copy = base.copyWith(comment: null);
      expect(copy.comment, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. MealEntry.fromMap
  // ═══════════════════════════════════════════════════════════════════════════
  group('MealEntry.fromMap', () {
    Map<String, dynamic> baseRow() => {
      'id': 'm1',
      'wallet_id': 'personal',
      'name': 'Idli Sambar',
      'emoji': '🫙',
      'meal_time': 'breakfast',
      'date': '2025-08-10',
      'meal_status': 'cooked',
      'servings_count': 4,
      'note': 'Extra sambar',
      'recipe_ids': ['r1', 'r2'],
      'ingredients': ['Rice batter', 'Sambar'],
      'meal_reactions': [
        {'member_name': 'Priya', 'reaction_emoji': '😋'},
      ],
    };

    test('parses all fields', () {
      final e = MealEntry.fromMap(baseRow());
      expect(e.id, 'm1');
      expect(e.walletId, 'personal');
      expect(e.name, 'Idli Sambar');
      expect(e.emoji, '🫙');
      expect(e.mealTime, MealTime.breakfast);
      expect(e.date, DateTime(2025, 8, 10));
      expect(e.mealStatus, MealStatus.cooked);
      expect(e.servingsCount, 4);
      expect(e.note, 'Extra sambar');
      expect(e.recipeIds, ['r1', 'r2']);
      expect(e.ingredients, ['Rice batter', 'Sambar']);
      expect(e.reactions.length, 1);
      expect(e.reactions[0].memberName, 'Priya');
    });

    test('emoji defaults to 🍽️ when absent', () {
      final row = baseRow()..remove('emoji');
      expect(MealEntry.fromMap(row).emoji, '🍽️');
    });

    test('mealStatus defaults to planned when absent', () {
      final row = baseRow()..remove('meal_status');
      expect(MealEntry.fromMap(row).mealStatus, MealStatus.planned);
    });

    test('unknown mealStatus string defaults to planned', () {
      final row = baseRow()..[' meal_status'] = 'archived';
      row['meal_status'] = 'archived';
      expect(MealEntry.fromMap(row).mealStatus, MealStatus.planned);
    });

    test('servingsCount defaults to 1 when absent', () {
      final row = baseRow()..remove('servings_count');
      expect(MealEntry.fromMap(row).servingsCount, 1);
    });

    test('unknown mealTime string defaults to lunch', () {
      final row = baseRow()..['meal_time'] = 'brunch';
      expect(MealEntry.fromMap(row).mealTime, MealTime.lunch);
    });

    test('all MealTime values parse correctly', () {
      for (final mt in MealTime.values) {
        final row = baseRow()..['meal_time'] = mt.name;
        expect(MealEntry.fromMap(row).mealTime, mt, reason: mt.name);
      }
    });

    test('all MealStatus values parse correctly', () {
      for (final ms in MealStatus.values) {
        final row = baseRow()..['meal_status'] = ms.name;
        expect(MealEntry.fromMap(row).mealStatus, ms, reason: ms.name);
      }
    });

    test('note is null when absent', () {
      final row = baseRow()..remove('note');
      expect(MealEntry.fromMap(row).note, isNull);
    });

    // recipe_ids vs legacy recipe_id fallback
    test('recipe_ids array takes priority over recipe_id', () {
      final row = baseRow()
        ..['recipe_ids'] = ['new1', 'new2']
        ..['recipe_id'] = 'old1';
      final e = MealEntry.fromMap(row);
      expect(e.recipeIds, ['new1', 'new2']);
    });

    test('falls back to legacy recipe_id when recipe_ids absent', () {
      final row = baseRow()
        ..remove('recipe_ids')
        ..['recipe_id'] = 'legacy_r1';
      final e = MealEntry.fromMap(row);
      expect(e.recipeIds, ['legacy_r1']);
    });

    test('no recipe_ids and no recipe_id → empty list', () {
      final row = baseRow()
        ..remove('recipe_ids')
        ..remove('recipe_id');
      expect(MealEntry.fromMap(row).recipeIds, isEmpty);
    });

    // Nested meal_reactions
    test('meal_reactions parsed into reaction objects', () {
      final row = baseRow()
        ..['meal_reactions'] = [
          {'member_name': 'Arjun', 'reaction_emoji': '👍', 'comment': 'Yum'},
          {'member_name': 'Mom', 'reaction_emoji': '😋'},
        ];
      final e = MealEntry.fromMap(row);
      expect(e.reactions.length, 2);
      expect(e.reactions[0].memberName, 'Arjun');
      expect(e.reactions[0].comment, 'Yum');
      expect(e.reactions[1].replyTo, isNull);
    });

    test('absent meal_reactions → empty list', () {
      final row = baseRow()..remove('meal_reactions');
      expect(MealEntry.fromMap(row).reactions, isEmpty);
    });

    test('non-list meal_reactions → empty list (type guard)', () {
      final row = baseRow()..['meal_reactions'] = null;
      expect(MealEntry.fromMap(row).reactions, isEmpty);
    });

    test('ingredients absent → empty list via getter', () {
      final row = baseRow()..remove('ingredients');
      expect(MealEntry.fromMap(row).ingredients, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. MealEntry.copyWith and computed getters
  // ═══════════════════════════════════════════════════════════════════════════
  group('MealEntry.copyWith', () {
    final base = MealEntry(
      id: 'm1',
      walletId: 'personal',
      name: 'Dal Rice',
      mealTime: MealTime.lunch,
      date: DateTime(2025, 8, 1),
      emoji: '🍚',
      mealStatus: MealStatus.planned,
      servingsCount: 2,
      recipeIds: ['r1'],
      note: 'Less salt',
      ingredients: ['Dal', 'Rice'],
    );

    test('id and walletId are immutable', () {
      final copy = base.copyWith(name: 'New Name');
      expect(copy.id, 'm1');
      expect(copy.walletId, 'personal');
    });

    test('overrides name', () {
      expect(base.copyWith(name: 'Biryani').name, 'Biryani');
    });

    test('overrides mealTime', () {
      expect(base.copyWith(mealTime: MealTime.dinner).mealTime, MealTime.dinner);
    });

    test('overrides mealStatus', () {
      expect(base.copyWith(mealStatus: MealStatus.cooked).mealStatus, MealStatus.cooked);
    });

    test('overrides servingsCount', () {
      expect(base.copyWith(servingsCount: 6).servingsCount, 6);
    });

    test('overrides note', () {
      expect(base.copyWith(note: 'Extra spicy').note, 'Extra spicy');
    });

    test('overrides recipeIds', () {
      expect(base.copyWith(recipeIds: ['r2', 'r3']).recipeIds, ['r2', 'r3']);
    });

    test('no-op preserves all fields', () {
      final copy = base.copyWith();
      expect(copy.name, base.name);
      expect(copy.mealTime, base.mealTime);
      expect(copy.emoji, base.emoji);
      expect(copy.note, base.note);
    });
  });

  group('MealEntry — computed getters', () {
    test('recipeId returns first recipeId', () {
      final e = MealEntry(
        id: 'm1', walletId: 'w', name: 'X',
        mealTime: MealTime.lunch, date: DateTime.now(),
        recipeIds: ['r1', 'r2'],
      );
      expect(e.recipeId, 'r1');
    });

    test('recipeId is null when recipeIds is empty', () {
      final e = MealEntry(
        id: 'm1', walletId: 'w', name: 'X',
        mealTime: MealTime.lunch, date: DateTime.now(),
      );
      expect(e.recipeId, isNull);
    });

    test('ingredients getter returns empty list when null', () {
      final e = MealEntry(
        id: 'm1', walletId: 'w', name: 'X',
        mealTime: MealTime.lunch, date: DateTime(2025, 1, 1),
      );
      expect(e.ingredients, isEmpty);
    });

    test('reactions getter returns empty list when null', () {
      final e = MealEntry(
        id: 'm1', walletId: 'w', name: 'X',
        mealTime: MealTime.lunch, date: DateTime(2025, 1, 1),
      );
      expect(e.reactions, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. RecipeModel.fromMap
  // ═══════════════════════════════════════════════════════════════════════════
  group('RecipeModel.fromMap', () {
    Map<String, dynamic> baseRow() => {
      'id': 'r1',
      'wallet_id': 'personal',
      'name': 'Butter Chicken',
      'emoji': '🍗',
      'cuisine': 'indian',
      'suitable_for': ['lunch', 'dinner'],
      'ingredients': ['Chicken 500g', 'Butter 3tbsp'],
      'social_link': 'https://instagram.com/reel/x',
      'note': 'Marinate overnight',
      'cook_time_min': 40,
      'is_favourite': true,
      'library_recipe_id': 'master_r1',
    };

    test('parses all fields', () {
      final r = RecipeModel.fromMap(baseRow());
      expect(r.id, 'r1');
      expect(r.walletId, 'personal');
      expect(r.name, 'Butter Chicken');
      expect(r.emoji, '🍗');
      expect(r.cuisine, CuisineType.indian);
      expect(r.suitableFor, [MealTime.lunch, MealTime.dinner]);
      expect(r.ingredients, ['Chicken 500g', 'Butter 3tbsp']);
      expect(r.socialLink, 'https://instagram.com/reel/x');
      expect(r.note, 'Marinate overnight');
      expect(r.cookTimeMin, 40);
      expect(r.isFavourite, true);
      expect(r.libraryRecipeId, 'master_r1');
    });

    test('emoji defaults to 🍽️ when absent', () {
      final row = baseRow()..remove('emoji');
      expect(RecipeModel.fromMap(row).emoji, '🍽️');
    });

    test('isFavourite defaults to false when absent', () {
      final row = baseRow()..remove('is_favourite');
      expect(RecipeModel.fromMap(row).isFavourite, false);
    });

    test('unknown cuisine string defaults to indian', () {
      final row = baseRow()..['cuisine'] = 'peruvian';
      expect(RecipeModel.fromMap(row).cuisine, CuisineType.indian);
    });

    test('all CuisineType values parse correctly', () {
      for (final ct in CuisineType.values) {
        final row = baseRow()..['cuisine'] = ct.name;
        expect(RecipeModel.fromMap(row).cuisine, ct, reason: ct.name);
      }
    });

    test('suitable_for maps strings to MealTime enums', () {
      final row = baseRow()..['suitable_for'] = ['breakfast', 'snack'];
      final r = RecipeModel.fromMap(row);
      expect(r.suitableFor, [MealTime.breakfast, MealTime.snack]);
    });

    test('unknown suitable_for string defaults to lunch', () {
      final row = baseRow()..['suitable_for'] = ['brunch'];
      final r = RecipeModel.fromMap(row);
      expect(r.suitableFor, [MealTime.lunch]);
    });

    test('empty suitable_for → empty list', () {
      final row = baseRow()..['suitable_for'] = <String>[];
      expect(RecipeModel.fromMap(row).suitableFor, isEmpty);
    });

    test('absent suitable_for → empty list', () {
      final row = baseRow()..remove('suitable_for');
      expect(RecipeModel.fromMap(row).suitableFor, isEmpty);
    });

    test('absent ingredients → empty list', () {
      final row = baseRow()..remove('ingredients');
      expect(RecipeModel.fromMap(row).ingredients, isEmpty);
    });

    test('optional fields are null when absent', () {
      final row = baseRow()
        ..remove('social_link')
        ..remove('note')
        ..remove('cook_time_min')
        ..remove('library_recipe_id');
      final r = RecipeModel.fromMap(row);
      expect(r.socialLink, isNull);
      expect(r.note, isNull);
      expect(r.cookTimeMin, isNull);
      expect(r.libraryRecipeId, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. MasterRecipe.fromMap — ingredient formatting
  // ═══════════════════════════════════════════════════════════════════════════
  group('MasterRecipe.fromMap — ingredient formatting', () {
    MasterRecipe makeRecipe(List<Map<String, dynamic>> ings) =>
        MasterRecipe.fromMap({
          'id': 'mr1',
          'name': 'Test',
          'emoji': '🍽️',
          'cuisine': 'Indian',
          'meal_types': <String>[],
          'ingredients': ings,
        });

    test('formats ingredient as "Name (qty unit)"', () {
      final r = makeRecipe([
        {'name': 'Chicken', 'qty': 500.0, 'unit': 'g'},
      ]);
      expect(r.ingredients[0], 'Chicken (500 g)');
    });

    test('integer qty rendered without decimal (2.0 → "2")', () {
      final r = makeRecipe([
        {'name': 'Butter', 'qty': 3.0, 'unit': 'tbsp'},
      ]);
      expect(r.ingredients[0], 'Butter (3 tbsp)');
    });

    test('fractional qty rendered with decimal (1.5 → "1.5")', () {
      final r = makeRecipe([
        {'name': 'Oil', 'qty': 1.5, 'unit': 'cup'},
      ]);
      expect(r.ingredients[0], 'Oil (1.5 cup)');
    });

    test('null qty → empty string in output', () {
      final r = makeRecipe([
        {'name': 'Salt', 'qty': null, 'unit': 'pinch'},
      ]);
      expect(r.ingredients[0], 'Salt ( pinch)');
    });

    test('null name → empty string in output', () {
      final r = makeRecipe([
        {'name': null, 'qty': 2.0, 'unit': 'cups'},
      ]);
      expect(r.ingredients[0], contains('2 cups'));
    });

    test('multiple ingredients all formatted', () {
      final r = makeRecipe([
        {'name': 'Tomatoes', 'qty': 4.0, 'unit': 'pcs'},
        {'name': 'Cream', 'qty': 0.5, 'unit': 'cup'},
      ]);
      expect(r.ingredients.length, 2);
      expect(r.ingredients[0], 'Tomatoes (4 pcs)');
      expect(r.ingredients[1], 'Cream (0.5 cup)');
    });

    test('absent ingredients → empty list', () {
      final r = MasterRecipe.fromMap({
        'id': 'mr1', 'name': 'X', 'emoji': '🍽️',
        'cuisine': 'Indian', 'meal_types': <String>[],
      });
      expect(r.ingredients, isEmpty);
    });

    test('parses optional fields', () {
      final r = MasterRecipe.fromMap({
        'id': 'mr1',
        'name': 'Biryani',
        'emoji': '🍛',
        'cuisine': 'Indian',
        'meal_types': ['lunch', 'dinner'],
        'ingredients': <Map>[],
        'cook_time_min': 45,
        'prep_time_min': 20,
        'servings': 4,
        'calories': 650,
        'youtube_search': 'biryani recipe',
        'tags': ['rice', 'spicy'],
      });
      expect(r.cookTimeMin, 45);
      expect(r.prepTimeMin, 20);
      expect(r.servings, 4);
      expect(r.calories, 650);
      expect(r.youtubeSearch, 'biryani recipe');
      expect(r.tags, ['rice', 'spicy']);
    });

    test('absent optional fields default to null / empty', () {
      final r = MasterRecipe.fromMap({
        'id': 'mr1', 'name': 'X', 'emoji': '🍽️',
        'cuisine': 'Indian', 'meal_types': <String>[],
      });
      expect(r.cookTimeMin, isNull);
      expect(r.prepTimeMin, isNull);
      expect(r.servings, isNull);
      expect(r.calories, isNull);
      expect(r.youtubeSearch, isNull);
      expect(r.tags, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. MasterRecipe.toRecipeModel
  // ═══════════════════════════════════════════════════════════════════════════
  group('MasterRecipe.toRecipeModel — cuisine mapping', () {
    RecipeModel convert(String cuisine, {List<String> mealTypes = const []}) =>
        MasterRecipe(
          id: 'mr1',
          name: 'Dish',
          emoji: '🍽️',
          cuisine: cuisine,
          mealTypes: mealTypes,
          ingredients: [],
        ).toRecipeModel();

    test('Indian → CuisineType.indian', () {
      expect(convert('Indian').cuisine, CuisineType.indian);
    });

    test('Chinese → CuisineType.chinese', () {
      expect(convert('Chinese').cuisine, CuisineType.chinese);
    });

    test('Indo-Chinese → CuisineType.chinese', () {
      expect(convert('Indo-Chinese').cuisine, CuisineType.chinese);
    });

    test('Italian → CuisineType.italian', () {
      expect(convert('Italian').cuisine, CuisineType.italian);
    });

    test('Continental → CuisineType.continental', () {
      expect(convert('Continental').cuisine, CuisineType.continental);
    });

    test('South Indian → CuisineType.indian', () {
      expect(convert('South Indian').cuisine, CuisineType.indian);
    });

    test('North Indian → CuisineType.indian', () {
      expect(convert('North Indian').cuisine, CuisineType.indian);
    });

    test('Street food → CuisineType.indian', () {
      expect(convert('Street Food').cuisine, CuisineType.indian);
    });

    test('Dessert → CuisineType.indian', () {
      expect(convert('Dessert').cuisine, CuisineType.indian);
    });

    test('unknown cuisine → CuisineType.indian (default)', () {
      expect(convert('Peruvian').cuisine, CuisineType.indian);
    });
  });

  group('MasterRecipe.toRecipeModel — mealType mapping', () {
    RecipeModel convert(List<String> mealTypes) =>
        MasterRecipe(
          id: 'mr1',
          name: 'Dish',
          emoji: '🍽️',
          cuisine: 'Indian',
          mealTypes: mealTypes,
          ingredients: [],
        ).toRecipeModel();

    test('"breakfast" → MealTime.breakfast', () {
      expect(convert(['breakfast']).suitableFor, [MealTime.breakfast]);
    });

    test('"lunch" → MealTime.lunch', () {
      expect(convert(['lunch']).suitableFor, [MealTime.lunch]);
    });

    test('"dinner" → MealTime.dinner', () {
      expect(convert(['dinner']).suitableFor, [MealTime.dinner]);
    });

    test('"snacks" → MealTime.snack', () {
      expect(convert(['snacks']).suitableFor, [MealTime.snack]);
    });

    test('"beverage" is filtered out (no MealTime mapping)', () {
      expect(convert(['beverage']).suitableFor, isEmpty);
    });

    test('"dessert" is filtered out', () {
      expect(convert(['dessert']).suitableFor, isEmpty);
    });

    test('multiple valid types mapped correctly', () {
      expect(
        convert(['breakfast', 'lunch', 'dinner']).suitableFor,
        [MealTime.breakfast, MealTime.lunch, MealTime.dinner],
      );
    });

    test('empty mealTypes → suitableFor defaults to [MealTime.lunch]', () {
      expect(convert([]).suitableFor, [MealTime.lunch]);
    });

    test('all-filtered types → suitableFor defaults to [MealTime.lunch]', () {
      // beverage and dessert are both filtered → empty → defaults to lunch
      expect(convert(['beverage', 'dessert']).suitableFor, [MealTime.lunch]);
    });

    test('libraryRecipeId is set to master recipe id', () {
      final recipe = MasterRecipe(
        id: 'master_42',
        name: 'Dish',
        emoji: '🍽️',
        cuisine: 'Indian',
        mealTypes: [],
        ingredients: [],
      ).toRecipeModel();
      expect(recipe.libraryRecipeId, 'master_42');
    });

    test('name and emoji carried over', () {
      final recipe = MasterRecipe(
        id: 'mr1',
        name: 'Masala Dosa',
        emoji: '🫓',
        cuisine: 'Indian',
        mealTypes: ['breakfast'],
        ingredients: [],
      ).toRecipeModel();
      expect(recipe.name, 'Masala Dosa');
      expect(recipe.emoji, '🫓');
    });

    test('cookTimeMin carried over', () {
      final recipe = MasterRecipe(
        id: 'mr1',
        name: 'Dish',
        emoji: '🍽️',
        cuisine: 'Indian',
        mealTypes: [],
        ingredients: [],
        cookTimeMin: 30,
      ).toRecipeModel();
      expect(recipe.cookTimeMin, 30);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. GroceryItem.fromMap (pantry_models.dart version)
  // ═══════════════════════════════════════════════════════════════════════════
  group('GroceryItem.fromMap', () {
    Map<String, dynamic> baseRow() => {
      'id': 'g1',
      'wallet_id': 'personal',
      'name': 'Tomatoes',
      'category': 'vegetables',
      'quantity': 0.5,
      'unit': 'kg',
      'in_stock': true,
      'to_buy': false,
      'is_grocery': true,
      'expiry_date': '2025-08-15',
      'note': 'Fresh only',
      'last_updated': '2025-08-01T10:00:00.000Z',
    };

    test('parses all fields', () {
      final g = GroceryItem.fromMap(baseRow());
      expect(g.id, 'g1');
      expect(g.walletId, 'personal');
      expect(g.name, 'Tomatoes');
      expect(g.category, GroceryCategory.vegetables);
      expect(g.quantity, 0.5);
      expect(g.unit, 'kg');
      expect(g.inStock, true);
      expect(g.toBuy, false);
      expect(g.isGrocery, true);
      expect(g.expiryDate, DateTime(2025, 8, 15));
      expect(g.note, 'Fresh only');
    });

    test('quantity as int is cast to double', () {
      final row = baseRow()..['quantity'] = 5; // int
      expect(GroceryItem.fromMap(row).quantity, 5.0);
    });

    test('inStock defaults to true when absent', () {
      final row = baseRow()..remove('in_stock');
      expect(GroceryItem.fromMap(row).inStock, true);
    });

    test('toBuy defaults to false when absent', () {
      final row = baseRow()..remove('to_buy');
      expect(GroceryItem.fromMap(row).toBuy, false);
    });

    test('isGrocery defaults to true when absent', () {
      final row = baseRow()..remove('is_grocery');
      expect(GroceryItem.fromMap(row).isGrocery, true);
    });

    test('expiryDate is null when absent', () {
      final row = baseRow()..remove('expiry_date');
      expect(GroceryItem.fromMap(row).expiryDate, isNull);
    });

    test('note is null when absent', () {
      final row = baseRow()..remove('note');
      expect(GroceryItem.fromMap(row).note, isNull);
    });

    test('unknown category string defaults to other', () {
      final row = baseRow()..['category'] = 'exotic';
      expect(GroceryItem.fromMap(row).category, GroceryCategory.other);
    });

    test('all GroceryCategory values parse correctly', () {
      for (final cat in GroceryCategory.values) {
        final row = baseRow()..['category'] = cat.name;
        expect(GroceryItem.fromMap(row).category, cat, reason: cat.name);
      }
    });

    test('is_grocery=false marks item as quick-list (dashboard) item', () {
      final row = baseRow()..['is_grocery'] = false;
      expect(GroceryItem.fromMap(row).isGrocery, false);
    });

    test('lastUpdated falls back to now when absent', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final row = baseRow()..remove('last_updated');
      final g = GroceryItem.fromMap(row);
      expect(g.lastUpdated.isAfter(before), true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. MemberFoodPrefs.fromMap / copyWith
  // ═══════════════════════════════════════════════════════════════════════════
  group('MemberFoodPrefs.fromMap', () {
    test('parses all fields', () {
      final fp = MemberFoodPrefs.fromMap({
        'id': 'fp1',
        'member_id': 'dad',
        'member_name': 'Dad',
        'member_emoji': '👨',
        'wallet_id': 'f1',
        'allergies': ['Peanuts', 'Shellfish'],
        'likes': ['Rice', 'Sambar'],
        'dislikes': ['Spicy food'],
        'mandatory_foods': ['Curd Rice (dinner)'],
      });
      expect(fp.id, 'fp1');
      expect(fp.memberId, 'dad');
      expect(fp.memberName, 'Dad');
      expect(fp.memberEmoji, '👨');
      expect(fp.walletId, 'f1');
      expect(fp.allergies, ['Peanuts', 'Shellfish']);
      expect(fp.likes, ['Rice', 'Sambar']);
      expect(fp.dislikes, ['Spicy food']);
      expect(fp.mandatoryFoods, ['Curd Rice (dinner)']);
    });

    test('memberEmoji defaults to 👤 when absent', () {
      final fp = MemberFoodPrefs.fromMap({
        'id': 'fp1', 'member_id': 'x', 'member_name': 'X',
        'wallet_id': 'w1',
      });
      expect(fp.memberEmoji, '👤');
    });

    test('all list fields default to empty when absent', () {
      final fp = MemberFoodPrefs.fromMap({
        'id': 'fp1', 'member_id': 'x', 'member_name': 'X',
        'wallet_id': 'w1',
      });
      expect(fp.allergies, isEmpty);
      expect(fp.likes, isEmpty);
      expect(fp.dislikes, isEmpty);
      expect(fp.mandatoryFoods, isEmpty);
    });

    test('empty list values remain empty', () {
      final fp = MemberFoodPrefs.fromMap({
        'id': 'fp1', 'member_id': 'x', 'member_name': 'X',
        'wallet_id': 'w1',
        'allergies': <String>[],
        'likes': <String>[],
      });
      expect(fp.allergies, isEmpty);
      expect(fp.likes, isEmpty);
    });
  });

  group('MemberFoodPrefs.copyWith', () {
    final base = MemberFoodPrefs(
      id: 'fp1',
      memberId: 'me',
      memberName: 'Me',
      memberEmoji: '🧑',
      walletId: 'personal',
      allergies: ['Peanuts'],
      likes: ['Biryani'],
      dislikes: ['Bitter Gourd'],
      mandatoryFoods: ['Fruits'],
    );

    test('no-op preserves all fields', () {
      final copy = base.copyWith();
      expect(copy.allergies, base.allergies);
      expect(copy.likes, base.likes);
      expect(copy.dislikes, base.dislikes);
      expect(copy.mandatoryFoods, base.mandatoryFoods);
    });

    test('id/memberId/memberName/memberEmoji/walletId are immutable', () {
      final copy = base.copyWith(likes: ['Pizza']);
      expect(copy.id, 'fp1');
      expect(copy.memberId, 'me');
      expect(copy.memberName, 'Me');
      expect(copy.memberEmoji, '🧑');
      expect(copy.walletId, 'personal');
    });

    test('overrides allergies', () {
      final copy = base.copyWith(allergies: ['Milk', 'Eggs']);
      expect(copy.allergies, ['Milk', 'Eggs']);
    });

    test('overrides likes', () {
      final copy = base.copyWith(likes: ['Pizza', 'Pasta']);
      expect(copy.likes, ['Pizza', 'Pasta']);
    });

    test('overrides dislikes', () {
      final copy = base.copyWith(dislikes: []);
      expect(copy.dislikes, isEmpty);
    });

    test('overrides mandatoryFoods', () {
      final copy = base.copyWith(mandatoryFoods: ['Salad (lunch)']);
      expect(copy.mandatoryFoods, ['Salad (lunch)']);
    });

    test('copyWith produces independent list (mutation does not affect original)', () {
      final copy = base.copyWith();
      copy.likes.add('New Item');
      expect(base.likes, isNot(contains('New Item')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. Enum extensions
  // ═══════════════════════════════════════════════════════════════════════════
  group('MealTime extensions', () {
    test('all values have non-empty label, emoji, and color', () {
      for (final mt in MealTime.values) {
        expect(mt.label, isNotEmpty, reason: mt.name);
        expect(mt.emoji, isNotEmpty, reason: mt.name);
        expect(mt.color, isA<Color>());
      }
    });

    test('spot checks', () {
      expect(MealTime.breakfast.label, 'Breakfast');
      expect(MealTime.breakfast.emoji, '🌅');
      expect(MealTime.lunch.label, 'Lunch');
      expect(MealTime.snack.label, 'Snacks');
      expect(MealTime.dinner.label, 'Dinner');
      expect(MealTime.dinner.emoji, '🌙');
    });
  });

  group('MealStatus extensions', () {
    test('all values have non-empty label, emoji, and color', () {
      for (final ms in MealStatus.values) {
        expect(ms.label, isNotEmpty, reason: ms.name);
        expect(ms.emoji, isNotEmpty, reason: ms.name);
        expect(ms.color, isA<Color>());
      }
    });

    test('spot checks', () {
      expect(MealStatus.planned.label, 'Planned');
      expect(MealStatus.cooked.emoji, '🏠');
      expect(MealStatus.ordered.label, 'Ordered');
    });
  });

  group('GroceryCategory extensions', () {
    test('all values have non-empty label and emoji', () {
      for (final gc in GroceryCategory.values) {
        expect(gc.label, isNotEmpty, reason: gc.name);
        expect(gc.emoji, isNotEmpty, reason: gc.name);
      }
    });

    test('spot checks', () {
      expect(GroceryCategory.vegetables.emoji, '🥬');
      expect(GroceryCategory.dairy.label, 'Dairy');
      expect(GroceryCategory.other.emoji, '📦');
    });
  });

  group('CuisineType extensions', () {
    test('all values have non-empty label and emoji', () {
      for (final ct in CuisineType.values) {
        expect(ct.label, isNotEmpty, reason: ct.name);
        expect(ct.emoji, isNotEmpty, reason: ct.name);
      }
    });

    test('spot checks', () {
      expect(CuisineType.indian.emoji, '🇮🇳');
      expect(CuisineType.italian.label, 'Italian');
      expect(CuisineType.mediterranean.emoji, '🫒');
    });
  });
}
