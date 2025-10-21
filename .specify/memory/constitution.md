<!--
	Sync Impact Report
	- Version change: [UNSET] -> 1.0.0
	- Modified principles: (new constitution created)
	- Added sections: "Development Workflow" and "Additional Constraints" specific to Flutter + Figma MCP
	- Removed sections: none (template completed)
	- Templates requiring validation:
		- .specify/templates/plan-template.md -> ⚠ pending: update "Constitution Check" gates to reference the new Figma MCP and testing requirements
		- .specify/templates/spec-template.md -> ✅ updated (no file edits required; alignment noted)
		- .specify/templates/tasks-template.md -> ⚠ pending: ensure task examples reflect test-first and UX gating
	- Follow-ups / TODOs:
		- TODO(RATIFICATION_DATE): confirm formal ratification date if different from initial creation (2025-10-21).
		- TODO(CONTACTS): designate constitution owners/maintainers in repository settings.
-->

# pinjam_in Constitution

## Core Principles

### I. Code Quality (NON-NEGOTIABLE)

All code MUST be readable, maintainable, and reviewed. Enforced practices:

-   Use the project's linting and formatter rules (Flutter's recommended lints). Commits
    that fail linting MUST be fixed before merge.
-   Prefer small, focused PRs with descriptive commit messages and a clear scope.
-   Follow idiomatic Dart/Flutter patterns: null-safety, immutability where appropriate,
    and clear separation between UI, state, and data layers.
-   Public APIs and package interfaces MUST include documentation comments and an
    example where relevant.

Rationale: high code quality reduces cognitive load, prevents defects, and
facilitates future contribution. These rules are non-negotiable for main branch
acceptance.

### II. Test-First Development (NON-NEGOTIABLE)

Testing is required before implementation. Specifically:

-   Write failing tests first where feasible: unit tests for business logic, widget
    tests for UI components, and integration/contract tests for cross-layer flows.
-   CI MUST run the full test suite and refuse merges that introduce test regressions.
-   Coverage targets: aim for a minimum of 70% line coverage for core logic. For
    critical modules (auth, data integrity) aim for 90%+ and explicit contract tests.
-   Tests MUST be deterministic and fast; long-running or flaky tests must be
    quarantined or reworked with a clear improvement plan.

Rationale: Test-first enforces designs that are verifiable and reduces regressions
while supporting refactor safely.

### III. User Experience Consistency & Figma MCP Integration

UX consistency is mandatory. Design verification steps:

-   Before creating a new screen or significant UI change, the developer MUST ask
    whether an approved Figma design exists for that screen/flow.
    -   If a Figma design is available: execute the Figma MCP workflow to extract
        assets, specs, spacing, tokens, and component mappings. Document the MCP
        execution result and link it in the related spec or PR.
    -   If no Figma design is available: the implementer MAY create a design mock
        that aligns with the existing app design system. That mock MUST be
        reviewed by the project designer (or a designated reviewer) before final UI
        implementation.
-   All screens MUST use the shared design tokens (colors, typography, spacing)
    and accessible contrast ratios. Interactive elements MUST meet touch target
    recommendations and support localization (text length variations).
-   Naming conventions for assets and components MUST follow the repo's UI
    component guidelines; exported assets MUST be optimized for mobile.

Rationale: This ensures UI parity with design, consistent user experience, and
reduces rework between design and implementation. Figma MCP is the canonical
source when available.

### IV. Performance Requirements

Performance expectations and constraints for the mobile app:

-   App should target 60 FPS for core scroll and animation experiences on supported
    devices. Where 60 FPS is impractical, provide documented tradeoffs and target
    stable 30 FPS with no jank in common flows.
-   Cold start time (first screen visible) SHOULD be under 2 seconds on a typical
    mid-range device; warm navigation transitions SHOULD be under 300ms.
-   Memory: avoid excessive retained memory; large lists MUST be virtualized and
    images/cached data should be size-limited and compressed.
-   Establish measurable performance goals for major features (example: search
    response p95 < 200ms). Benchmarks and profiling reports MUST accompany
    performance-related PRs that claim improvements.

Rationale: Performance directly affects user satisfaction and retention. Clear
goals and measurements keep engineering tradeoffs explicit and measurable.

### V. Observability, Versioning & Release Quality

Release and runtime observability rules:

-   Use structured logging and an error reporting tool (e.g., Sentry). Errors
    SHOULD include contextual details (screen, user action) but MUST NOT log
    sensitive PII.
-   Follow semantic versioning for releases: MAJOR.MINOR.PATCH. Public API or
    significant behavior changes that may break clients MUST increment MAJOR and
    include a migration plan.
-   Release artifacts MUST include a changelog entry and a short migration note
    when applicable. Rollback criteria and a verification checklist MUST be
    provided for each production release.

Rationale: Observability enables quick triage; versioning and release discipline
protect users and integrators when changes are made.

## Additional Constraints

-   Technology stack: Flutter (Dart) is the canonical implementation platform for
    this project. Native platform code is allowed when required, but changes MUST
    be justified and reviewed.
-   Security and privacy: do not store sensitive data unencrypted; follow platform
    best practices for secure storage and network transport (TLS). If the project
    processes user-identifiable information, document retention and deletion
    policies.
-   Design tokens, component library, and accessibility checks are required for UI
    delivery. All strings MUST be prepared for localization.

## Development Workflow

-   Pull Requests
    -   Every PR MUST include a clear description, linked issue/spec, screenshots
        or recordings for UI changes, and test results.
    -   At least one approver other than the author is required. Critical changes
        (security, performance, privacy) MUST have two approvers, one of whom is a
        designated maintainer.
-   CI Gates
    -   Linting, formatting, and unit tests MUST pass before merge.
    -   Integration tests and UI tests (where present) MUST run in CI for feature
        branches prior to a release candidate build.
-   Backlog & Tasks
    -   Use the project's task templates. Tasks that touch UX MUST reference the
        Figma design or the created mock and the MCP output if applicable.

## Governance

-   Amendments: Changes to this constitution MUST be proposed in a PR that
    references the rationale, impact analysis, and a migration plan if needed.
    A simple majority of maintainers (or two designated maintainers) approval is
    required for non-breaking edits. Major governance changes (removing or
    redefining principles) require a MAJOR version bump and broader notification.
-   Versioning policy for the constitution itself:
    -   Initial release: 1.0.0
    -   PATCH: wording, typos, clarifications
    -   MINOR: adding a principle or materially expanding guidance
    -   MAJOR: removing or redefining principles or governance model
-   Compliance: every release or major PR SHOULD include a short "Constitution
    Check" section describing how it complies with the principles; the plan
    template's "Constitution Check" should be updated to reference the
    UX/Figma, testing, and performance gates.

**Version**: 1.0.0 | **Ratified**: 2025-10-21 | **Last Amended**: 2025-10-21
