# Quickstart: Borrowed items manager (local dev)

## Prerequisites

-   Flutter SDK installed (matching repo sdk constraints)
-   Supabase project configured with a free tier instance
-   Supabase URL and anon/public keys available

## Steps

1. Fork/clone repo
2. Create a Supabase project and enable Auth (email), Postgres, and Storage
3. Populate `.env` or Flutter secure config with SUPABASE_URL and SUPABASE_KEY
4. Run:

```fish
flutter pub get
flutter run
```

## Notes

-   The app defaults to offline-first; for full sync ensure Supabase credentials
    are set and a user is authenticated.
-   For Android contact picker testing, run on an Android emulator or device.

**End of quickstart**
