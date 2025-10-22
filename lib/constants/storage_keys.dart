/// Storage keys for SharedPreferences and Supabase Storage.
/// Centralizes all key strings used for data persistence.
class StorageKeys {
  StorageKeys._(); // Private constructor to prevent instantiation

  // ==================== SharedPreferences Keys ====================
  /// Key for storing active loan items in local storage (version 1).
  static const String activeLoansKey = 'loan_active_v1';

  /// Key for storing historical loan items in local storage (version 1).
  static const String historyLoansKey = 'loan_history_v1';

  // ==================== Supabase Storage Buckets ====================
  /// Bucket name for storing item photos in Supabase Storage.
  /// This bucket should be created in your Supabase project with appropriate
  /// policies (public read or authenticated access).
  static const String imagesBucket = 'item_photos';

  // ==================== Supabase Table & Column Names ====================
  /// Table name for loan items in Supabase database.
  static const String itemsTable = 'items';

  /// Column names for the items table.
  static const String columnId = 'id';
  static const String columnUserId = 'user_id';
  static const String columnName = 'name';
  static const String columnBorrowerName = 'borrower_name';
  static const String columnBorrowerContactId = 'borrower_contact_id';
  static const String columnBorrowDate = 'borrow_date';
  static const String columnReturnDate = 'return_date';
  static const String columnStatus = 'status';
  static const String columnNotes = 'notes';
  static const String columnPhotoUrl = 'photo_url';
  static const String columnCreatedAt = 'created_at';

  // ==================== Environment Variable Keys ====================
  /// Environment variable key for Supabase URL.
  static const String envSupabaseUrl = 'SUPABASE_URL';

  /// Environment variable key for Supabase anonymous key.
  static const String envSupabaseAnonKey = 'SUPABASE_ANON_KEY';

  /// Environment variable key for optional upload server URL.
  static const String envUploadServerUrl = 'SUPABASE_UPLOAD_SERVER';
}
