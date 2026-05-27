import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class QrCodeCacheService {
  QrCodeCacheService._internal();

  static final QrCodeCacheService instance = QrCodeCacheService._internal();

  final Map<String, Uint8List> _cache = {};
  final Map<String, Future<Uint8List>> _pendingLoads = {};

  ImageProvider? imageForUrl(String url) {
    final bytes = _cache[url];
    if (bytes == null) return null;
    return MemoryImage(bytes);
  }

  bool hasCachedImage(String url) => _cache.containsKey(url);

  Future<Uint8List> loadQrBytes(String url) {
    if (_cache.containsKey(url)) {
      return Future.value(_cache[url]);
    }

    if (_pendingLoads.containsKey(url)) {
      return _pendingLoads[url]!;
    }

    final future = http
        .get(Uri.parse(url), headers: {'Accept': 'image/png'})
        .then((response) {
          if (response.statusCode != 200) {
            throw Exception('Failed to load QR code image from $url');
          }
          final bytes = response.bodyBytes;
          _cache[url] = bytes;
          _pendingLoads.remove(url);
          return bytes;
        })
        .catchError((error) {
          _pendingLoads.remove(url);
          throw error;
        });

    _pendingLoads[url] = future;
    return future;
  }

  void clear() {
    _cache.clear();
    _pendingLoads.clear();
  }
}
