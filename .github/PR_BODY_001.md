Summary
- Introduces the feature specification and implementation plan for the Borrowed Items Manager (branch `001-borrowed-items-manager`).
- Documents user stories, acceptance criteria, data model, research notes, tasks (TDD-first), and constitution/gating checks.

What’s included (files)
- `specs/001-borrowed-items-manager/spec.md` — feature spec, user stories, requirements (FR-001..FR-010), success criteria.
- `specs/001-borrowed-items-manager/plan.md` — implementation plan, technical context, constitution/gates evaluation.
- `specs/001-borrowed-items-manager/tasks.md` — prioritized, test-first task list (T001..T038) with file paths and test tasks.
- `specs/001-borrowed-items-manager/research.md` — Phase 0 research decisions and open research tasks.
- `specs/001-borrowed-items-manager/data-model.md` — entities and validation rules.
- `specs/001-borrowed-items-manager/contracts/rest-endpoints.md` — high-level API contract (Supabase mapping).
- `specs/001-borrowed-items-manager/quickstart.md` — local dev notes and env guidance.
- `.specify/memory/constitution.md` — updated project constitution (code quality / testing / Figma MCP rules).
- `.github/copilot-instructions.md` — agent guidance update (dev tooling context).
- Creates placeholder `supabase/migrations/` directory (migration file placeholder referenced in tasks).

Why
- Creates a test-first, design-enforced foundation for the feature before any code is written.
- Makes implementation tasks, acceptance tests, and privacy/consent requirements explicit.

How to review
1. Read `specs/001-borrowed-items-manager/spec.md` for user stories, acceptance criteria and FRs.
2. Confirm the plan and gates in `plan.md` satisfy the updated constitution (tests, Figma, privacy).
3. Inspect `tasks.md` to ensure test tasks are present and prioritized correctly.
4. Validate data model (`data-model.md`) against FRs (fields, indexes, deletion/consent).
5. Check `research.md` for open decisions and whether any of those block implementation.

Testing / manual verification
- Checkout branch and inspect specs locally:
  - git checkout 001-borrowed-items-manager
  - Open the `specs/001-borrowed-items-manager/` docs in your editor
- There are no runtime code changes yet; tests referenced are tasks to be implemented during Phase 1/2.

Reviewer checklist (please tick before merge)
- [ ] Spec acceptance: user stories and FRs make sense and cover edge-cases
- [ ] Constitution gates: Test-First, Figma MCP rule, Performance & Privacy checks are adequate
- [ ] Files to add before implementation: a `.env.example` and non-secret config guidance present
- [ ] Migration placeholder confirmed (actual SQL still required before data-backed work)
- [ ] CI skeleton added or tracked (lint & tests to run in CI)
- [ ] No secrets accidentally committed

Next steps after merge (recommended)
- Implement Phase 1 + Phase 2 tasks: add `supabase/migrations/001_init.sql`, add `lib/services/supabase_service.dart`, stub tests, and CI workflow.
- Provide Figma links or design mocks for all screens; run MCP on designs when available.
- Resolve R001..R004 (research tasks) before heavy implementation (Supabase quotas, state-management choice, Android contact-picker package, offline sync prototype).

Recommended reviewers & labels
- Reviewers: design (for Figma/UX checks), backend/Supabase lead (for migration + quotas), mobile tech lead (for architecture + TDD expectations).
- Labels: spec, feature, docs, needs-design
