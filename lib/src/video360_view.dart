import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:video_360/src/video360_android_view.dart';
import 'package:video_360/src/video360_controller.dart';
import 'package:video_360/src/video360_ios_view.dart';

typedef Video360ViewCreatedCallback = void Function(
    Video360Controller controller);
typedef PlatformViewCreatedCallback = void Function(int id);

class Video360View extends StatefulWidget {
  final Video360ViewCreatedCallback onVideo360ViewCreated;

  final String? url;
  final bool? isAutoPlay;
  final bool? isRepeat;
  final Video360ControllerCallback? onCallback;
  final Video360ControllerPlayInfo? onPlayInfo;
  final VoidCallback? onPanCancel;
  final VoidCallback? onPanStart;
  final VoidCallback? onPanEnd;

  const Video360View({
    Key? key,
    required this.onVideo360ViewCreated,
    this.url,
    this.isAutoPlay = true,
    this.isRepeat = true,
    this.onCallback,
    this.onPlayInfo,
    this.onPanCancel,
    this.onPanStart,
    this.onPanEnd,
  }) : super(key: key);

  @override
  _Video360ViewState createState() => _Video360ViewState();
}

class _Video360ViewState extends State<Video360View>
    with WidgetsBindingObserver {
  late Video360Controller controller;

  bool isPlaying = false;

  @override
  void initState() {
    WidgetsBinding.instance?.addObserver(this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Container(
        child: Video360AndroidView(
          viewType: 'kino_video_360',
          onPlatformViewCreated: _onPlatformViewCreated,
          gestureRecognizers: [
            if (isPlaying)
              Factory(
                () => EagerGestureRecognizer(),
              ),
          ].toSet(),
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Container(
        child: GestureDetector(
          child: Video360IOSView(
            viewType: 'kino_video_360',
            onPlatformViewCreated: _onPlatformViewCreated,
          ),
          onPanCancel: widget.onPanCancel,
          onPanStart: (details) {
            widget.onPanStart?.call();

            controller.onPanUpdate(
                true, details.localPosition.dx, details.localPosition.dy);
          },
          onPanUpdate: (details) {
            controller.onPanUpdate(
                false, details.localPosition.dx, details.localPosition.dy);
          },
          onPanEnd: (_) => widget.onPanEnd?.call(),
        ),
      );
    }
    return Center(
      child: Text(
          '$defaultTargetPlatform is not supported by the video360_view plugin'),
    );
  }

  void _onPlatformViewCreated(int id) {
    if (widget.onVideo360ViewCreated == null) {
      return;
    }

    RenderBox? box = context.findRenderObject() as RenderBox?;

    var width = box?.size.width ?? 0.0;
    var heigt = box?.size.height ?? 0.0;

    controller = Video360Controller(
      id: id,
      url: widget.url,
      width: width,
      height: heigt,
      isAutoPlay: widget.isAutoPlay,
      isRepeat: widget.isRepeat,
      onCallback: widget.onCallback,
      onPlayInfo: (info) {
        if (info.isPlaying != isPlaying && Platform.isAndroid) {
          setState(() {
            isPlaying = info.isPlaying;
          });
        }
        widget.onPlayInfo?.call(info);
      },
    );
    controller.updateTime();
    widget.onVideo360ViewCreated(controller);
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    controller.dispose();
    super.dispose();
  }
}
