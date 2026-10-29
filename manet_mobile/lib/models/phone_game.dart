// A game's site (Jackbox's jackbox.tv, a manual) is shown inside the pad
// page instead of replacing it, so the phone keeps its seat and can still
// reach the pad and the Home overlay.

/// The address to show, or null when it can't be shown in a frame
/// (anything but a web page, like `javascript:`). A bare host gets https.
String? normalizePhoneGameUrl(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return uri.toString();
}
