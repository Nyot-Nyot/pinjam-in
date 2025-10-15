# Pinjam In

Proyek mata kuliah: Pemrograman Sistem Bergerak

Pinjam In adalah aplikasi sederhana untuk mencatat dan mengelola barang yang pernah dipinjamkan. Aplikasi ini dibuat sebagai tugas/portofolio untuk mata kuliah Pemrograman Sistem Bergerak (PSB). Tujuan utamanya adalah menyediakan antarmuka mobile untuk:

- Mencatat barang yang dipinjamkan beserta nama peminjam.
- Menandai item sebagai selesai/dikembalikan melalui kontrol geser khusus.
- Melihat detail tiap pinjaman (catatan, status keterlambatan, dll).

Repositori ini berisi seluruh kode sumber aplikasi Flutter (multi-platform) yang dibuat untuk keperluan pembelajaran.

Struktur singkat
- `lib/` — sumber kode Flutter (layar, model, logika UI).
- `android/`, `ios/`, `linux/`, `macos/`, `web/`, `windows/` — platform runner dan konfigurasi.
- `assets/` — aset gambar / ikon / svg yang digunakan aplikasi.
- `pubspec.yaml` — daftar dependensi dan konfigurasi paket Flutter.

Menjalankan aplikasi (pengembangan)
1. Pastikan Anda sudah menginstal Flutter dan Android/iOS toolchain sesuai dokumentasi resmi Flutter.
2. Dari direktori proyek, jalankan:

```fish
flutter pub get
flutter run
```

Catatan: beberapa plugin/platform native mungkin memerlukan konfigurasi tambahan saat menjalankan di desktop. Jika menerima error terkait plugin pada desktop (mis. `MissingPluginException`), coba jalankan pada emulator perangkat seluler atau lakukan `flutter clean` lalu `flutter pub get` dan rebuild.

Kontribusi
- Ini adalah repositori tugas kuliah; jika ingin mengembangkan lebih lanjut, buat branch baru dan ajukan pull request.

Lisensi
- File lisensi tidak disertakan secara eksplisit. Jika proyek ini akan dibagikan, tambahkan lisensi yang sesuai (mis. MIT) di file `LICENSE`.

Kontak
- Pemilik repo: Nyot-Nyot (lihat profil GitHub untuk kontak lebih lanjut).

Catatan teknis singkat
- UI menggunakan paket `google_fonts` dan beberapa aset SVG.
- Ada kontrol geser kustom pada tampilan Home untuk menandai item selesai; perubahan besar pada widget tersebut berisiko menimbulkan masalah layout jika diperbaiki tidak hati-hati.

---
Dokumentasi ini ringkas dan fokus pada penggunaan serta struktur. Jika Anda ingin, saya bisa menambahkan:
- CI GitHub Actions untuk `flutter analyze` dan `flutter test`.
- Panduan pengembangan lebih lengkap.

