/// Parses server timestamps for display.
///
/// `timestamp without time zone` values are stored in UTC but returned without
/// a `Z` suffix. [DateTime.parse] would treat them as local time and break
/// relative labels (e.g. "3h ago").
DateTime parseServerTimestamp(dynamic value) {
  if (value == null) return DateTime.now().toUtc();
  if (value is DateTime) return value.toUtc();

  final s = value.toString().trim();
  if (s.isEmpty) return DateTime.now().toUtc();

  final hasOffset = s.endsWith('Z') ||
      RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s) ||
      RegExp(r'[+-]\d{4}$').hasMatch(s);

  if (hasOffset) {
    return DateTime.parse(s).toUtc();
  }

  final parsed = DateTime.parse(s);
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}
