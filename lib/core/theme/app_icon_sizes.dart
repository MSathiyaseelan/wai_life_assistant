class AppIconSizes {
  AppIconSizes._();

  // Bottom navigation / Tabs
  static const bottomNav = 24.0;

  // AppBar icons (back, menu, actions)
  static const appBar = 24.0;

  // Primary list / tile leading icons
  static const list = 24.0;

  // Secondary icons (subtitle, trailing)
  static const secondary = 20.0;

  // Small helper icons (info, hint, inline)
  static const small = 16.0;
  static const medium = 18.0;

  // Large feature icons (empty states, headers)
  static const large = 32.0;

  // Floating action buttons / rail buttons
  static const fab = 28.0;
}

// | Usage             | Size | Reason                   |
// | ----------------- | ---- | ------------------------ |
// | Bottom Nav        | 24   | Material standard        |
// | AppBar            | 24   | Balanced with title text |
// | List leading      | 24   | Clear but not noisy      |
// | Trailing / helper | 20   | Visually lighter         |
// | Inline            | 16   | Doesn’t break text flow  |
// | Feature / Empty   | 32   | Visual emphasis          |
// | FAB icon          | 28   | Looks centered in FAB    |
