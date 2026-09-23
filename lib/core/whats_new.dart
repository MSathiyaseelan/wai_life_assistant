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
    26: [
      'Fixed a crash on My Hub for some fresh installs.',
      'Fixed a few screens (My Hub, PlanIt, Health Space) showing "Failed to save/load" when the real cause was just being offline.',
    ],
    27: [
      'Fixed removed family members still getting transaction and reminder alerts.',
      'Fixed reminders occasionally failing to save.',
      'Fixed function dates sometimes showing the wrong year.',
    ],
    28: [
      'Fixed scanning a bill sometimes failing to save to your personal wallet.',
      'Fixed a blank Messages tab on function detail screens.',
      'Fixed tapping a family member under Wardrobe not showing their outfit.',
      'Added gender to your profile, with a bigger, better-organized set of wardrobe categories to match.',
    ],
    31: [
      'Item Locator: move containers between Personal and Family groups.',
      'Wardrobe: edit and delete items and outfit logs, full-image viewer, and share items across Personal/Family.',
      'Fixed the update prompt sometimes appearing twice, or restart not working, after downloading an update.',
      'Functions: added a Dishes tab.',
      'Pantry: added a Beverages meal type.',
      'Wallet: export transactions and split groups to CSV.',
    ],
    32: [
      'Fixed the OTP screen briefly flashing a red error right after requesting the code.',
      'Fixed Wardrobe\'s full-image viewer sometimes showing a blank image.',
      'Fixed tapping a recipe under "Your Recipes" in Add Recipe not opening its details.',
      'Fixed slow/unresponsive number taps when setting your App Lock PIN.',
      'Added a "Forgot PIN?" option to App Lock, plus biometric as a fallback there.',
      'Privacy & Security: "Require Biometric" for Locked Notes and "Personalisation" now actually take effect.',
      'Fixed Family Plus/Pro members sometimes seeing "Free scan limit reached" on Wallet bill scans.',
    ],
  };
}
