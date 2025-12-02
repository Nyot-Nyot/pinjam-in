# Phase A — Migration & RLS: Apply and Test

File: `sql/migrations/002_add_profiles_and_admin_rls.sql`

Berikut langkah-langkah yang perlu Anda lakukan secara manual di Supabase (atau di lingkungan Postgres Anda) untuk menerapkan migration dan menguji RLS. Saya sudah menambahkan file migration di `sql/migrations/002_add_profiles_and_admin_rls.sql` pada branch ini.

1. Backup (strongly recommended)

-   Sebelum menjalankan migration apapun di database produksi, lakukan backup snapshot/dump.

2. Apply migration

-   Buka Supabase project -> SQL Editor -> new query.
-   Paste seluruh isi file `sql/migrations/002_add_profiles_and_admin_rls.sql` dan jalankan.
-   Atau, dari terminal (psql):

    ```bash
    # contoh (sesuaikan):
    psql "postgresql://postgres:YOUR_PASSWORD@db.yourhost:5432/postgres" -f sql/migrations/002_add_profiles_and_admin_rls.sql
    ```

3. Seed admin user (manual)

-   Migration otomatis mengisi `profiles` default untuk semua `auth.users` dengan role='user'.
-   Pilih user yang ingin Anda jadikan admin dan jalankan di SQL editor:

    ```sql
    UPDATE public.profiles SET role = 'admin' WHERE id = '<USER_UUID>';
    -- OR insert if profile missing:
    INSERT INTO public.profiles (id, role) VALUES ('<USER_UUID>', 'admin') ON CONFLICT (id) DO UPDATE SET role = 'admin';
    ```

4. Verify RLS behavior (manual tests)

-   Quick smoke tests using the mobile app (recommended):

    -   Start app and login as a normal user A. Verify you only see your items.
    -   Login as admin user B (the one you promoted). Verify admin can see all items.

-   More robust test using API (optional):

    -   Use Supabase client from a quick Node/JS script or curl to call the REST endpoints with different access tokens.
    -   Example approach:
        1. Use Supabase Auth to sign in as user A and user B and obtain their access tokens.
        2. Call PostgREST endpoint (e.g. GET /rest/v1/items) with Authorization: Bearer <token>
        3. Confirm that user A's token returns only their items, while admin B's token returns all items.

-   Example PostgREST curl (replace values):

    ```bash
    curl -H "Authorization: Bearer <USER_TOKEN>" \
      -H "apikey: <ANON_KEY>" \
      "https://<project>.supabase.co/rest/v1/items?select=*"
    ```

5. Storage policy considerations

-   The project uses storage path conventions like `<user_id>/<itemId>_timestamp.jpg`.
-   Migration added storage policies that allow admin users to view/delete/insert objects in `item_photos` bucket.
-   If you prefer not to allow admins direct storage access, consider creating a server-side function (Edge Function or server) that performs admin-only storage operations using the service role key.

6. Troubleshooting

-   If after migration users suddenly see no data: check `public.items` RLS and ensure policies are enabled and correct.
-   In Supabase SQL editor you can run queries as service role; to simulate user behavior, use the app or call the REST API with a user token.

7. Post-migration housekeeping

-   Add tests or scripts that verify one admin exists.
-   Consider adding an admin UI to promote/demote users (we'll implement next in client phase).

If Anda mau, saya bisa lanjutkan dan membuat perubahan client-side (AuthProvider fetch profile + model + tests) di branch ini. Pilih saja agar saya lanjut mengerjakan otomatis di repo.
