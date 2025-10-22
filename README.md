# Pinjam In

Proyek mata kuliah: Pemrograman Sistem Bergerak

Pinjam In adalah aplikasi mobile untuk mencatat dan mengelola barang yang dipinjamkan. Aplikasi ini dibuat sebagai tugas/portofolio untuk mata kuliah Pemrograman Sistem Bergerak (PSB).

## ✨ Fitur Utama

-   Mencatat barang yang dipinjamkan beserta informasi peminjam
-   Set tanggal target pengembalian dengan date picker
-   Upload foto barang (dengan crop & preview)
-   Integrasi dengan kontak perangkat
-   Tandai item sebagai selesai/dikembalikan dengan gesture swipe
-   Riwayat pinjaman yang telah dikembalikan
-   Pencarian barang dan peminjam
-   Autentikasi user dengan Supabase
-   Sinkronisasi data dengan cloud (Supabase)
-   Mode offline dengan SharedPreferences fallback

## 🏗️ Struktur Proyek

```
pinjam_in/
├── lib/                      # Source code Flutter
│   ├── models/              # Data models (LoanItem)
│   ├── screens/             # UI screens (8 screens)
│   ├── services/            # Business logic & persistence
│   ├── theme/               # App theming (colors, fonts)
│   ├── utils/               # Utility functions (logger, helpers)
│   └── widgets/             # Reusable UI components
├── assets/                  # Gambar, icons, dan aset lainnya
├── android/                 # Android native code
├── ios/                     # iOS native code
├── linux/                   # Linux desktop native code
├── macos/                   # macOS desktop native code
│   └── web/                     # Web platform
├── windows/                 # Windows desktop native code
├── server/                  # Optional: External upload server (Node.js)
├── functions/               # Optional: Supabase Edge Functions
├── sql/                     # Database schemas & migrations
│   ├── schema.sql          # Main Supabase schema
│   ├── SCHEMA_DOCS.md      # Schema documentation
│   └── migrations/         # Database migration scripts
└── pubspec.yaml            # Dependencies & project config
```

## 🚀 Menjalankan Aplikasi

### Prerequisites

-   Flutter SDK (3.8.1 atau lebih baru)
-   Dart SDK (3.8.1 atau lebih baru)
-   Android Studio / Xcode (untuk mobile development)
-   Git

### Setup & Installation

1. **Clone repository**

```bash
git clone https://github.com/Nyot-Nyot/pinjam-in.git
cd pinjam-in
```

2. **Install dependencies**

```bash
flutter pub get
```

3. **Setup environment variables** (Optional - untuk Supabase)

Buat file `.env` di root project:

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_UPLOAD_SERVER=http://localhost:3000
```

4. **Run aplikasi**

```bash
# Run di emulator/device
flutter run

# Run di platform spesifik
flutter run -d linux
flutter run -d chrome
```

## 🛠️ Tech Stack

-   **Framework**: Flutter 3.8.1
-   **State Management**: Manual setState (refactoring to Provider planned)
-   **Backend**: Supabase (Auth, Database, Storage)
-   **Local Storage**: SharedPreferences
-   **Image Handling**: image_picker, image, file_picker
-   **UI**: Material Design with custom theme
-   **Fonts**: Google Fonts (Arimo)

## 📦 Dependencies Utama

-   `supabase_flutter` - Backend as a Service
-   `flutter_dotenv` - Environment variables
-   `google_fonts` - Custom fonts
-   `image_picker` - Camera & gallery access
-   `flutter_contacts` - Device contacts integration
-   `shared_preferences` - Local data persistence
-   `uuid` - Generate unique IDs

## 🗄️ Database Schema

Aplikasi menggunakan Supabase PostgreSQL dengan tabel `items`:

-   `id` (UUID) - Primary key
-   `user_id` (UUID) - Foreign key to auth.users
-   `name` (TEXT) - Nama barang
-   `borrower_name` (TEXT) - Nama peminjam
-   `borrower_contact_id` (TEXT) - Contact ID (optional)
-   `borrow_date` (TIMESTAMPTZ) - Tanggal dipinjam
-   `due_date` (DATE) - Target tanggal kembali
-   `return_date` (DATE) - Tanggal dikembalikan
-   `status` (TEXT) - 'borrowed' | 'returned'
-   `notes` (TEXT) - Catatan tambahan
-   `photo_url` (TEXT) - URL foto barang
-   `created_at` (TIMESTAMPTZ) - Timestamp created

Lihat `sql/schema.sql` untuk detail lengkap.

## 🧪 Development

### Run tests

```bash
flutter test
```

### Analyze code

```bash
flutter analyze
```

### Format code

```bash
dart format .
```

## 📝 Catatan Development

-   **Desktop Support**: Beberapa plugin native (image_picker, contacts) memerlukan konfigurasi tambahan untuk desktop. Gunakan emulator mobile untuk full functionality.
-   **File Picker di Linux**: Memerlukan `zenity` package. Install dengan: `sudo apt install zenity`
-   **Offline Mode**: Aplikasi dapat berjalan offline menggunakan SharedPreferences, namun fitur upload gambar dan sinkronisasi memerlukan koneksi internet.

## 🎯 Roadmap & Refactoring

Lihat file `REFACTORING_TASK.md` untuk rencana refactoring dan improvement yang sedang dilakukan.

## 👥 Kontribusi

Ini adalah repositori tugas kuliah. Jika ingin mengembangkan lebih lanjut:

1. Fork repository
2. Buat branch baru (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push ke branch (`git push origin feature/AmazingFeature`)
5. Buat Pull Request

## 📄 Lisensi

Project ini dibuat untuk keperluan akademik. Belum ada lisensi formal yang diterapkan.

## 📧 Kontak

-   Mata Kuliah: Pemrograman Sistem Bergerak (PSB)
-   Semester: 5

---

**Last Updated**: 22 Oktober 2025
