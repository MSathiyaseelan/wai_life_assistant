/// "What's New" changelog entries, shown once per update via
/// [WhatsNewSheet] — see dashboard_screen.dart's version-check on launch.
///
/// Keyed by build number: pubspec.yaml's `version: 1.0.0+24` → key `24`.
/// Write a new entry here in the SAME commit as the version bump, whenever
/// a release has user-visible changes worth announcing. Skip versions that
/// are purely internal (config, refactors, backend-only fixes) — an empty
/// changelog is better than a noisy one.
///
/// If a user skips several versions between opens, [WhatsNewSheet] shows
/// the union of every version's entries in the gap, most recent first.
class WhatsNew {
  WhatsNew._();

  static const Map<int, List<String>> entries = {
    25: [
      'Redesigned the update-ready prompt into a clearer "Restart to update" screen.',
    ],
  };
}
