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
    33: [
      'Split groups: requesting an extension works again, extension and proof details now show on the Overview, and you can still submit proof after asking for more time.',
      'Tap a payment proof or wardrobe photo to view it full size.',
      'Fixed crashes when opening Wardrobe items or editing Item Locator containers.',
      'Wardrobe: "Pairs well with" now lists all your items.',
      'Quiet hours now apply even when the app is closed — notifications arrive silently.',
      'Voice input: pick any of the 10 supported languages in Settings.',
      'Your Default Scope choice now saves and syncs properly.',
      '"borrowed … from" is now recorded as a borrow, and salary SMS imports are categorised as Salary.',
      'Profile photo changes now show up right away.',
      '"Logout from all devices" now fully signs out your other phones.',
    ],
    34: [
      'Pantry: meals now warn you when they may contain a family member\'s allergy from the Family Food Guide.',
      'Meal Map: family members\' meal changes now show up live, and the days you can plan ahead now match your plan exactly.',
      'Basket: "+ To Buy" keeps the item in stock and adds a separate To Buy entry; buying it adds to your stock instead of creating a duplicate.',
      'Basket and your Dashboard list now stay in sync, and the expiring-items count matches the Expiring Soon list.',
      'Recipe stock check is more accurate — "egg" no longer matches "eggplant", and "rice" no longer matches "rice flour".',
      'Family Food Guide: saving now updates right away, and you can always edit your own preferences.',
      'Family permissions for editing and deleting meals and recipes now work as set.',
      'Deleting a Basket item now asks for confirmation.',
      'Split payment reminders no longer show the amount as negative.',
    ],
    35: [
      'Functions: the "Bridal Essentials" tab is now "Essentials", with categories that fit any kind of function.',
      'Lend, Borrow and Request Money: pick an exact due date, and change or remove it later when editing.',
      'Fixed buttons and message boxes being hidden behind the navigation bar on newer Android phones.',
      'Wallet reports and export now include lent, borrowed and split money in the totals.',
      'Wallet reports: use the arrows on the Daily tab to see earlier weeks day by day.',
      'Shopping List: ticked an item by mistake? Tap Undo to bring it back.',
      'Family shopping lists now update live when another member adds or ticks off an item.',
    ],
    37: [
      'Fixed adding a task from the AI Assistant.',
      'Fixed "Delete Account" failing.',
      'Fixed the OTP code sometimes being saved as your name — names now need at least one letter.',
      'Pasting or tapping the suggested OTP code now fills all six boxes at once.',
      'Fixed the status bar and navigation buttons flickering on some Samsung phones.',
      'The app opens faster on first launch, and notifications work right after you sign in.',
      'Family: members can now leave a family from Edit Family, and only admins see the delete option.',
    ],
    38: [
      'Pantry: rice, dal, flour, oil and other loose items now get sensible units (g, kg, L) instead of "pcs".',
      'Pantry: quantities show cleanly — "2 kg" instead of "2.0 kg".',
      'Pantry: add several items in one go, e.g. "need brinjal 2kg and pori 1 pack".',
      'Pantry: new Oils category, and meat and fish are now filed under Meat instead of Other.',
      'Alert Me: reminders now show the right family member they\'re assigned to.',
      'Dashboard: tap "Plan a meal" on Today\'s Plate to start planning.',
    ],
    39: [
      'Functions: family members added to a participant group now save correctly.',
      'Functions: a participant can be a person or a city group, e.g. relatives from Madurai.',
      'Functions: vendors are now saved, so they stay after you leave the screen.',
      'Functions: pull down to refresh now shows newly added or deleted functions right away.',
      'PlanIt: deleting an item now asks for confirmation first.',
    ],
    40: [
      'AI assistant: say "planning to buy a new A/C for 40k" and it\'s added to your Wish List.',
      'AI assistant: if a request is missing details, it now asks instead of showing an error.',
      'Dashboard: Needs Attention and Upcoming Functions open in the right Personal or family group, with a label showing which.',
      'Functions: Gold/Silver and gift items received are now saved.',
      'Functions: "Undo returned" on a moi entry now stays undone.',
      'Functions: members in a participant group have separate Name and Relation boxes.',
    ],
  };
}
