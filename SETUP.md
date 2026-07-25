# Setup

This app is code-complete against Supabase, Plaid, and Google/Apple sign-in, but needs real
credentials before those features work. Everything below reads from `dart_define.json`
(git-ignored — copy `dart_define.example.json` and fill in real values), or from native config
files for the OAuth providers.

## Supabase

1. Create a project at supabase.com.
2. Run the migration in `supabase/migrations/0001_init.sql` (SQL editor, or `supabase db push`
   after `supabase link --project-ref <ref>`).
3. Deploy the three Edge Functions in `supabase/functions/` (see Plaid section):
   `supabase functions deploy plaid-link-token`, `plaid-exchange`, `plaid-sync-transactions`.
   Then set their secrets: `supabase secrets set PLAID_CLIENT_ID=... PLAID_SECRET=... PLAID_ENV=sandbox`.
   `plaid-exchange` and `plaid-sync-transactions` also need `SUPABASE_URL` and
   `SUPABASE_SERVICE_ROLE_KEY` (find the service-role key in Project Settings → API — set it with
   `supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...`; `SUPABASE_URL` is auto-injected by Supabase
   for every Edge Function, no need to set it yourself).
4. Put the project URL and publishable key into `dart_define.json` as `SUPABASE_URL` /
   `SUPABASE_PUBLISHABLE_KEY`. Never put the secret/service-role key in the Flutter app.

## Plaid

1. Sign up at plaid.com, grab the sandbox `client_id` and `secret` from the dashboard.
2. Set them as Supabase Edge Function secrets (see above) — the secret never touches the client.
3. Put the Plaid **public** key (used to init Plaid Link) into `dart_define.json` as
   `PLAID_PUBLIC_KEY`, and set `PLAID_ENV` to `sandbox` / `development` / `production`.

## Delivery Habits PRO (subscription / In-App Purchase)

Manual budget tracking is free forever; Plaid bank sync is gated behind a Pro subscription
(`lib/screens/accounts/link_account_button.dart` checks `isProProvider` before launching Plaid
Link). The paywall UI and purchase plumbing (`in_app_purchase` package) are code-complete, but the
actual subscription products need to exist in App Store Connect (and later Google Play Console)
before purchases will work.

1. **Enable In-App Purchase capability.** On the App ID
   (developer.apple.com/account/resources/identifiers → `com.deliveryhabits.deliveryHabits`),
   check **In-App Purchase** if it isn't already implicitly enabled, and save.
2. **Create a subscription group** in App Store Connect → your app → Monetization → Subscriptions
   → **+** next to Subscription Groups. Name it e.g. "Delivery Habits Pro".
3. **Create three subscription products** inside that group, with these **exact** Product IDs
   (must match `lib/services/purchase_products.dart`):
   - `com.deliveryhabits.deliveryHabits.pro.monthly` — Duration: 1 Month — price: $3.99
   - `com.deliveryhabits.deliveryHabits.pro.yearly` — Duration: 1 Year — price: $23.88
     (displays as $1.99/mo)
   - `com.deliveryhabits.deliveryHabits.pro.yearly.offer` — Duration: 1 Year — price: $11.99
     (the "hold up... this is a limited offer" retention-screen price, ~$1.00/mo)
   For each, add a localization (display name + description) and, if you want the "activate free
   trial" / "try free for 7 days" copy to be real rather than just UI copy, add a 7-day
   Introductory Offer (free trial) under that product's Subscription Prices.
4. Submit the subscriptions for review along with your next app build (subscriptions can't go live
   independently — Apple reviews them together with a build that uses them).
5. **Android**: same product IDs, created later in Google Play Console → Monetize → Subscriptions,
   once you set up a Play Console listing (not done yet — this session focused on iOS/TestFlight).

Purchases are trusted client-side for v1 (no server-side receipt verification) — see the doc
comment on `PurchaseService` for what to add before this matters for real revenue.

## Google Sign-In

