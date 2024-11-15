import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'constant/constant.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  RtcEngine? _engine;
  bool localUserJoined = false;
  List<int> users = []; // List to store remote user IDs

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  /// This method is used to initialize the Agora engine
  Future<void> initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine?.initialize(RtcEngineContext(appId: appId));

    await _engine?.enableVideo();
    await _engine?.startPreview();

    _engine?.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          setState(() {
            localUserJoined = true;
          });
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          setState(() {
            users.add(remoteUid);
          });
        },
        onUserOffline: (connection, remoteUid, reason) {
          setState(() {
            users.remove(remoteUid);
          });
        },
      ),
    );

    await _engine?.joinChannel(
      token: token,
      channelId: channel,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  /// This method is used to dispose the Agora engine
  Future<void> _dispose() async {
    await _engine?.leaveChannel();
    await _engine?.release();
  }

  // This method is used to build video layout based on the number of users
  Widget _renderVideoLayout() {
    if (_engine == null) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Widget> videoViews = [];

    // Add the local video view. i.e the main user(YOU)
    videoViews.add(
      AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine!,
          canvas: const VideoCanvas(uid: 0),
        ),
      ),
    );

    // Add remote user video views (Other users)
    for (var uid in users) {
      videoViews.add(
        AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine!,
            canvas: VideoCanvas(uid: uid),
            connection: RtcConnection(channelId: channel),
          ),
        ),
      );
    }

    // Display full screen for single user
    if (videoViews.length == 1) {
      return videoViews[0];
    }

    // For two users, split screen vertically
    if (videoViews.length == 2) {
      return Column(
        children: [
          Expanded(child: videoViews[0]),
          Expanded(child: videoViews[1]),
        ],
      );
    }

    // For 3 or 4 users, use a 2x2 grid
    if (videoViews.length <= 4) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.0,
        ),
        itemCount: videoViews.length,
        itemBuilder: (context, index) {
          return videoViews[index];
        },
      );
    }

    // For more than 4 users, use a grid layout with increasing columns
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: (videoViews.length / 2).ceil(),
        childAspectRatio: 1.0,
      ),
      itemCount: videoViews.length,
      itemBuilder: (context, index) {
        return videoViews[index];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          Center(
            child: _renderVideoLayout(),
          ),
          if (!localUserJoined)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
