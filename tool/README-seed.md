Seeding Firestore Emulator

This project includes a small Node script to seed the Firestore emulator with sample
LoanItem documents. It uses the emulator REST API and works without requiring a
service account.

Prerequisites

-   Node.js (you already have fnm-managed Node)
-   Firebase CLI (installed and configured)
-   Firestore emulator running on localhost:8080

How to run

1. Start the emulators in a separate terminal. You can use the provided helper script:

```fish
./scripts/start_emulators.fish
```

2. In another terminal (project root), run the seed script:

```fish
node scripts/seed_firestore.js
```

3. Open the Emulator UI to inspect data: http://localhost:4000

Notes

-   The script reads `firebase.json` in the project root to determine the projectId
    (fallback to `demo-project` when not present).
-   This script writes documents to the `loan_items` collection. It sets a simple
    `isHistory` boolean field so items appear either in active or history queries.
