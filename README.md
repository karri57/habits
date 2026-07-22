# Delivery Habits

A budgeting and habit-tracking app for food delivery spending — set a monthly budget, track
orders against it, and see your saved/overspent total for every day on a calendar.

Flutter + Supabase (Postgres, Auth, Edge Functions) + Plaid + Riverpod. See [SETUP.md](SETUP.md)
for how to wire up real Supabase/Plaid/OAuth credentials and the Codemagic iOS pipeline — the app
runs out of the box against placeholder config with an empty/local-only backend.

## Local dev

```
flutter run --dart-define-from-file=dart_define.json -d <device-id>
```

`flutter devices` lists available targets.
