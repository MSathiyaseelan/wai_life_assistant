-- ============================================================
-- Backfill member_id: family_members.id → family_members.user_id
--
-- Earlier this session, the family member list handed to Wardrobe/
-- Health Space (LifeMember.id in my_hub_screen.dart / lifestyle_screen.dart)
-- was changed from the family_members row id to family_members.user_id
-- (the real auth uid), to fix "Family Today" not matching the same
-- person across two devices.
--
-- wardrobe_items / wardrobe_outfit_logs / health_* all persist a
-- `member_id` column that was, by design, the family_members ROW id
-- (see the comment on pantry's member_id: "family_members.id, or 'me'
-- for personal"). Once the selectable member ids became user_id-based,
-- every row written before this change became permanently unmatchable —
-- _selectedMember now resolves to a real auth uid that no existing row's
-- member_id equals, so previously-added wardrobe items / health records
-- silently stopped showing up ("nothing showing, details were added
-- earlier").
--
-- Fix: backfill member_id on every affected table from the owning
-- family_members row's id to its user_id, wherever that user_id is
-- known (unlinked/placeholder family members with no user_id are left
-- as-is — they were never selectable via a real auth uid to begin with).
-- 'me' (personal-wallet default) is untouched — it was never fm-id-based.
-- ============================================================

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'wardrobe_items',
    'wardrobe_outfit_logs',
    'health_profiles',
    'health_medications',
    'health_doctors',
    'health_documents',
    'health_appointments',
    'health_vitals',
    'health_vaccinations',
    'health_insurance'
  ]
  LOOP
    EXECUTE format(
      'UPDATE %I t
         SET member_id = fm.user_id::TEXT
         FROM family_members fm
         WHERE t.member_id = fm.id::TEXT
           AND fm.user_id IS NOT NULL',
      t
    );
  END LOOP;
END $$;
