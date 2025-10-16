# Pinjam In

Proyek mata kuliah: Pemrograman Sistem Bergerak

Pinjam In adalah aplikasi sederhana untuk mencatat dan mengelola barang yang pernah dipinjamkan. Aplikasi ini dibuat sebagai tugas/portofolio untuk mata kuliah Pemrograman Sistem Bergerak (PSB). Tujuan utamanya adalah menyediakan antarmuka mobile untuk:

-   Mencatat barang yang dipinjamkan beserta nama peminjam.
-   Menandai item sebagai selesai/dikembalikan melalui kontrol geser khusus.
-   Melihat detail tiap pinjaman (catatan, status keterlambatan, dll).

Repositori ini berisi seluruh kode sumber aplikasi Flutter (multi-platform) yang dibuat untuk keperluan pembelajaran.

### Struktur singkat

-   `lib/` — sumber kode Flutter (layar, model, logika UI).
-   `android/`, `ios/`, `linux/`, `macos/`, `web/`, `windows/` — platform runner dan konfigurasi.
-   `assets/` — aset gambar / ikon / svg yang digunakan aplikasi.
-   `pubspec.yaml` — daftar dependensi dan konfigurasi paket Flutter.

### Menjalankan aplikasi (pengembangan)

1. Pastikan Anda sudah menginstal Flutter dan Android/iOS toolchain sesuai dokumentasi resmi Flutter.
2. Dari direktori proyek, jalankan:

```fish
flutter pub get
flutter run
```

Catatan: beberapa plugin/platform native mungkin memerlukan konfigurasi tambahan saat menjalankan di desktop. Jika menerima error terkait plugin pada desktop (mis. `MissingPluginException`), coba jalankan pada emulator perangkat seluler atau lakukan `flutter clean` lalu `flutter pub get` dan rebuild.

### Kontribusi

-   Ini adalah repositori tugas kuliah; jika ingin mengembangkan lebih lanjut, buat branch baru dan ajukan pull request.

### Lisensi

-   File lisensi tidak disertakan secara eksplisit. Jika proyek ini akan dibagikan, tambahkan lisensi yang sesuai (mis. MIT) di file `LICENSE`.

### Catatan teknis singkat

-   UI menggunakan paket `google_fonts` dan beberapa aset SVG.
-   Ada kontrol geser kustom pada tampilan Home untuk menandai item selesai; perubahan besar pada widget tersebut berisiko menimbulkan masalah layout jika diperbaiki tidak hati-hati.

---

## Emulator & seeding (development)

Jika Anda ingin menjalankan aplikasi melawan Firebase Emulator set lokal, ikuti langkah ini:

1. Pastikan `firebase-tools` terpasang (`npm i -g firebase-tools`) dan Anda berada di root proyek.
2. Mulai emulator (Firestore, Storage, Auth):

```fish
npm run start:emulators
```

3. Di terminal lain, jalankan seeder untuk menulis dokumen contoh ke Firestore dan (opsional) membuat akun test di Auth emulator:

```fish
# tulis koleksi contoh
npm run seed

# buat user Auth via admin emulator endpoint (jika emulator Auth dapat dijangkau)
npm run seed:auth-admin

# atau jalankan keduanya berurutan
npm run seed:all
```

4. Catatan konektivitas:

-   Jika Anda menjalankan aplikasi pada Android emulator, host pada device dapat mengakses host machine via `10.0.2.2`. Anda dapat mem-passing host ke seeder jika perlu:

```fish
node scripts/seed_auth_admin.js --authHost 10.0.2.2:9099 --firestoreHost 10.0.2.2:8080
```

-   Jika seeder tidak dapat membuat akun Auth, periksa output `npm run start:emulators` untuk memastikan Auth emulator aktif dan perhatikan alamat host/port yang dilaporkan oleh emulator UI.

5. Setelah seeding selesai, buka Emulator UI pada http://localhost:4000 untuk memeriksa data dan akun.
