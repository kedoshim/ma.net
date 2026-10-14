import 'package:flutter/material.dart';
import 'embedded_video_stub.dart'
    if (dart.library.html) 'embedded_video_web.dart' as impl;

Widget getEmbeddedVideo(String videoId) => impl.buildEmbeddedVideo(videoId);

/// A video file or stream (Steam trailers are HLS: `.m3u8`).
Widget getEmbeddedStream(String url) => impl.buildEmbeddedStream(url);

/// Stops the stream player (HLS keeps downloading otherwise).
void stopEmbeddedStreams() => impl.stopEmbeddedStreams();

bool get isEmbeddedVideoSupported => impl.isEmbeddedVideoSupported;

/// Links the stream player can play directly (not YouTube or a store page).
bool isStreamUrl(String url) {
  final path = Uri.tryParse(url.trim())?.path.toLowerCase() ?? '';
  return path.endsWith('.m3u8') || path.endsWith('.mp4') || path.endsWith('.webm');
}
