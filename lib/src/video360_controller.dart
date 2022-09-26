import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_360/src/video360_play_info.dart';

typedef Video360ControllerCallback = void Function(
    String method, dynamic arguments);
typedef Video360ControllerPlayInfo = void Function(Video360PlayInfo playInfo);

class Video360Controller {
  Video360Controller({
    required int id,
    this.url,
    this.headers,
    this.width,
    this.height,
    this.isAutoPlay,
    this.isRepeat,
    this.onCallback,
    this.onPlayInfo,
    this.onCompassAngleChanged,
  }) {
    _channel = MethodChannel('kino_video_360_$id');
    _channel.setMethodCallHandler(_handleMethodCalls);
    init();
  }

  late MethodChannel _channel;

  final String? url;
  final Map<String, String>? headers;
  final double? width;
  final double? height;
  final bool? isAutoPlay;
  final bool? isRepeat;
  final Video360ControllerCallback? onCallback;
  final Video360ControllerPlayInfo? onPlayInfo;
  final ValueChanged<double>? onCompassAngleChanged;

  StreamSubscription? playInfoStream;

  init() async {
    try {
      await _channel.invokeMethod<void>('init', {
        'url': url,
        'width': width,
        'headers': headers,
        'isAutoPlay': isAutoPlay,
        'isRepeat': isRepeat,
        'height': height,
      });
    } on PlatformException catch (e) {
      print('${e.code}: ${e.message}');
    }
  }

  dispose() async {
    try {
      playInfoStream?.cancel();
      await _channel.invokeMethod<void>('dispose');
    } on PlatformException catch (e) {
      print('${e.code}: ${e.message}');
    }
  }

  play() async {
    try {
      await _channel.invokeMethod<void>('play');
    } on PlatformException catch (e) {
      print('${e.code}: ${e.message}');
    }
  }

  stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException catch (e) {
      print('${e.code}: ${e.message}');
    }
  }

  reset({bool autoplay = false}) async {
    try {
      await _channel.invokeMethod<void>('reset', {'autoplay': autoplay});
    } on PlatformException catch (e) {
      print('${e.code}: ${e.message}');
    }
  }

  jumpTo(double millisecond, {bool autoplay = false}) async {
    try {
      await _channel.invokeMethod<void>('jumpTo', {
        'millisecond': millisecond,
        'autoplay': autoplay,
      });
    } on PlatformException catch (e) {
      print('${e.code}: ${e.message}');
    }
  }

  seekTo(double millisecond, {bool autoplay = false}) async {
    try {
      await _channel.invokeMethod<void>('seekTo', {
        'millisecond': millisecond,
        'autoplay': autoplay,
      });
    } on PlatformException catch (e) {
      print('${e.code}: ${e.message}');
    }
  }

  onPanUpdate(bool isStart, double x, double y) async {
    if (Platform.isIOS) {
      try {
        await _channel.invokeMethod<void>(
            'onPanUpdate', {'isStart': isStart, 'x': x, 'y': y});
      } on PlatformException catch (e) {
        print('${e.code}: ${e.message}');
      }
    }
  }

  getPlaying() async {
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod<bool>('playing');
      } on PlatformException catch (e) {
        print('${e.code}: ${e.message}');
      }
    }
  }

  getCurrentPosition() async {
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod<int>('currentPosition');
      } on PlatformException catch (e) {
        print('${e.code}: ${e.message}');
      }
    }
  }

  getDuration() async {
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod<int>('duration');
      } on PlatformException catch (e) {
        print('${e.code}: ${e.message}');
      }
    }
  }

  // This function must be called only once.
  updateTime() async {
    if (Platform.isAndroid) {
      if (playInfoStream != null) {
        playInfoStream?.cancel();
        playInfoStream = null;
      }

      playInfoStream = Stream.periodic(Duration(milliseconds: 100), (x) => x)
          .listen((event) async {
        var duration = await getCurrentPosition();
        var total = await getDuration();
        var isPlaying = await getPlaying();
        onPlayInfo?.call(Video360PlayInfo(
            duration: duration, total: total, isPlaying: isPlaying));
      });
    }
  }

  /// Only available on iOS.
  Future<void> resize(double width, double height) async {
    if (Platform.isIOS) {
      try {
        await _channel
            .invokeMethod<void>('resize', {'width': width, 'height': height});
      } on PlatformException catch (e) {
        print('${e.code}: ${e.message}');
      }
    }
  }

  /// Only available on iOS.
  Future<void> centerCamera() async {
    if (Platform.isIOS) {
      try {
        await _channel.invokeMethod<void>('centerCamera');
      } on PlatformException catch (e) {
        print('${e.code}: ${e.message}');
      }
    }
  }

  // flutter -> android / ios callback handle
  Future<dynamic> _handleMethodCalls(MethodCall call) async {
    switch (call.method) {
      // for iOS updateTime
      case 'updateTime':
        var duration = call.arguments['duration'];
        var total = call.arguments['total'];
        var isPlaing = call.arguments['isPlaying'];
        final compassAngle = call.arguments['compassAngle'];

        onPlayInfo?.call(Video360PlayInfo(
          duration: duration,
          total: total,
          isPlaying: isPlaing,
          compassAngle: compassAngle,
        ));

        break;
      case 'updateCompassAngle':
        final compassAngle = call.arguments['compassAngle'] as double;

        onCompassAngleChanged?.call(compassAngle);
        break;
      default:
        print('Unknowm method ${call.method} ');
        break;
    }
    return Future.value();
  }
}
