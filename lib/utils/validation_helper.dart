/// Helper class for form validation.
/// Provides common validation functions used throughout the app.
class ValidationHelper {
  ValidationHelper._(); // Private constructor to prevent instantiation

  // ==================== Text Validation ====================

  /// Validate if a string is not empty after trimming whitespace.
  ///
  /// Returns true if the string is valid (not empty after trim).
  /// Returns false if null or empty.
  static bool isNotEmpty(String? value) {
    if (value == null) return false;
    return value.trim().isNotEmpty;
  }

  /// Validate if a string meets minimum length requirement.
  ///
  /// Returns true if the trimmed string length >= minLength.
  /// Returns false if null, empty, or too short.
  static bool hasMinLength(String? value, int minLength) {
    if (value == null) return false;
    return value.trim().length >= minLength;
  }

  /// Validate if a string meets maximum length requirement.
  ///
  /// Returns true if the trimmed string length <= maxLength.
  /// Returns false if null or too long.
  static bool hasMaxLength(String? value, int maxLength) {
    if (value == null) return true; // null is considered valid for max length
    return value.trim().length <= maxLength;
  }

  /// Validate if a string is within length range.
  ///
  /// Returns true if minLength <= trimmed length <= maxLength.
  static bool hasLengthInRange(String? value, int minLength, int maxLength) {
    if (value == null) return false;
    final length = value.trim().length;
    return length >= minLength && length <= maxLength;
  }

  // ==================== Email Validation ====================

  /// Basic email validation using regex pattern.
  ///
  /// Checks for basic email format: something@domain.extension
  /// Returns true if email format is valid.
  /// Returns false if null, empty, or invalid format.
  ///
  /// Note: This is a basic validation. For production apps, consider
  /// using email verification via backend.
  static bool isValidEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;

    // Basic email regex pattern
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    return emailRegex.hasMatch(email.trim());
  }

  /// Validate email with custom error message.
  ///
  /// Returns null if valid, error message string if invalid.
  /// Useful for TextFormField validator property.
  static String? validateEmail(
    String? email, {
    String? emptyMessage,
    String? invalidMessage,
  }) {
    if (email == null || email.trim().isEmpty) {
      return emptyMessage ?? 'Email tidak boleh kosong';
    }

    if (!isValidEmail(email)) {
      return invalidMessage ?? 'Format email tidak valid';
    }

    return null; // Valid
  }

  // ==================== Password Validation ====================

  /// Validate password meets minimum length requirement.
  ///
  /// Returns true if password length >= minLength.
  /// Default minimum length is 6 characters.
  static bool isValidPassword(String? password, {int minLength = 6}) {
    if (password == null) return false;
    return password.length >= minLength;
  }

  /// Validate password with custom error message.
  ///
  /// Returns null if valid, error message string if invalid.
  /// Useful for TextFormField validator property.
  static String? validatePassword(
    String? password, {
    int minLength = 6,
    String? emptyMessage,
    String? tooShortMessage,
  }) {
    if (password == null || password.isEmpty) {
      return emptyMessage ?? 'Password tidak boleh kosong';
    }

    if (password.length < minLength) {
      return tooShortMessage ?? 'Password minimal $minLength karakter';
    }

    return null; // Valid
  }

  /// Validate password confirmation matches original password.
  ///
  /// Returns null if matching, error message if not matching.
  static String? validatePasswordConfirmation(
    String? password,
    String? confirmation, {
    String? emptyMessage,
    String? notMatchMessage,
  }) {
    if (confirmation == null || confirmation.isEmpty) {
      return emptyMessage ?? 'Konfirmasi password tidak boleh kosong';
    }

    if (password != confirmation) {
      return notMatchMessage ?? 'Password tidak cocok';
    }

    return null; // Valid
  }

  // ==================== Item/Borrower Name Validation ====================

  /// Validate item name for loan items.
  ///
  /// Returns null if valid, error message string if invalid.
  /// Default minimum length is 3 characters.
  static String? validateItemName(
    String? name, {
    int minLength = 3,
    String? emptyMessage,
    String? tooShortMessage,
  }) {
    if (name == null || name.trim().isEmpty) {
      return emptyMessage ?? 'Nama barang tidak boleh kosong';
    }

    if (name.trim().length < minLength) {
      return tooShortMessage ?? 'Nama barang minimal $minLength karakter';
    }

    return null; // Valid
  }

  /// Validate borrower name.
  ///
  /// Returns null if valid, error message string if invalid.
  /// Default minimum length is 3 characters.
  static String? validateBorrowerName(
    String? name, {
    int minLength = 3,
    String? emptyMessage,
    String? tooShortMessage,
  }) {
    if (name == null || name.trim().isEmpty) {
      return emptyMessage ?? 'Nama peminjam tidak boleh kosong';
    }

    if (name.trim().length < minLength) {
      return tooShortMessage ?? 'Nama peminjam minimal $minLength karakter';
    }

    return null; // Valid
  }

  // ==================== Generic Text Validation ====================

  /// Generic required field validator.
  ///
  /// Returns null if valid, error message string if invalid.
  /// Useful for any required text field.
  static String? validateRequired(
    String? value, {
    String? fieldName,
    String? customMessage,
  }) {
    if (value == null || value.trim().isEmpty) {
      return customMessage ?? '${fieldName ?? 'Field'} tidak boleh kosong';
    }

    return null; // Valid
  }

  /// Generic minimum length validator.
  ///
  /// Returns null if valid, error message string if invalid.
  static String? validateMinLength(
    String? value,
    int minLength, {
    String? fieldName,
    String? customMessage,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Field'} tidak boleh kosong';
    }

    if (value.trim().length < minLength) {
      return customMessage ??
          '${fieldName ?? 'Field'} minimal $minLength karakter';
    }

    return null; // Valid
  }

  /// Generic maximum length validator.
  ///
  /// Returns null if valid, error message string if invalid.
  static String? validateMaxLength(
    String? value,
    int maxLength, {
    String? fieldName,
    String? customMessage,
  }) {
    if (value == null) return null; // null is valid for max length check

    if (value.trim().length > maxLength) {
      return customMessage ??
          '${fieldName ?? 'Field'} maksimal $maxLength karakter';
    }

    return null; // Valid
  }

  // ==================== Utility Methods ====================

  /// Trim whitespace from a string value.
  ///
  /// Returns trimmed string or null if input is null.
  static String? trim(String? value) {
    return value?.trim();
  }

  /// Check if a string is null or empty (after trimming).
  static bool isNullOrEmpty(String? value) {
    return value == null || value.trim().isEmpty;
  }

  /// Combine multiple validators.
  ///
  /// Executes validators in order and returns first error message found.
  /// Returns null if all validators pass.
  ///
  /// Example:
  /// ```dart
  /// validator: (value) => ValidationHelper.combineValidators(value, [
  ///   (v) => ValidationHelper.validateRequired(v, fieldName: 'Email'),
  ///   (v) => ValidationHelper.validateEmail(v),
  /// ]),
  /// ```
  static String? combineValidators(
    String? value,
    List<String? Function(String?)> validators,
  ) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) return error;
    }
    return null; // All validators passed
  }
}
