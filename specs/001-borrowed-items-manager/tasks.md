# Task Breakdown: Borrowed Items Manager

**Feature**: `001-borrowed-items-manager`
**Date**: 2025-10-21

This document breaks down the implementation of the Borrowed Items Manager feature into actionable, ordered tasks.

## Implementation Strategy

The strategy is to build the application in layers, starting with a solid foundation for authentication and data services, then implementing each user story as an independent, testable feature slice. This allows for incremental delivery and testing. The MVP will consist of User Stories 1, 2, and 3 (Add, View, and Mark as Returned).

## Phase 1: Project Setup & Configuration

These tasks set up the foundational structure of the project.

-   [ ] T001 Create project folder structure as defined in `plan.md`.
-   [ ] T002 Add dependencies (`supabase_flutter`, `flutter_riverpod`, `image_picker`, `flutter_contacts`) to `pubspec.yaml`.
-   [ ] T003 Initialize Supabase in `lib/main.dart` using credentials from environment variables.
-   [ ] T004 Set up basic app theme, colors, and typography in a `lib/src/core/theme` directory.
-   [ ] T005 Create a `lib/src/core/utils/router.dart` for app navigation (e.g., using GoRouter).

## Phase 2: Authentication (Foundational)

This phase implements the authentication layer, which is a prerequisite for all other features.

-   [ ] T006 [P] Create an `AuthRepository` interface in `lib/src/features/auth/domain/repositories/auth_repository.dart`.
-   [ ] T007 [P] Implement `AuthRepositoryImpl` in `lib/src/features/auth/data/repositories/auth_repository_impl.dart` to handle Supabase login, logout, and session state.
-   [ ] T008 [P] Create Riverpod providers for the auth repository and auth state stream in `lib/src/features/auth/presentation/manager/auth_providers.dart`.
-   [ ] T009 Create a `LoginPage` UI in `lib/src/features/auth/presentation/pages/login_page.dart` with email/password fields.
-   [ ] T010 Create a `SplashPage` in `lib/src/features/auth/presentation/pages/splash_page.dart` to redirect users based on auth state.
-   [ ] T011 Implement login and logout functionality, connecting the UI to the auth providers.

## Phase 3: User Story 1 - Add a New Borrowed Item

**Goal**: User can record a new item they have lent.

-   [ ] T012 [US1] Create the `Item` entity in `lib/src/features/borrowed_items/domain/entities/item.dart`.
-   [ ] T013 [US1] Create the `Item` model (for JSON serialization) in `lib/src/features/borrowed_items/data/models/item_model.dart`.
-   [ ] T014 [US1] Create an `ItemRepository` interface in `lib/src/features/borrowed_items/domain/repositories/item_repository.dart`.
-   [ ] T015 [US1] Implement `ItemRepositoryImpl` in `lib/src/features/borrowed_items/data/repositories/item_repository_impl.dart` with a `createItem` method.
-   [ ] T016 [US1] Create a `StorageService` in `lib/src/core/storage/storage_service.dart` to handle image uploads to Supabase Storage.
-   [ ] T017 [US1] Create Riverpod providers for the item repository and use cases in `lib/src/features/borrowed_items/presentation/manager/item_providers.dart`.
-   [ ] T018 [US1] Create the `AddItemPage` UI in `lib/src/features/borrowed_items/presentation/pages/add_item_page.dart` with all necessary form fields.
-   [ ] T019 [US1] Implement image picking functionality using `image_picker` and upload it via the `StorageService`.
-   [ ] T020 [US1] [P] Implement contact picking functionality on Android using `flutter_contacts`. For other platforms, provide a simple text input field for contact info.
-   [ ] T021 [US1] Connect the `AddItemPage` to the providers to save the new item to Supabase.

## Phase 4: User Story 2 - View the List of Borrowed Items

**Goal**: User can see all the items they have lent out.

-   [ ] T022 [US2] Add a `getItems` method to `ItemRepository` and its implementation to fetch items from Supabase.
-   [ ] T023 [US2] Create a `HomePage` UI in `lib/src/features/borrowed_items/presentation/pages/home_page.dart`.
-   [ ] T024 [US2] Use a `StreamProvider` in `lib/src/features/borrowed_items/presentation/manager/item_providers.dart` to provide a real-time list of items.
-   [ ] T025 [US2] Create an `ItemCard` widget in `lib/src/features/borrowed_items/presentation/widgets/item_card.dart` to display item details.
-   [ ] T026 [US2] Implement the list view on the `HomePage` to display `ItemCard` widgets for each borrowed item.
-   [ ] T027 [US2] [P] Implement search functionality on the `HomePage` to filter items by name or borrower.

## Phase 5: User Story 3 - Mark an Item as Returned

**Goal**: User can easily mark an item as returned.

-   [ ] T028 [US3] Add an `updateItemStatus` method to `ItemRepository` and its implementation.
-   [ ] T029 [US3] Wrap the `ItemCard` widget with a `Dismissible` or similar widget to detect a swipe gesture.
-   [ ] T030 [US3] On swipe, call the `updateItemStatus` method via the Riverpod provider to change the item's status to 'returned'.
-   [ ] T031 [US3] Ensure the UI automatically updates to remove the returned item from the main list.

## Phase 6: User Story 4, 5, 6 - Edit, Delete, and View Statistics

**Goal**: User can manage items and view statistics.

-   [ ] T032 [US4] [P] Add `updateItem` and `deleteItem` methods to `ItemRepository` and its implementation.
-   [ ] T033 [US4] Create an `EditItemPage` UI in `lib/src/features/borrowed_items/presentation/pages/edit_item_page.dart`.
-   [ ] T034 [US4] Implement the logic to update and delete items from a detail view.
-   [ ] T035 [US6] [P] Create a `StatsRepository` and implementation to calculate statistics from the `items` table.
-   [ ] T036 [US6] Create a `StatsPage` UI in `lib/src/features/stats/presentation/pages/stats_page.dart` to display the statistics.

## Phase 7: Testing & Polish

-   [ ] T037 Write unit tests for all repositories and providers.
-   [ ] T038 Write widget tests for `LoginPage`, `HomePage`, and `AddItemPage`.
-   [ ] T039 [P] Write integration tests for the "add item" and "mark as returned" flows.
-   [ ] T040 Review the entire application for UI polish, performance, and adherence to the constitution.

## Dependencies

-   **US2 (View List)** depends on **US1 (Add Item)** to have data to display.
-   **US3 (Mark Returned)** depends on **US2 (View List)** to have an item to swipe.
-   **US4/5 (Edit/Delete)** depends on **US2 (View List)** to select an item.
-   **US6 (Stats)** can be developed in parallel with other user stories after the foundational phase is complete.

## Parallel Execution

-   **Within US1**: Image picking (T019) and contact picking (T020) can be worked on in parallel.
-   **Across Stories**: Once the `ItemRepository` is established, work on the `StatsPage` (T036) can begin in parallel with the UI work for other stories.
-   **Testing**: Unit tests (T037) can be written in parallel with feature implementation.
