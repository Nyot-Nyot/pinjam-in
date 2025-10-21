# Implementation Plan: Borrowed Items Manager

**Branch**: `001-borrowed-items-manager` | **Date**: 2025-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/home/nyotnyot/Project/Kuliah/Semester_5/PSB/pinjam_in/specs/001-borrowed-items-manager/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.github/prompts/speckit.plan.prompt.md` for the execution workflow.

## Summary

This plan outlines the technical implementation for the Borrowed Items Manager feature. The application will be a Flutter-based Android app allowing users to track items they have lent. It will use Supabase for the database, authentication, and image storage. The core functionality includes creating, viewing, updating, and deleting borrowed item records, complete with photos and optional contact integration.

## Technical Context

**Language/Version**: Flutter (Dart SDK ^3.8.1)
**Primary Dependencies**: `supabase_flutter`, `image_picker`, `flutter_contacts` (for Android), `flutter_riverpod`
**Storage**: Supabase (PostgreSQL for data, Supabase Storage for images)
**Testing**: `flutter_test` (unit, widget), `integration_test`
**Target Platform**: Android (Primary), iOS (Secondary)
**Project Type**: Mobile
**Performance Goals**: 60 FPS for animations/scrolling, < 2s cold start, < 300ms warm navigation.
**Constraints**: Offline capability is not in the initial scope. All data interaction requires a network connection to Supabase.
**Scale/Scope**: Single-user application, data stored per user account. The app will handle up to ~50 screens as per the initial design.

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

-   **I. Code Quality**: **PASS**. The project will adhere to Flutter's recommended lints and idiomatic Dart.
-   **II. Test-First Development**: **PASS**. The plan will include tasks for writing unit and widget tests before implementation.
-   **III. UX Consistency & Figma MCP Integration**: **PASS (with note)**. No Figma designs are specified. The plan will assume the creation of mockups for review before UI implementation, following existing design system principles.
-   **IV. Performance Requirements**: **PASS**. The plan aligns with the performance goals outlined in the specification.
-   **V. Observability, Versioning & Release Quality**: **PASS (with note)**. The plan will include basic error handling. Structured logging and error reporting (e.g., Sentry) are recommended for future iterations but are not part of this initial plan.

## Project Structure

### Documentation (this feature)

```
specs/001-borrowed-items-manager/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── supabase_schema.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```
lib/
├── src/
│   ├── core/                # Core services, constants, and utilities
│   │   ├── auth/            # Authentication service
│   │   ├── database/        # Supabase client and services
│   │   └── storage/         # Supabase storage service
│   ├── features/
│   │   ├── auth/            # Login/Signup UI and state
│   │   ├── borrowed_items/  # Feature module for item management
│   │   │   ├── data/
│   │   │   │   ├── models/
│   │   │   │   └── repositories/
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   └── usecases/
│   │   │   └── presentation/
│   │   │       ├── manager/     # State management (e.g., BLoC, Riverpod)
│   │   │       ├── pages/
│   │   │       └── widgets/
│   │   └── stats/             # Statistics feature module
│   └── main.dart
└── test/
    ├── features/
    │   └── borrowed_items/
    │       ├── data/
    │       │   ├── models/
    │       │   └── repositories/
    │       └── presentation/
    │           └── manager/
    └── ...
```

**Structure Decision**: The project will follow a feature-driven architecture with a clear separation of layers (data, domain, presentation) to promote scalability and maintainability. This structure is well-suited for a Flutter application of this scope.

## Complexity Tracking

_No violations to the constitution were identified that require justification._
