# Emulator helper scripts

This folder contains simple helpers and documentation for running the Firebase
Emulators used by the project.

Available npm scripts (run from the project root):

-   `npm run start:emulators` — start the Firestore and Storage emulators (UI on :4000)
-   `npm run seed` — run the seeding script that writes sample `loan_items` documents

Quick workflow

1. Start the emulators:

```fish
npm run start:emulators
```

2. In another terminal, seed the emulator with sample data:

```fish
npm run seed
```

3. Inspect the Emulator UI at: http://localhost:4000

Notes

-   The Flutter app (`lib/main.dart`) is already configured to use the Firestore and
    Storage emulators when running in debug mode (`useFirestoreEmulator('localhost', 8080)` and
    `useStorageEmulator('localhost', 9199)`).
-   If you run the app on an Android emulator and it cannot reach `localhost`, use
    `10.0.2.2` as the host (I can add an automatic fallback to `lib/main.dart` if you
    want).
-   The seed script prefers Node >= 18 (global `fetch`). If you use older Node, install
    a fetch polyfill (e.g. `npm install node-fetch`) or use Node 18+.
