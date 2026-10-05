/// A person's name needs at least one letter (any script, so Tamil etc. pass).
///
/// Some keyboards (e.g. Samsung) keep offering the SMS code as a suggestion
/// for a few minutes after OTP, and Profile Setup focuses the name field
/// straight away — a tap on that chip used to save the 6-digit code as the
/// user's name.
bool isValidPersonName(String name) =>
    RegExp(r'\p{L}', unicode: true).hasMatch(name.trim());
