import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_360/video_360.dart';

void main() {
  const MethodChannel channel = MethodChannel('kino_video_360_7');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends the iOS field-of-view scale with the player size', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    Video360Controller(
      id: 7,
      url: 'https://cdn.example/360.m3u8',
      width: 844,
      height: 390,
      fieldOfViewScale: 1.12,
      isAutoPlay: false,
      isRepeat: false,
    );
    await Future<void>.delayed(Duration.zero);

    final init = calls.singleWhere((call) => call.method == 'init');
    final arguments = init.arguments as Map<dynamic, dynamic>;
    expect(arguments['fieldOfViewScale'], 1.12);
    expect(arguments['width'], 844);
    expect(arguments['height'], 390);
  });
}
