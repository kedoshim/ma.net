import 'dart:html' as html;

bool isAndroidBrowser() {
  final userAgent = html.window.navigator.userAgent.toLowerCase();
  return userAgent.contains('android');
}

bool isStandalonePwa() {
  final isStandalone = html.window.matchMedia('(display-mode: standalone)').matches;
  return isStandalone;
}
