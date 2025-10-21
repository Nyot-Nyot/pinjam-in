---
description: "Task list for Borrowed items manager"
---

# Tasks: Borrowed items manager

**Input**: Design documents from `/specs/001-borrowed-items-manager/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: The plan enforces a TDD approach per constitution (Test-First). Generate test tasks for each story (unit/widget/integration) and CI integration.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

-   [ ] T001 Initialize Flutter project dependencies and formatters (no story) — update `pubspec.yaml` with Supabase client, image_picker, flutter_riverpod, flutter_test, contact_picker (Android) and run `flutter pub get` (project root)
-   [ ] T002 [P] Configure linting and formatting rules (analysis_options.yaml) and ensure project follows Flutter lints (project root)
-   [ ] T003 Create `.env.example` and secure config instructions for SUPABASE_URL and SUPABASE_ANNON_KEY (specs/001-borrowed-items-manager/quickstart.md)
-   [ ] T004 [P] Add Supabase initialization wrapper in `lib/services/supabase_service.dart` (create file)
-   [ ] T005 Create `supabase/migrations/` directory and add placeholder migration `001_init.sql` for tables (repository root)
-   [ ] T006 [P] Add CI job skeleton to run lint, flutter test, and basic build for Android/iOS (e.g., `.github/workflows/ci.yml`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infra that MUST be complete before any user story can be implemented

-   [ ] T007 Setup Supabase tables migration (create SQL in `supabase/migrations/001_init.sql`) to define `borrowed_items`, `contacts` with fields from `data-model.md` (supabase/migrations/001_init.sql)
-   [ ] T008 [P] Implement authentication flows (email sign-up/login) using Supabase in `lib/services/auth_service.dart` and tests in `test/services/auth_service_test.dart`
-   [ ] T009 Implement photo upload helper `lib/services/photo_service.dart` (upload to Supabase Storage) and unit tests `test/services/photo_service_test.dart`
-   [ ] T010 [P] Implement local cache layer for offline-first (e.g., `lib/services/local_cache.dart` using sqflite) and migration/sync scaffolding `lib/services/sync_service.dart`
-   [ ] T011 [P] Create basic Riverpod providers for Supabase client, auth state, and local cache in `lib/providers/` (files)
-   [ ] T012 Add privacy/consent flows and deletion UI placeholders in the app shell `lib/screens/settings/privacy_settings.dart` and tests `test/widgets/privacy_settings_test.dart`

**Checkpoint**: Foundation ready - user story implementation can begin

---

## Phase 3: User Story US1 - Quick mark returned (Priority: P1)

**Goal**: Allow user to mark an item as returned with a single swipe on the list

**Independent Test**: Integration test that performs a swipe gesture on the item in the home list and asserts item status updated and `returned_at` timestamp present.

### Tests (TDD required)

-   [ ] T013 [US1] Create integration test `integration_test/us1_mark_returned_test.dart` that verifies swipe action updates item status and UI

### Implementation

-   [ ] T014 [US1] Add list item widget `lib/widgets/borrowed_item_tile.dart` and widget tests `test/widgets/borrowed_item_tile_test.dart`
-   [ ] T015 [US1] Implement home list screen `lib/screens/home_screen.dart` with swipe-to-mark behavior and UI tests `test/widgets/home_screen_test.dart`
-   [ ] T016 [US1] Implement repository method `lib/repositories/borrowed_item_repository.dart` for `markReturned(id)` and unit tests `test/repositories/borrowed_item_repository_test.dart`
-   [ ] T017 [US1] Wire UI action to repository and ensure local cache + remote sync is triggered in `lib/services/sync_service.dart`

**Checkpoint**: US1 should be fully functional and testable independently

---

## Phase 4: User Story US2 - Add / Edit / Delete item (Priority: P2)

**Goal**: CRUD for borrowed items, including optional photo, contact (Android), return date, and notes

**Independent Test**: End-to-end test adding an item with photo and optional contact, verifying persistence after restart

### Tests

-   [ ] T018 [US2] Unit tests for `BorrowedItem` model validations `test/models/borrowed_item_test.dart`
-   [ ] T019 [US2] Integration test for add/edit/delete `integration_test/us2_crud_test.dart`

### Implementation

-   [ ] T020 [US2] Add form screen `lib/screens/item_edit_screen.dart` and widget tests `test/widgets/item_edit_screen_test.dart`
-   [ ] T021 [US2] Implement camera/photo picker integration `lib/services/photo_service.dart` (use previously created) and UI for attaching photo in `item_edit_screen.dart`
-   [ ] T022 [US2] Implement contact picker integration for Android `lib/services/contact_service.dart` and fallback phone input for other platforms; tests in `test/services/contact_service_test.dart`
-   [ ] T023 [US2] Implement create/update/delete repository methods in `lib/repositories/borrowed_item_repository.dart` and tests `test/repositories/borrowed_item_repository_test.dart`
-   [ ] T024 [US2] Add confirmation dialog for delete `lib/widgets/confirm_delete_dialog.dart` and widget tests `test/widgets/confirm_delete_dialog_test.dart`

**Checkpoint**: US2 should be independently testable and persisted

---

## Phase 5: User Story US3 - History, Search & Filters (Priority: P3)

**Goal**: Provide searchable and filterable history view

**Independent Test**: Unit/integration tests verifying search filtering, status filters, and pagination

### Tests

-   [ ] T025 [US3] Unit tests for search/filter helpers `test/utils/search_utils_test.dart`
-   [ ] T026 [US3] Integration test for history screen `integration_test/us3_history_test.dart`

### Implementation

-   [ ] T027 [US3] Implement history screen `lib/screens/history_screen.dart` and widget tests `test/widgets/history_screen_test.dart`
-   [ ] T028 [US3] Implement search bar and filters `lib/widgets/search_bar.dart` and `lib/widgets/filter_chip.dart`
-   [ ] T029 [US3] Add pagination/virtualized list support in `lib/widgets/virtual_list.dart` if needed

**Checkpoint**: US3 should be fully functional and testable independently

---

## Phase 6: User Story US4 - Statistics & Insights (Priority: P3)

**Goal**: Provide aggregated statistics and simple charts

**Independent Test**: After seeding sample data, verify aggregates match expected values

### Tests

-   [ ] T030 [US4] Unit tests for aggregation helpers `test/utils/aggregates_test.dart`

### Implementation

-   [ ] T031 [US4] Create statistics screen `lib/screens/statistics_screen.dart` and widget tests `test/widgets/statistics_screen_test.dart`
-   [ ] T032 [US4] Implement aggregation queries in repository `lib/repositories/statistics_repository.dart`
-   [ ] T033 [US4] Add simple charting (use an embeddable charting package) and ensure charts are accessible

**Checkpoint**: US4 should be testable and accurate with sample data

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

-   [ ] T034 [P] Documentation updates in `docs/` and `specs/001-borrowed-items-manager/quickstart.md`
-   [ ] T035 [P] Code cleanup and refactoring across modules
-   [ ] T036 [P] Performance optimization for lists and image loading; profiling report `docs/perf/profile_report.md`
-   [ ] T037 [P] Security & privacy audit: ensure PII handling and deletion UI work as intended
-   [ ] T038 [P] End-to-end smoke tests and release checklist `docs/release/checklist.md`

---

## Dependencies & Execution Order

### Phase Dependencies

-   **Setup (Phase 1)**: No dependencies - can start immediately
-   **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
-   **User Stories (Phase 3+)**: Depend on Foundational phase completion
    -   User stories can then proceed in parallel (if staffed)
    -   Or sequentially in priority order (P1 → P2 → P3)
-   **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

-   **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
-   **User Story 2 (P2)**: Can start after Foundational (Phase 2)
-   **User Story 3 (P3)**: Can start after Foundational (Phase 2)
-   **User Story 4 (P3)**: Can start after Foundational (Phase 2)

### Parallel Opportunities

-   Setup tasks T001, T002, T004, T006 can run in parallel
-   Foundational tasks T008, T009, T010, T011 can be parallelized by different engineers
-   User stories can be implemented in parallel after foundational tasks complete

---

## Parallel Example: User Story 1

-   [ ] T013 [US1] Create integration test `integration_test/us1_mark_returned_test.dart`
-   [ ] T014 [US1] Add list item widget `lib/widgets/borrowed_item_tile.dart`
-   [ ] T015 [US1] Implement home list screen `lib/screens/home_screen.dart`
-   [ ] T016 [US1] Implement repository method `lib/repositories/borrowed_item_repository.dart` for `markReturned(id)`

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Quick mark returned)
4. STOP and VALIDATE: Test User Story 1 independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3/4 → Test independently → Deploy/Demo

---

## Task Summary

-   Total tasks: 38 (est.)
-   Tasks by story:
    -   Setup/Foundational: 12
    -   US1: 5
    -   US2: 7
    -   US3: 5
    -   US4: 4
    -   Polish: 5

**Validation**: All tasks follow the required checklist format and include file paths.
