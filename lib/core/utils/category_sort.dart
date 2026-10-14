/// Sorts category options A–Z by their display label so users can find one
/// quickly. Matching ignores case and any leading emoji ("🍔 Food" sorts
/// under F). An "All" option stays first and catch-all buckets ("Other",
/// "Others", "Misc") stay last.
List<T> sortCategories<T>(Iterable<T> items, String Function(T) labelOf) {
  final leading = RegExp(r'^[^\p{L}\p{N}]+', unicode: true);
  String key(T item) =>
      labelOf(item).replaceFirst(leading, '').trim().toLowerCase();
  int rank(String k) => switch (k) {
    'all' => 0,
    'other' || 'others' || 'misc' || 'miscellaneous' => 2,
    _ => 1,
  };
  return items.toList()..sort((a, b) {
    final ka = key(a), kb = key(b);
    final r = rank(ka).compareTo(rank(kb));
    return r != 0 ? r : ka.compareTo(kb);
  });
}

/// [sortCategories] for plain category-name strings.
List<String> sortCategoryNames(Iterable<String> names) =>
    sortCategories(names, (n) => n);
