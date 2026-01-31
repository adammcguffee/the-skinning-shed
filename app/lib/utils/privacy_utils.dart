/// Privacy utilities for sanitizing user-facing data.
/// 
/// These utilities ensure sensitive information like email addresses
/// are never accidentally displayed to users.

/// Check if a string looks like an email address.
/// Used to prevent accidental email display in usernames/display names.
bool looksLikeEmail(String? value) {
  if (value == null || value.isEmpty) return false;
  // Check for email-like pattern: contains @ and a domain suffix
  final hasAt = value.contains('@');
  final hasDomainSuffix = RegExp(
    r'\.(com|net|org|edu|gov|io|co|me|info|biz|us|uk|ca|au|de|fr|es|it|nl|ru|cn|jp|br|in|za|mil|int)$',
    caseSensitive: false,
  ).hasMatch(value);
  return hasAt && hasDomainSuffix;
}

/// Sanitize a display value to never show emails.
/// Returns null if the value looks like an email, otherwise returns the value.
String? sanitizeDisplayValue(String? value) {
  if (value == null || value.isEmpty) return null;
  if (looksLikeEmail(value)) return null; // Never display email-like strings
  return value;
}

/// Get a safe display name from display_name and username.
/// Never returns an email address - falls back to defaultName if both are email-like or empty.
String getSafeDisplayName({
  String? displayName,
  String? username,
  String defaultName = 'User',
}) {
  // Try display name first, then username
  final safeName = sanitizeDisplayValue(displayName) ?? sanitizeDisplayValue(username);
  return safeName ?? defaultName;
}

/// Get a safe handle from username.
/// Returns @username if username is valid, empty string if username looks like email or is empty.
String getSafeHandle(String? username) {
  final safeUsername = sanitizeDisplayValue(username);
  return safeUsername != null ? '@$safeUsername' : '';
}
