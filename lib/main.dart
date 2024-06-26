// ignore_for_file: avoid_print

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agora Android 14 Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isReadyPreview = false;
  bool isJoined = false;
  bool isScreenShared = false;
  bool loading = true;

  int localUid = 1000;
  int screenSharerUid = 1001;

  // Agora 24-hour Temp IDs
  // TODO: Add IDs
  String agoraAppId = ""; // Your App ID here
  String agoraToken = ""; // Your temp token here
  String channelId = ""; // Your channel name here

  late final RtcEngineEx _engine;
  late final RtcEngineEventHandler _rtcEngineEventHandler;

  @override
  void initState() {
    super.initState();
    _requestPermissionIfNeed();
  }

  Future<void> _requestPermissionIfNeed() async {
    await [Permission.microphone, Permission.camera].request();
    setState(() {
      loading = false;
    });
    _initEngine();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    flex: 1,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: _engine,
                          canvas: const VideoCanvas(
                            uid: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: isScreenShared
                          ? Stack(children: [
                              AgoraVideoView(
                                controller: VideoViewController(
                                  rtcEngine: _engine,
                                  canvas: const VideoCanvas(
                                    uid: 0,
                                    sourceType:
                                        VideoSourceType.videoSourceScreen,
                                  ),
                                ),
                              ),
                              const Positioned(
                                top: 5,
                                right: 5,
                                child: Text(
                                  "Screen Share",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ])
                          : Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Text('Screen Sharing View'),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
      persistentFooterButtons: [
        ElevatedButton(
          // Joining channel not really required
          onPressed: isJoined ? _leaveChannel : _joinChannel,
          // onPressed: null,
          child: Text('${isJoined ? 'Leave' : 'Join'} channel'),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: !isScreenShared ? startScreenShare : stopScreenShare,
          child: Text('${isScreenShared ? 'Stop' : 'Start'} screen share'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
    _engine.unregisterEventHandler(_rtcEngineEventHandler);
    _engine.release();
  }

  _initEngine() async {
    _rtcEngineEventHandler = RtcEngineEventHandler(
        onError: (ErrorCodeType err, String msg) {
      print('[onError] err: $err, msg: $msg');
    }, onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
      print(
          '[onJoinChannelSuccess] connection: ${connection.toJson()} elapsed: $elapsed');
      setState(() {
        isJoined = true;
      });
    }, onLeaveChannel: (RtcConnection connection, RtcStats stats) {
      print(
          '[onLeaveChannel] connection: ${connection.toJson()} stats: ${stats.toJson()}');
      setState(() {
        isJoined = false;
      });
    }, onLocalVideoStateChanged: (VideoSourceType source,
            LocalVideoStreamState state, LocalVideoStreamReason error) {
      print(
          '[onLocalVideoStateChanged] source: $source, state: $state, error: $error');
      if (!(source == VideoSourceType.videoSourceScreen ||
          source == VideoSourceType.videoSourceScreenPrimary)) {
        return;
      }

      switch (state) {
        case LocalVideoStreamState.localVideoStreamStateCapturing:
        case LocalVideoStreamState.localVideoStreamStateEncoding:
          setState(() {
            isScreenShared = true;
          });
          break;
        case LocalVideoStreamState.localVideoStreamStateStopped:
        case LocalVideoStreamState.localVideoStreamStateFailed:
          setState(() {
            isScreenShared = false;
          });
          break;
        default:
          break;
      }
    });
    _engine = createAgoraRtcEngineEx();
    await _engine.initialize(RtcEngineContext(
      appId: agoraAppId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));
    await _engine.setLogLevel(LogLevel.logLevelError);

    _engine.registerEventHandler(_rtcEngineEventHandler);

    _engine.setVideoEncoderConfiguration(const VideoEncoderConfiguration(
      dimensions: VideoDimensions(width: 720, height: 1368),
      frameRate: 15,
    ));

    await _engine.enableVideo();
    await _engine.startPreview();
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    setState(() {
      isReadyPreview = true;
    });
  }

  void _joinChannel() async {
    await _engine.joinChannelEx(
        token: agoraToken,
        connection: RtcConnection(channelId: channelId, localUid: localUid),
        options: const ChannelMediaOptions(
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ));

    await _engine.joinChannelEx(
        token: agoraToken,
        connection:
            RtcConnection(channelId: channelId, localUid: screenSharerUid),
        options: const ChannelMediaOptions(
          autoSubscribeVideo: false,
          autoSubscribeAudio: false,
          publishScreenTrack: true,
          publishSecondaryScreenTrack: true,
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
          publishScreenCaptureAudio: true,
          publishScreenCaptureVideo: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ));
  }

  Future<void> _updateScreenShareChannelMediaOptions() async {
    await _engine.updateChannelMediaOptionsEx(
      options: const ChannelMediaOptions(
        publishScreenTrack: true,
        publishSecondaryScreenTrack: true,
        publishCameraTrack: false,
        publishMicrophoneTrack: false,
        publishScreenCaptureAudio: true,
        publishScreenCaptureVideo: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
      connection:
          RtcConnection(channelId: channelId, localUid: screenSharerUid),
    );
  }

  _leaveChannel() async {
    await _engine.stopScreenCapture();
    await _engine.leaveChannel();
  }

  void startScreenShare() async {
    if (isScreenShared) return;

    await _engine.startScreenCapture(
        const ScreenCaptureParameters2(captureAudio: true, captureVideo: true));
    await _engine.startPreview(sourceType: VideoSourceType.videoSourceScreen);

    if (isJoined) {
      _updateScreenShareChannelMediaOptions();
    }
  }

  void stopScreenShare() async {
    if (!isScreenShared) return;

    await _engine.stopScreenCapture();
  }
}
