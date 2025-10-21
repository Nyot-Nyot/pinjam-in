# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Flutter (Dart) — target SDK matching repository (Dart SDK ^3.8.1).
**Primary Dependencies**: Supabase client for Flutter, image picker / camera packages, contact_picker (Android), state management (to be chosen), flutter_test and widget testing libraries.
**Storage**: Supabase (Postgres) on free tier for structured data; Supabase Storage for media (photos).
**Testing**: Unit tests (Dart test), widget tests, and integration/e2e tests (integration_test or driver).
**Target Platform**: Mobile (Android + iOS), with Android-specific contact picker integration.
**Project Type**: Mobile app with backend-as-a-service (Supabase).
**Performance Goals**: 60 FPS for core scrolling; cold start < 2s on mid-range devices; search perceived instant for typical lists (see constitution).
**Constraints**: Supabase free tier limitations (storage quota, request limits) — design for modest dataset sizes and offline-first resilience.
**Scale/Scope**: Expected single-user datasets per account (thousands of items), optional sync across user's devices via Supabase auth + storage.

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

The following gates are derived from the project constitution and MUST be considered for Phase 0 acceptance:

-   Test-First: All features in plan MUST include test tasks (unit/widget/integration) and CI must be configured to run them. Any deviation requires justification.
-   Figma MCP: UI screens must reference an existing Figma design. If a design exists, include the MCP output link in the spec; if not, include a design mock and reviewer acceptance task.
-   Performance: Document measurable performance goals for list rendering, swipe responsiveness, and image handling; any feature claiming performance improvements MUST include a profiling report.
-   Privacy & Consent: Contact picker usage and cloud photo storage MUST be consented; include a data deletion UI for stored PII.

If any of the gates are violated by the plan, the violation MUST be justified in Complexity Tracking with alternatives considered.

### Constitution Check Evaluation (Phase 0)

-   Test-First: PASS — plan includes test tasks (unit/widget/integration) to be added to tasks.md during Phase 2.
-   Figma MCP: PARTIAL — UI will reference Figma when available; where no design exists a mock must be created and a designer review task added.
-   Performance: PASS (designated goals established in Technical Context and constitution) — profiling tasks required for image handling and list rendering.
-   Privacy & Consent: PASS — contact picker and cloud photo storage are explicitly consent-driven and a deletion UI requirement was added (FR-010).

No gate violations block Phase 0 research. Continue to Phase 1.

## Project Structure

### Documentation (this feature)

```
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```
# [REMOVE IF UNUSED] Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]
```

**Structure Decision**: Mobile + API (Supabase). Use the repository root Flutter app (existing) and a `specs/*` directory for design artifacts. There is no custom backend in repo; use Supabase as the backend service.

## Complexity Tracking

_Fill ONLY if Constitution Check has violations that must be justified_

| Violation                  | Why Needed         | Simpler Alternative Rejected Because |
| -------------------------- | ------------------ | ------------------------------------ |
| [e.g., 4th project]        | [current need]     | [why 3 projects insufficient]        |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient]  |
