/// Application-wide constants for consistent values across the app.
/// This file contains magic numbers, durations, sizes, and text strings
/// that are used throughout the application.
class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  // ==================== Animation Durations ====================
  static const Duration splashDuration = Duration(milliseconds: 2000);
  static const Duration pageTransitionDuration = Duration(milliseconds: 350);
  static const Duration quickTransitionDuration = Duration(milliseconds: 300);
  static const Duration animationDuration = Duration(milliseconds: 900);
  static const Duration searchDebounceDuration = Duration(milliseconds: 200);
  static const Duration snackBarDuration = Duration(seconds: 5);
  static const Duration snackBarShortDuration = Duration(seconds: 3);
  static const Duration snackBarLongDuration = Duration(seconds: 6);
  static const Duration hapticFeedbackDelay = Duration(milliseconds: 120);
  static const Duration dialogTransitionDuration = Duration(milliseconds: 260);

  // ==================== Spacing & Sizes ====================
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing10 = 10.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  // Border Radius
  static const double borderRadius12 = 12.0;
  static const double borderRadius16 = 16.0;
  static const double borderRadius20 = 20.0;
  static const double borderRadius999 = 999.0; // For pill-shaped containers

  // Icon Sizes
  static const double iconSize20 = 20.0;
  static const double iconSize22 = 22.0;
  static const double iconSize24 = 24.0;

  // Input Heights
  static const double inputHeight48 = 48.0;
  static const double inputHeight56 = 56.0;

  // Image Sizes
  static const double imageMaxWidth = 1600.0;
  static const double overdueIndicatorSize = 14.0;

  // ==================== Text Strings ====================
  // App Name
  static const String appName = 'Pinjam In';

  // Screen Titles
  static const String titleActiveLoan = 'Pinjaman Aktif';
  static const String titleHistory = 'Riwayat';
  static const String titleAddItem = 'Tambah Barang';
  static const String titleEditItem = 'Edit Barang';

  // Button Labels
  static const String buttonSave = 'Simpan';
  static const String buttonCancel = 'Batal';
  static const String buttonDelete = 'Hapus';
  static const String buttonEdit = 'Edit';
  static const String buttonAdd = 'Tambah';
  static const String buttonConfirm = 'Konfirmasi';
  static const String buttonUndo = 'Undo';
  static const String buttonLogout = 'Logout';
  static const String buttonLogin = 'Masuk';
  static const String buttonRegister = 'Daftar';
  static const String buttonRestore = 'Kembalikan';
  static const String buttonAddItem = 'Tambah Barang';

  // Form Labels
  static const String labelItemName = 'Nama Barang';
  static const String labelBorrowerName = 'Nama Peminjam';
  static const String labelContact = 'Kontak';
  static const String labelContactOptional = 'Kontak (opsional)';
  static const String labelBorrowerInfo = 'Informasi Peminjam';
  static const String labelDueDate = 'Tanggal Target Kembali';
  static const String labelReturnOn = 'Dikembalikan pada';
  static const String labelNote = 'Catatan';
  static const String labelNoteOptional = 'Catatan (opsional)';
  static const String labelEmail = 'Email';
  static const String labelPassword = 'Password';
  static const String labelConfirmPassword = 'Konfirmasi Password';

  // Placeholders
  static const String placeholderItemName = 'Contoh: Power Bank Hitam';
  static const String placeholderBorrowerName = 'Contoh: Budi Santoso';
  static const String placeholderContact = 'Nomor telepon atau nama kontak';
  static const String placeholderNote =
      'Tambahkan catatan khusus (mis. kondisi barang, dll)';
  static const String placeholderSearch = 'Cari barang atau nama peminjam';
  static const String placeholderDateNotSet = 'Belum diatur';

  // Messages
  static const String messageNoItemsYet = 'Belum Ada Barang';
  static const String messageNoItemsDescription =
      'Belum ada barang yang dipinjamkan.\nTambahkan barang pertama Anda!';
  static const String messageNoResults = 'Tidak ada barang yang cocok';
  static const String messageNoResultsDescription =
      'Tidak ada barang yang cocok\ndengan pencarian Anda.';
  static const String messageNoHistory = 'Belum Ada Riwayat';
  static const String messageNoHistoryDescription =
      'Semua barang yang sudah dikembalikan\nakan muncul di sini.';
  static const String messageItemMovedToHistory =
      'dipindahkan ke Riwayat'; // Used with item title
  static const String messageItemDeleted = 'dihapus permanen';
  static const String messageItemRestored = 'dipulihkan ke Pinjaman Aktif';
  static const String messageLogoutConfirm = 'Apakah Anda yakin ingin keluar?';
  static const String messageDeleteConfirm =
      'Item ini akan dihapus permanen.\nApakah Anda yakin?';
  static const String messageUnsavedChanges =
      'Ada perubahan yang belum disimpan.\nApakah Anda yakin ingin keluar?';

  // Error Messages
  static const String errorItemNameRequired = 'Nama barang wajib diisi';
  static const String errorBorrowerNameRequired = 'Nama peminjam wajib diisi';
  static const String errorItemNameTooShort = 'Nama barang minimal 3 karakter';
  static const String errorBorrowerNameTooShort =
      'Nama peminjam minimal 3 karakter';
  static const String errorSaveFailed = 'Gagal menyimpan data';
  static const String errorLoadFailed = 'Gagal memuat data';
  static const String errorUploadFailed = 'Gagal mengunggah gambar';
  static const String errorDeleteFailed = 'Gagal menghapus item';
  static const String errorLoginFailed = 'Gagal login';
  static const String errorLogoutFailed = 'Gagal logout';
  static const String errorAuthRequired =
      'Tidak terautentikasi. Silakan login untuk menyinkronkan data.';

  // Info Messages
  static const String infoItemsCount = 'barang sedang dipinjamkan';
  static const String infoOverdue = 'terlambat';
  static const String infoDaysRemaining = 'hari lagi';
  static const String infoDaysOverdue = 'hari terlambat';

  // Date Presets (in days)
  static const int datePresetThreeDays = 3;
  static const int datePresetOneWeek = 7;
  static const int datePresetTwoWeeks = 14;
  static const int datePresetOneMonth = 30;

  // Validation Limits
  static const int minItemNameLength = 3;
  static const int minBorrowerNameLength = 3;
  static const int minPasswordLength = 6;

  // Pagination & Limits
  static const int maxActiveItemsQuery = 100;
  static const int maxHistoryItemsQuery = 200;

  // Status Values
  static const String statusActive = 'active';
  static const String statusBorrowed = 'borrowed';
  static const String statusReturned = 'returned';
  static const String statusDeleted = 'deleted';

  // Platform Messages
  static const String platformPickerUnavailable = 'Picker foto tidak tersedia';
  static const String platformZenityMissing =
      'Pilih foto gagal karena utilitas "zenity" tidak ditemukan di sistem.';
  static const String platformZenityInstall =
      'Di sebagian besar distribusi Linux, Anda bisa menginstalnya dengan:\n\nsudo apt install zenity\n\natau perintah serupa sesuai package manager distro Anda.';
}
