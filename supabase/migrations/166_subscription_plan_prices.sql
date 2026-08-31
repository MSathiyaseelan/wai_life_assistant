-- ============================================================
-- 166_subscription_plan_prices.sql
--
-- subscription_plans.price_monthly/price_yearly were seeded as 0 in
-- 061_subscription_plans_full_setup.sql with a "Price TBD" comment —
-- the Subscription settings sheet's upgrade tiles (subscription_sheet.dart)
-- read these columns directly and were showing "TBD/mo" even after
-- family_plus/family_pro were fully priced and published in Play Console
-- + RevenueCat, since those two systems don't feed this table.
--
-- This is display-only data (the real charge always comes from Play
-- Billing via RevenueCat's product prices, e.g. paywall_screen.dart reads
-- product.priceString live) — kept in sync manually when list prices
-- change.
-- ============================================================

UPDATE subscription_plans SET price_monthly = 149, price_yearly = 999  WHERE plan_key = 'family_plus';
UPDATE subscription_plans SET price_monthly = 299, price_yearly = 1999 WHERE plan_key = 'family_pro';