1. In Google Cloud Console, create OAuth client IDs: one "Web application" client (used as the
   `serverClientId` so Supabase can verify the ID token) and one per mobile platform
   (Android/iOS).
2. Put the **web** client ID into `dart_define.json` as `GOOGLE_SIGN_IN_SERVER_CLIENT_ID`.
3. Android: add the SHA-1 of your signing key to the Android OAuth client in Google Cloud
   Console.
4. iOS: add the iOS client's reversed client ID as a URL scheme in `ios/Runner/Info.plist`
   (`CFBundleURLTypes`), per the `google_sign_in` package's iOS setup docs.
5. In Supabase Dashboard → Authentication → Providers → Google, enable the provider and paste the
   web client ID.

## Apple Sign-In

1. Requires an active Apple Developer account ($99/yr).
2. In Apple Developer → Certificates, Identifiers & Profiles, enable "Sign In with Apple" for the
   app's App ID, and create a Services ID + key for server-side verification.
3. In Supabase Dashboard → Authentication → Providers → Apple, enable the provider and fill in
   the Services ID / key details per Supabase's Apple guide.
4. In Xcode (once available), add the "Sign In with Apple" capability to the Runner target.

## iOS builds (Codemagic) — the path to a physical iPhone

No local Xcode is available in this environment, so iOS builds happen in the cloud. `codemagic.yaml`
is already checked in with Android + iOS workflows; here's what you need to do on your end:

1. **Create a GitHub repo and push.** This machine doesn't have the `gh` CLI or a GitHub login, so
   create the repo yourself (github.com → New repository, don't initialize with a README), then:
   ```
   git remote add origin git@github.com:<you>/delivery-habits.git
   git push -u origin main
   ```
2. **Sign up at codemagic.io** and connect the GitHub repo. It'll detect `codemagic.yaml`
   automatically.
3. **Add the secrets group.** In Codemagic → your app → Environment variables, create a group
   named exactly `delivery_habits_secrets` and add (as secure vars): `SUPABASE_URL`,
   `SUPABASE_PUBLISHABLE_KEY`, `PLAID_PUBLIC_KEY`, `PLAID_ENV`, `GOOGLE_SIGN_IN_SERVER_CLIENT_ID`.
   The workflows write these into a `dart_define.json` at build time — the real one on this machine
   is git-ignored and never leaves your laptop.
4. **Apple Developer account** ($99/yr, developer.apple.com/programs) — required for code signing
   and TestFlight.
5. **Connect code signing.** In App Store Connect → Users and Access → Integrations → App Store
   Connect API, generate a key with the **Admin** role (App Manager isn't enough — automatic
   certificate/profile creation needs Admin). In Codemagic → Team settings → Integrations → Apple
   Developer Portal, add it — whatever name you give the integration must match `codemagic.yaml`'s
   `app_store_connect:` value under `ios-workflow.integrations` exactly (this project's integration
   ended up named `codemagic`, which is what the yaml currently references). In practice, Codemagic
   may not auto-create the certificate/provisioning profile on the first build — if you hit "No
   matching profiles found", generate them once manually via Settings → Code signing identities →
   iOS certificates (Generate certificate, type App Store) and iOS provisioning profiles (Fetch
   profiles, or create one at developer.apple.com/account/resources/profiles and fetch again).
6. **Register the app in App Store Connect** with bundle ID `com.deliveryhabits.deliveryHabits`
   (matches `ios_signing.bundle_identifier` in `codemagic.yaml`) so TestFlight has somewhere to
   publish to.
7. **Trigger a build.** Codemagic dashboard → Start new build → `ios-workflow`. On success it
   publishes straight to TestFlight; install the TestFlight app on your iPhone and accept the
   invite to get the build. Builds are manual-trigger by default (see the commented-out
   `triggering` block at the bottom of `codemagic.yaml`) to conserve free-tier minutes — flip it on
   once you're iterating less frequently.

## Local dev

```
flutter run --dart-define-from-file=dart_define.json -d <device-id>
```

`flutter devices` lists available targets, including the `delivery_habits` Android emulator
created during setup.
