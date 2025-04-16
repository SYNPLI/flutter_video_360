import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Video360AndroidView extends AndroidView {
  final String viewType;
  final PlatformViewCreatedCallback? onPlatformViewCreated;
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  Video360AndroidView({
    Key? key,
    required this.viewType,
    this.onPlatformViewCreated,
    this.gestureRecognizers,
  }) : super(
          viewType: viewType,
          onPlatformViewCreated: onPlatformViewCreated,
          creationParams: <String, dynamic>{},
          creationParamsCodec: const StandardMessageCodec(),
          gestureRecognizers: gestureRecognizers,
        );
}
