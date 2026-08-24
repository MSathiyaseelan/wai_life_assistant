-- Migration 159: One-time backfill for profiles.phone left NULL by accounts
-- bootstrapped before migration 137 taught bootstrap_new_user() to parse the
-- phone out of the synthetic internal email (phone_<digits>@waiapp.internal)
-- instead of relying on auth.users.phone, which firebase-verify never
-- actually sets (it only stores the phone in user_metadata).
--
-- Only touches rows that are still NULL — never overwrites an existing value.

UPDATE profiles p
SET phone = '+' || (regexp_match(u.email, '^phone_(\d+)@waiapp\.internal$'))[1],
    updated_at = NOW()
FROM auth.users u
WHERE p.id = u.id
  AND p.phone IS NULL
  AND u.email ~ '^phone_\d+@waiapp\.internal$';
