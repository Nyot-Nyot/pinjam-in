# Sprint Planning: Add Admin Role

Tanggal: 13 November 2025

Tujuan: Menambahkan satu role baru `admin` ke aplikasi Pinjam In. Role ini memungkinkan satu atau lebih pengguna (dosen, pengelola, atau pemilik aplikasi) untuk melihat dan mengelola seluruh data instance aplikasi untuk keperluan demo, penilaian, dan administrasi.

Ringkasan perubahan teknis yang diusulkan
- Database: tambah kolom `role` pada tabel `users`. Default untuk pengguna eksisting: `user`.
- Auth / Policies (Supabase): gunakan `role` di profil pengguna untuk Row Level Security (RLS). Buat policy yang memperbolehkan `admin` mengakses semua baris.
- Backend / Services: perbarui model `User` di Flutter, provider/repository permission checks, dan gunakan pengecekan role di service layer sebelum operasi sensitif.
- UI: tampilkan badge role di halaman `Profile`; buat halaman sederhana `Admin Dashboard` (statistik singkat, daftar users, export CSV) — bisa ditandai `dev-only` untuk sekarang.
- Migration: contoh SQL migration ditambahkan di bawah.

Detail desain & rationale

1) Data model
- `users` table: tambah kolom `role TEXT NOT NULL DEFAULT 'user'`.
- Rationale: sederhana, mudah di-query, dan cocok untuk klaim token minimal.

2) Supabase / RLS
- Simpan `role` di table `profiles` atau `users` (sesuaikan skema repo); atur RLS policy contoh:

  -- Allow admins to select/insert/update/delete any row
  CREATE POLICY "admins_full_access" ON items
    USING ( auth.role() = 'admin' )
    WITH CHECK ( auth.role() = 'admin' );

  -- For non-admins: allow owners to modify their own items
  CREATE POLICY "owners_modify_own" ON items
    USING ( user_id = auth.uid() )
    WITH CHECK ( user_id = auth.uid() );

  (Catatan: Supabase tidak memiliki `auth.role()` built-in — biasanya role disimpan di table `profiles` dan kebijakan akan memeriksa value itu melalui `current_setting('request.jwt.claims')` atau menggunakan `auth.uid()` bersama join; file `sql/schema.sql` perlu disesuaikan dengan pendekatan yang dipilih.)

3) Flutter app changes (high level)
- Model: `lib/models/user.dart` — tambahkan field `role` (String).
- Provider/Repository: saat memanggil update/delete item, cek:
  - if (currentUser.role == 'admin') allow
  - else allow only when item.userId == currentUser.id
- UI: `lib/screens/profile_screen.dart` — tampilkan role; `lib/screens/admin_dashboard.dart` (baru) — minimal: daftar pengguna, jumlah items, tombol export.

4) Migration SQL (contoh)

-- 1. add role column
ALTER TABLE users
  ADD COLUMN role TEXT NOT NULL DEFAULT 'user';

-- 2. (opsional) create admin user
INSERT INTO users (id, email, role, created_at)
VALUES ('<UUID-ADMIN>', 'admin@example.com', 'admin', now());

5) Testing
- Unit tests: permission checks (user vs admin) di service layer
- Integration test (manual): create admin account, verify admin dapat mengedit item milik user lain

Sprint plan (3 iterasi, sprint length 1 minggu each) — fokus: deliverable minimal + polish

Sprint 1 (3-4 hari) - Core role & migration
- Tasks:
  - DB migration: add `role` column (0.5d)
  - Update backend (if any) / Supabase policies draft (0.5d)
  - Update Flutter model & provider to include `role` (0.5d)
  - Permission checks in service layer (1d)
  - Basic UI: show role in Profile (0.5d)
  - Manual test + doc (0.5d)

Deliverable: Migration SQL, app accepts role, owner vs admin checks enforced locally.

Sprint 2 (3-5 hari) - Admin UI & policies
- Tasks:
  - Implement `Admin Dashboard` (list users + counts) (1.5d)
  - RLS policies in Supabase and testing (1d)
  - Add admin creation flow / seed admin (0.5d)
  - Export CSV helper & small UI (0.5d)
  - Tests & review (0.5d)

Deliverable: Admin UI + server-side RLS enforcing admin privileges.

Sprint 3 (2-3 hari) - Polish & docs
- Tasks:
  - Role management UI: promote/demote users (1d)
  - Add audit log entry when admin performs critical action (0.5d)
  - E2E test scenario & final docs (0.5-1d)

Deliverable: Full workflow for admin, docs, and tests.

Backlog (nice-to-have)
- Group/household support (future)
- Delegation/temporary approver
- Audit UI with filters and export

Issues / To-do items (breakdown actionable tasks)

- DOCS: Add this sprint planning file (this document) — 0.25d
- MIGRATION: SQL migration to add `role` column — 0.5d
- MODEL: Add `role` to Flutter `User` model and parsing from Supabase response — 0.5d
- SERVICE: Add `isAdmin` helper & permission checks in repository `items_repository.dart` — 1d
- UI: Show role in Profile screen — 0.5d
- UI: Admin Dashboard (list users + counts) — 1.5d
- RLS: Write and apply Supabase RLS policies — 1d
- SEED: Add script or migration to create initial admin account — 0.25d
- EXPORT: CSV export for admin — 0.5d
- TESTS: Unit tests for permission checks — 0.5d
- QA: Manual test plan + checklist — 0.25d

Estimate total: ~8–11 days (rough) across 3 sprints, can be compressed.

Appendix: ready-to-create GitHub Issue templates

-- Issue: DB migration - add role
Title: feat(db): add `role` column to `users`
Body:
Summary: Add a non-null `role` column (default 'user') to `users` table. Include migration SQL and seed admin example.
Estimated: 0.5d

-- Issue: Flutter model & provider
Title: feat(app): add `role` field to User model and provider
Body: Update model, parsing, and persist role in user provider; add `isAdmin` helper. Update tests.
Estimated: 0.5d

-- Issue: Permission checks in services
Title: feat(app): enforce admin permission checks in ItemsRepository
Body: Implement check so admin can access all items; non-admin can access own items only.
Estimated: 1d

-- Issue: Admin Dashboard UI
Title: feat(ui): add Admin Dashboard (users, stats, export)
Body: Minimal dashboard for admin to view users and item counts, export CSV.
Estimated: 1.5d

-- Issue: Supabase RLS policies
Title: infra(supabase): create and test RLS policies for admin and owner
Body: Add RLS policies so admin can CRUD all items, owner only their items.
Estimated: 1d

---

Catatan implementasi
- Saya membuat branch lokal dan commit file ini (opsional: push ke remote). Jika Anda ingin, saya bisa lanjut membuat GitHub issues secara otomatis—tapi itu membutuhkan akses token/izin. Saya akan mencoba aktifkan GitHub MCP untuk membuat issue berikutnya.

---

Completion checklist (saat sprint selesai)
- [ ] Migration applied in staging
- [ ] Admin seeded
- [ ] App updated and tested
- [ ] Supabase RLS policies enabled and verified
- [ ] Admin UI available in release build
