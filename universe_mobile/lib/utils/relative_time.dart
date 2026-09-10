/// Shared relative-timestamp formatting — "5 seconds ago", "30 minutes
/// ago", "5 hours ago", falling back to a real date once it's more than
/// a week old. One function, used everywhere a timestamp shows (Feed,
/// Anonymous, Messages, notifications, etc.) instead of each screen
/// formatting dates its own way.
String formatRelativeTime(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);

  if (diff.inSeconds < 5) return 'just now';
  if (diff.inSeconds < 60) return '${diff.inSeconds} seconds ago';
  if (diff.inMinutes < 60) {
    return diff.inMinutes == 1 ? '1 minute ago' : '${diff.inMinutes} minutes ago';
  }
  if (diff.inHours < 24) {
    return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
  }
  if (diff.inDays < 7) {
    return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
  }

  // Older than a week: a real date is more useful than "52 weeks ago".
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final sameYear = time.year == now.year;
  return sameYear
      ? '${months[time.month - 1]} ${time.day}'
      : '${months[time.month - 1]} ${time.day}, ${time.year}';
}

/// Convenience overload for the common case of formatting an ISO string
/// straight from an API response, with a safe fallback if it's missing
/// or unparseable.
String formatRelativeTimeFromString(String? isoString) {
  if (isoString == null) return '';
  final parsed = DateTime.tryParse(isoString);
  if (parsed == null) return '';
  return formatRelativeTime(parsed.toLocal());
}
