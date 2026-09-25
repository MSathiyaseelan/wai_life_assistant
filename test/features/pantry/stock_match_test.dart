import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/core/utils/ingredient_normalizer.dart';

void main() {
  group('stockCoversIngredient', () {
    test('exact and plural/singular', () {
      expect(stockCoversIngredient('tomato', 'tomatoes'), isTrue);
      expect(stockCoversIngredient('egg', 'egg'), isTrue);
    });

    test('never matches part of a word', () {
      expect(stockCoversIngredient('egg', 'eggplant'), isFalse);
      expect(stockCoversIngredient('salt', 'unsalted butter'), isFalse);
      expect(stockCoversIngredient('tea', 'steak'), isFalse);
    });

    test('plain qualifier still matches either way', () {
      expect(stockCoversIngredient('rice', 'basmati rice'), isTrue);
      expect(stockCoversIngredient('basmati rice', 'rice'), isTrue);
      expect(stockCoversIngredient('onion', 'red onions'), isTrue);
    });

    test('a product-form word makes it a different item', () {
      expect(stockCoversIngredient('rice', 'rice flour'), isFalse);
      expect(stockCoversIngredient('rice flour', 'rice'), isFalse);
      expect(stockCoversIngredient('coconut', 'coconut oil'), isFalse);
      expect(stockCoversIngredient('chilli', 'chilli powder'), isFalse);
      expect(stockCoversIngredient('curry', 'curry leaves'), isFalse);
    });

    test('same product in both still matches', () {
      expect(stockCoversIngredient('coconut oil', 'coconut oil'), isTrue);
      expect(stockCoversIngredient('rice flour', 'fine rice flour'), isTrue);
    });

    test('empty names never match', () {
      expect(stockCoversIngredient('', 'rice'), isFalse);
      expect(stockCoversIngredient('rice', '  '), isFalse);
    });
  });
}
