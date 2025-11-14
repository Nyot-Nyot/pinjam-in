## Analisis: Menambahkan Role "admin" ke Pinjam In

Dokumen ini merangkum hasil pemeriksaan kode sumber saat ini dan menjelaskan perubahan minimal yang diperlukan untuk menambahkan role "admin" pada aplikasi Pinjam In (Supabase backend + Flutter client).

Ringkasan implementasi saat ini

-   Backend: Supabase (tabel `items` di `sql/schema.sql`). Aplikasi menggunakan Row Level Security (RLS) agar setiap user hanya melihat/ubah data yang dimiliki.
-   Persistence: Aplikasi mendukung dua backend persistence:
    -   `SharedPrefsPersistence` untuk local (shared_preferences).
    -   `SupabasePersistence` untuk remote (Supabase) — implementasi ada di `lib/services/supabase_persistence.dart`.
-   Auth: dikelola lewat `supabase_flutter`. `AuthProvider` memanfaatkan `Supabase.instance.client` untuk login/register dan mendengarkan perubahan auth.
-   Model utama: `LoanItem` di `lib/models/loan_item.dart`.
-   Provider utama: `AuthProvider`, `PersistenceProvider`, `LoanProvider` (lihat `lib/providers/*`).

Dependensi penting

-   Lihat `pubspec.yaml`: `supabase_flutter`, `shared_preferences`, `provider`, `flutter_dotenv`, `uuid`, `http`, dsb.

Struktur DB yang relevan

-   `sql/schema.sql` mendefinisikan tabel `public.items` (kolom: id, user_id, name, borrower_name, photo_url, borrow_date, due_date, return_date, status, notes, created_at)
-   RLS policies saat ini membatasi semua operasi agar hanya auth.uid() == user_id saja (lihat file `sql/schema.sql`).

Area kode yang perlu diubah untuk menambahkan role `admin`

1. Database / schema & RLS

-   Tambahkan tabel `profiles` (atau `users_profiles`) di `public` untuk menyimpan metadata user (role). Contoh:

    ```sql
    CREATE TABLE IF NOT EXISTS public.profiles (
      id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
      full_name TEXT,
      role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user','admin')),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );
    ```

-   Alternatif: simpan role di `auth.users` metadata (lebih rumit dan kurang dianjurkan untuk RLS). `profiles` memberi kontrol yang jelas.

-   Perbarui RLS pada `public.items` supaya admin dapat membaca/menulis semua baris. Contoh policy (SELECT):

    ```sql
    DROP POLICY IF EXISTS "Allow users to view their own items" ON public.items;
    CREATE POLICY "Allow users to view own items or admins" ON public.items
      FOR SELECT USING (
        auth.uid() = user_id
        OR EXISTS (
          SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
        )
      );
    -- Serupa untuk INSERT/UPDATE/DELETE: WITH CHECK dan USING harus memperbolehkan admin
    ```

-   Jika ada bucket storage (item photos) yang RLS-nya bergantung pada folder name (menggunakan auth.uid()), pertimbangkan kebijakan storage tambahan agar admin dapat menghapus/melihat foto (atau sediakan fungsi server-side untuk admin actions).

2. Backend / Supabase layer

-   Tidak ada backend server tambahan; perubahan utama ada pada schema SQL dan RLS.
-   Jika Anda memakai service role key di server-side, hati-hati jangan masukkan ke client.

3. Flutter client

-   AuthProvider: setelah login, perlu mem-fetch profil user (SELECT dari `public.profiles WHERE id = current_user_id`) lalu expose `role` di provider. Contoh method:

    -   `Future<void> loadProfile()` — panggil setelah AuthProvider berhasil login.

-   Model user: tambahkan representasi `UserProfile { id, fullName, role }` atau simpan role sebagai string di `AuthProvider`.

-   Penyajian UI: tambahkan tampilan sederhana di `Settings/Profile` yang menampilkan role, dan conditionally show admin-only routes (mis. `Admin Dashboard`).

-   Permission checks: tambahkan check sebelum operasi sensitif di service layer (mis. di `SupabasePersistence.deleteItem` atau di `LoanProvider.deleteLoan`) untuk memungkinkan admin bypass. Namun jangan andalkan hanya client-side — RLS di DB harus menjadi sumber kebenaran.

Checklist migrasi minimal (SQL + client)

1. Tambah tabel `public.profiles` (migration SQL).
2. Isi `profiles` untuk existing users (migration script: set role = 'user' untuk semua current users; set at least one admin manually).
3. Update RLS policies di `sql/schema.sql` untuk memperbolehkan admin akses penuh (lihat contoh di atas).
4. Perbarui `lib/providers/auth_provider.dart` untuk mem-fetch `profiles` setelah login dan expose `role`.
5. Perbarui `lib/services/supabase_persistence.dart` bila perlu (mis. pengecualian pada operasi yang admin boleh lakukan, tapi DB RLS seharusnya cukup).
6. Tambah UI: di `screens/settings` atau `screens/profile` tampilkan role; buat `screens/admin_dashboard.dart` sederhana (list semua users / items) — awalnya read-only untuk demo.

Contoh SQL migration (kompak)

```sql
BEGIN;

-- 1) Profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user','admin')),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2) Default profiles for existing users (creates row with 'user')
INSERT INTO public.profiles (id, role)
SELECT id, 'user' FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 3) Update items RLS to include admins (example for SELECT)
DROP POLICY IF EXISTS "Allow users to view their own items" ON public.items;
CREATE POLICY "Allow users to view own items or admins" ON public.items
  FOR SELECT USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- Repeat analogous policies for INSERT/UPDATE/DELETE using WITH CHECK/USING

COMMIT;
```

Perubahan kode Flutter (detail yang disarankan)

-   `lib/providers/auth_provider.dart`

    -   Tambah state `String? role` atau `UserProfile? profile`.
    -   Setelah login sukses, lakukan query ke `profiles` table: `client.from('profiles').select().eq('id', user.id).maybeSingle()`.
    -   Simpan role ke provider dan panggil `notifyListeners()`.

-   `lib/models`

    -   (opsional) tambah `lib/models/user_profile.dart` untuk mem-serialize profile.

-   `lib/services/supabase_persistence.dart` / `LoanProvider`

    -   Tambahkan optional permission checks di client untuk UX, tetapi jangan hapus RLS server-side.

-   UI
    -   Tambah menu admin di `Drawer` atau di `Settings` (tampil hanya jika `authProvider.role == 'admin'`).
    -   Buat halaman `Admin Dashboard` minimal: list semua items (panggil persistence.loadActive tanpa filter atau gunakan dedicated RPC jika diperlukan) dan daftar users (select from `profiles`).

Pengujian & Quality gates

-   Tulis test unit untuk permission checks yang ditambahkan di client.
-   Jalankan `flutter analyze` dan `flutter test` sebelum merge.

Risiko & catatan

-   Pastikan RLS teruji; jika RLS salah konfigurasi, data bisa bocor.
-   Jangan menaruh service_role key di client.
-   Jika Anda ingin admin bisa mengelola foto yang berada di folder `user_id/...`, perlu kebijakan storage khusus atau endpoint server side yang dijalankan dengan service role.

Selanjutnya

-   Jika Anda setuju, saya bisa membuat migration SQL file penuh, menambahkan fetch profile di `AuthProvider`, dan menyiapkan sebuah halaman admin read-only sederhana di Flutter sebagai PR di branch ini.
