import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/store/providers.dart';

class VideoPlayerView extends ConsumerStatefulWidget {
  const VideoPlayerView({super.key});

  @override
  ConsumerState<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends ConsumerState<VideoPlayerView> {
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    final player = ref.read(playerProvider.notifier).player;
    _controller = VideoController(player);
  }

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: _controller,
      fill: Colors.black,
    );
  }
}
