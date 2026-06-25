-- 065_soft_delete_all.sql
-- Adds deleted_at to all soft-deletable tables (families and transactions already have it from 034).

ALTER TABLE wishes               ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE reminders            ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE notes                ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE wardrobe_items       ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE health_medications   ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE health_doctors       ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE health_documents     ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE health_appointments  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE health_vitals        ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE health_vaccinations  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE health_insurance     ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE family_members       ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE functions_my         ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE functions_upcoming   ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE functions_attended   ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE function_participants        ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE function_moi_entries         ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE function_clothing_families   ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE function_bridal_essentials   ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE function_return_gifts        ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE item_locator_containers ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE item_locator_items      ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE tx_groups           ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE bills               ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE wallet_budgets      ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE recipes             ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE meal_entries        ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE meal_reactions      ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Partial indexes for efficient recycle-bin queries (only index deleted rows)
CREATE INDEX IF NOT EXISTS idx_wishes_deleted_at               ON wishes               (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_reminders_deleted_at            ON reminders            (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notes_deleted_at                ON notes                (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_wardrobe_items_deleted_at       ON wardrobe_items       (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_health_medications_deleted_at   ON health_medications   (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_health_doctors_deleted_at       ON health_doctors       (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_health_documents_deleted_at     ON health_documents     (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_health_appointments_deleted_at  ON health_appointments  (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_health_vitals_deleted_at        ON health_vitals        (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_health_vaccinations_deleted_at  ON health_vaccinations  (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_health_insurance_deleted_at     ON health_insurance     (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_family_members_deleted_at       ON family_members       (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_functions_my_deleted_at         ON functions_my         (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_functions_upcoming_deleted_at   ON functions_upcoming   (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_functions_attended_deleted_at   ON functions_attended   (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_function_participants_deleted_at       ON function_participants       (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_function_moi_entries_deleted_at        ON function_moi_entries        (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_function_clothing_families_deleted_at  ON function_clothing_families  (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_function_bridal_essentials_deleted_at  ON function_bridal_essentials  (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_function_return_gifts_deleted_at       ON function_return_gifts       (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_item_locator_containers_deleted_at ON item_locator_containers (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_item_locator_items_deleted_at      ON item_locator_items      (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tx_groups_deleted_at         ON tx_groups        (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bills_deleted_at             ON bills            (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_wallet_budgets_deleted_at    ON wallet_budgets   (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_recipes_deleted_at           ON recipes          (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_meal_entries_deleted_at      ON meal_entries     (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_meal_reactions_deleted_at    ON meal_reactions   (deleted_at) WHERE deleted_at IS NOT NULL;

-- Purge function: hard-delete rows soft-deleted more than 30 days ago
CREATE OR REPLACE FUNCTION purge_old_deleted_records()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM wishes               WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM reminders            WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM notes                WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM wardrobe_items       WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM health_medications   WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM health_doctors       WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM health_documents     WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM health_appointments  WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM health_vitals        WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM health_vaccinations  WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM health_insurance     WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM family_members       WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM functions_my         WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM functions_upcoming   WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM functions_attended   WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM function_participants       WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM function_moi_entries        WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM function_clothing_families  WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM function_bridal_essentials  WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM function_return_gifts       WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM item_locator_containers WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM item_locator_items      WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM tx_groups           WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM bills               WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM wallet_budgets      WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM recipes             WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM meal_entries        WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM meal_reactions      WHERE deleted_at < NOW() - INTERVAL '30 days';
END;
$$;
