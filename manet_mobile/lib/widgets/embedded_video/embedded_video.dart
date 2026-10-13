import 'package:flutter/material.dart';
import 'embedded_video_stub.dart'
    if (dart.library.html) 'embedded_video_web.dart' as impl;

Widget getEmbeddedVideo(String videoId) => impl.buildEmbeddedVideo(videoId);

bool get isEmbeddedVideoSupported => impl.isEmbeddedVideoSupported;
