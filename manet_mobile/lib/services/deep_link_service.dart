import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'connection_intent_handler.dart';

/// Android App Links & Deep Links Explained:
///
/// 1. App Links (Verified Deep Links):
///    Require hosting an `assetlinks.json` file on a public HTTPS domain.
///    When the user clicks a link, Android verifies the domain and opens the app silently.
///    LIMITATION: This DOES NOT work for local network URLs (like http://192.168.x.x)
///    because we cannot host a verified SSL certificate or assetlinks file on arbitrary local IPs.
///
/// 2. Deep Links (Standard Intents):
///    Using an Intent Filter for HTTP/HTTPS without verification.
///    When clicked, Android shows a "disambiguation dialog" (Open with Browser or Ma.net?).
///    We constrain this to port "8765" in AndroidManifest to avoid intercepting all web traffic.
///
/// 3. Custom URI Schemes (e.g., manet://connect):
///    Guaranteed to route to our app without a disambiguation dialog (if no other app uses it).
///    This is the most seamless fallback from the web controller banner.

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  /// Initializes the deep link listener.
  /// Call this inside your main App widget's initState (e.g., inside `MaterialApp`'s root widget).
  void init(BuildContext context) {
    // Handle app opened from a deep link while terminated
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _processUri(context, uri);
      }
    });

    // Handle app opened from a deep link while running in background
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _processUri(context, uri);
      },
      onError: (err) {
        debugPrint('Deep Link Error: $err');
      },
    );
  }

  void _processUri(BuildContext context, Uri uri) {
    final parsedHost = ConnectionIntentHandler.parseDeepLinkToHost(uri);
    if (parsedHost != null) {
      ConnectionIntentHandler.handleConnection(context, parsedHost);
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
