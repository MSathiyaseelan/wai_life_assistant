# RiyasHome Admin Dashboard

Flutter web app for monitoring the RiyasHome app: users, subscriptions,
reported issues, errors, AI usage and live `app_config`.

It never touches the app's tables directly. Every read and write goes
through the `admin_*` SQL functions in
[`supabase/migrations/201_admin_dashboard.sql`](../supabase/migrations/201_admin_dashboard.sql),
and each one checks that the signed-in account is in `dashboard_admins`.

## Pages

| Page | Shows | Admin can |
|---|---|---|
| Overview | Headline numbers + daily charts (new users, errors, AI calls, issues) | — |
| Reported issues | Everything sent from the app's Report Issue screen, with screenshots and device info | Set status/priority, write a reply (users see it under "My reports") |
| Errors | `error_logs` grouped by message + screen, with stack trace and recent occurrences | Mark a group acknowledged / resolved / ignored |
| Users | App users with plan, activity counts, search | — |
| Subscriptions | `wallet_subscriptions`, lapsing plans highlighted | — |
| AI usage | Calls, failures, corrections, latency, tokens per feature; recent failures | — |
| App config | `app_config` key/values | Edit existing values |

Links to Supabase, Crashlytics, RevenueCat and Play Console are in the side menu.

## Roles

- `admin` can read everything and make the edits above.
- `viewer` is read-only.

## One-time setup (per environment)

1. Apply `supabase/migrations/201_admin_dashboard.sql`.
2. Supabase dashboard → **Authentication → Users → Add user** → create an
   email + password user with **Auto Confirm User** ticked.
3. SQL editor:
   ```sql
   INSERT INTO dashboard_admins (user_id, role)
   SELECT id, 'admin' FROM auth.users WHERE email = '<that email>';
   ```

To add someone later, repeat steps 2–3 with their email and use `'viewer'`
for read-only access. To remove access:
`DELETE FROM dashboard_admins WHERE user_id = (SELECT id FROM auth.users WHERE email = '<email>');`

Dashboard accounts are excluded from all user counts.

## Run

Uses the same env files as the mobile app:

```sh
cd admin
flutter run -d chrome --dart-define-from-file=../env/dev.json
```

Build for hosting:

```sh
flutter build web --dart-define-from-file=../env/prod.json
# output: admin/build/web
```

The header shows a DEV / PROD badge so it's always clear which database
you're looking at.
