abstract final class AppRpc {
  // ── Plan / usage ───────────────────────────────────────────────────────────
  static const String getPlanLimits      = 'get_plan_limits';
  static const String checkFeatureLimit  = 'check_feature_limit';
  static const String getEffectiveFeatureLimit = 'get_effective_feature_limit';

  // ── Profile / account ──────────────────────────────────────────────────────
  static const String bootstrapNewUser      = 'bootstrap_new_user';
  static const String deleteMyAccount       = 'delete_my_account';
  static const String devLinkProfileByPhone = 'dev_link_profile_by_phone';
  static const String markOnboarded         = 'mark_onboarded';

  // ── Family ─────────────────────────────────────────────────────────────────
  static const String createFamilyWithWallet = 'create_family_with_wallet';
  static const String updateFamily           = 'update_family';
  static const String deleteFamily           = 'delete_family';
  static const String addFamilyMember          = 'add_family_member';
  static const String updateFamilyMember       = 'update_family_member';
  static const String leaveFamilyMember        = 'leave_family';
  static const String transferAdminAndLeave    = 'transfer_admin_and_leave';

  // ── Invites ────────────────────────────────────────────────────────────────
  static const String sendFamilyInvite    = 'send_family_invite';
  static const String createInviteLink    = 'create_invite_link';
  static const String acceptFamilyInvite  = 'accept_family_invite';
  static const String declineFamilyInvite = 'decline_family_invite';
  static const String joinFamilyByToken   = 'join_family_by_token';

  // ── Wallet ─────────────────────────────────────────────────────────────────
  static const String incrementSplitReminder = 'increment_split_reminder';
}
