/// Normalizes an ingredient/grocery name into a stable comparison key so
/// the same ingredient is recognized across the Pantry recipe library and
/// the Basket (In Stock / To Buy), regardless of capitalization, plural
/// form, or stray punctuation — e.g. "Tomato", "tomato", "Tomatoes" all
/// normalize to "tomato".
///
/// Mirrors normalize_grocery_name() in
/// supabase/migrations/087_grocery_normalized_name.sql, which backfills
/// this value server-side for rows written before this existed.
///
/// Also keeps the Tamil Unicode block (U+0B80-U+0BFF, see
/// supabase/migrations/151_tamil_ingredient_search.sql) so a Tamil
/// ingredient name survives normalization intact and can resolve through
/// [canonicalIngredientName]'s alias lookup. Plain ASCII-letter stripping
/// isn't enough — Tamil vowel signs and the pulli (virama) mark are
/// combining characters, not "letters", so a naive alpha-only filter would
/// strip them and corrupt the word. To support another language later,
/// add its Unicode block range here the same way and seed its aliases in
/// a migration like 151's.
String normalizeIngredientName(String raw) {
  var s = raw.toLowerCase().trim();
  s = s.replaceAll(RegExp(r'[^a-z0-9஀-௿ ]'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (s.length > 3 && s.endsWith('ies')) {
    s = '${s.substring(0, s.length - 3)}y';
  } else if (s.length > 4 && RegExp(r'(shes|ches|xes|ses)$').hasMatch(s)) {
    s = s.substring(0, s.length - 2);
  } else if (s.length > 3 && s.endsWith('oes')) {
    // "tomatoes" -> "tomato", "potatoes" -> "potato", "mangoes" -> "mango".
    // Ambiguous with "-oe" nouns pluralized by just adding "s" (shoes,
    // canoes) — those never occur as pantry ingredients, so the "-o" base
    // is the right assumption for this domain.
    s = s.substring(0, s.length - 2);
  } else if (s.length > 3 &&
      s.endsWith('s') &&
      !RegExp(r'(ss|us|as|os)$').hasMatch(s)) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// In-memory cache of the `ingredient_aliases` table (normalized alias ->
/// normalized canonical name), e.g. "eggplant" -> "brinjal". Populated by
/// [PantryService] once per session — see [setIngredientAliases] — so new
/// synonyms can be added with a plain SQL insert, no app release.
Map<String, String> _ingredientAliases = const {};

/// Replaces the cached alias map. Called by PantryService after fetching
/// the `ingredient_aliases` table.
void setIngredientAliases(Map<String, String> aliases) {
  _ingredientAliases = aliases;
}

/// Resolves [raw] to its final comparison key: base-normalize via
/// [normalizeIngredientName], then follow the alias if one is cached (e.g.
/// "Eggplant" and "Brinjal" both resolve to "brinjal"). Falls back to the
/// base-normalized form when no alias is loaded/known, so matching still
/// works (just without synonym awareness) before the alias cache loads.
String canonicalIngredientName(String raw) {
  final base = normalizeIngredientName(raw);
  return _ingredientAliases[base] ?? base;
}

/// Words that turn an ingredient into a different product — "rice flour"
/// is not "rice", "coconut oil" is not "coconut". Stored normalized
/// (singular), as [normalizeIngredientName] produces them.
const _productFormWords = {
  'flour', 'powder', 'paste', 'oil', 'sauce', 'milk', 'butter', 'cream',
  'juice', 'leaf', 'leave', 'seed', 'water', 'vinegar', 'syrup', 'extract',
  'essence', 'masala', 'pickle', 'jam', 'ketchup', 'chip',
};

/// Whether a stock/basket item named [stockKey] covers a recipe ingredient
/// named [ingredientKey] (both normalized names). Matches whole words only
/// — "egg" never matches "eggplant", "salt" never "unsalted butter". When
/// one name is the other plus extra words, it still matches for a plain
/// qualifier ("basmati rice" ↔ "rice", "red onion" ↔ "onion") but not when
/// an extra word makes it a different product ("rice flour" ↔ "rice").
bool stockCoversIngredient(String ingredientKey, String stockKey) {
  List<String> words(String s) => s
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map(normalizeIngredientName)
      .where((w) => w.isNotEmpty)
      .toList();
  final ing = words(ingredientKey);
  final stock = words(stockKey);
  if (ing.isEmpty || stock.isEmpty) return false;

  final (shorter, longer) =
      ing.length <= stock.length ? (ing, stock) : (stock, ing);
  for (var start = 0; start + shorter.length <= longer.length; start++) {
    var match = true;
    for (var i = 0; i < shorter.length; i++) {
      if (longer[start + i] != shorter[i]) {
        match = false;
        break;
      }
    }
    if (!match) continue;
    final extra = [
      ...longer.sublist(0, start),
      ...longer.sublist(start + shorter.length),
    ];
    return !extra.any(_productFormWords.contains);
  }
  return false;
}

/// Display-only capitalization: "ghee" -> "Ghee", "coconut oil" -> "Coconut
/// Oil". Only touches the first letter of each word — leaves the rest of a
/// word untouched (so an already-mixed-case name like "iPhone" isn't
/// mangled). Names are stored as typed/parsed (often lowercase from manual
/// entry or OCR); this is applied at render time so it doesn't affect the
/// [normalizeIngredientName] comparison key used for matching.
String displayCase(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
