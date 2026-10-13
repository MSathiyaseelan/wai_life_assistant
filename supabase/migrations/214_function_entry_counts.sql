-- ============================================================
-- 214_function_entry_counts.sql
--
-- Our Functions cards show 🎁 gift / 💰 moi counts, but the list only
-- loads functions_my rows — gifts and moi entries were fetched per
-- function when its detail screen opened, so the counts vanished on the
-- next refresh. This returns both counts for a batch of functions in one
-- call.
--
-- function_moi_entries.function_id is TEXT with no FK to functions_my,
-- so PostgREST can't embed a count for it — hence an RPC. SECURITY
-- INVOKER: the tables' own RLS decides what each caller can count.
-- ============================================================

CREATE OR REPLACE FUNCTION function_entry_counts(p_function_ids TEXT[])
RETURNS TABLE (function_id TEXT, gift_count INT, moi_count INT)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    ids.id,
    (SELECT COUNT(*)::INT FROM function_gifts g
      WHERE g.function_id = ids.id::UUID AND g.deleted_at IS NULL),
    (SELECT COUNT(*)::INT FROM function_moi_entries m
      WHERE m.function_id = ids.id AND m.deleted_at IS NULL)
  FROM unnest(p_function_ids) AS ids(id);
$$;

GRANT EXECUTE ON FUNCTION function_entry_counts(TEXT[]) TO authenticated;
