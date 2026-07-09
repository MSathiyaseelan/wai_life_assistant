/// Normalizes an ingredient/grocery name into a stable comparison key so
/// the same ingredient is recognized across the Pantry recipe library and
/// the Basket (In Stock / To Buy), regardless of capitalization, plural
/// form, or stray punctuation — e.g. "Tomato", "tomato", "Tomatoes" all
/// normalize to "tomato".
///
/// Mirrors normalize_grocery_name() in
/// supabase/migrations/087_grocery_normalized_name.sql, which backfills
/// this value server-side for rows written before this existed.
String normalizeIngredientName(String raw) {
  var s = raw.toLowerCase().trim();
  s = s.replaceAll(RegExp(r'[^a-z0-9 ]'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (s.length > 3 && s.endsWith('ies')) {
    s = '${s.substring(0, s.length - 3)}y';
  } else if (s.length > 4 && RegExp(r'(shes|ches|xes|ses)$').hasMatch(s)) {
    s = s.substring(0, s.length - 2);
  } else if (s.length > 3 &&
      s.endsWith('s') &&
      !RegExp(r'(ss|us|as|os)$').hasMatch(s)) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
