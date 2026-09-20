
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class CapturedVideoPage extends StatefulWidget {
  const CapturedVideoPage({
    super.key,
    required this.videoPath,
  });

  final String videoPath;

  @override
  State<CapturedVideoPage> createState() =>
      _CapturedVideoPageState();
}

class _CapturedVideoPageState extends State<CapturedVideoPage> {
  VideoPlayerController? _controller;

  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.file(
      File(widget.videoPath),
    );

    _controller = controller;

    try {
      await controller.initialize();

      if (!mounted) return;

      controller.addListener(_refresh);

      setState(() {});
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
      });
    }
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.position >=
          controller.value.duration) {
        await controller.seekTo(Duration.zero);
      }

      await controller.play();
    }
  }

  @override
  void dispose() {
    final controller = _controller;

    if (controller != null) {
      controller.removeListener(_refresh);
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    final ready = controller != null &&
        controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Vídeo capturado'),
      ),

      body: SafeArea(
        child: _error != null
            ? Center(
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
              )
            : !ready
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio:
                                controller.value.aspectRatio,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16),

                        child: Column(
                          children: [
                            VideoProgressIndicator(
                              controller,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: Colors.red,
                                bufferedColor: Colors.white24,
                                backgroundColor: Colors.white12,
                              ),
                            ),

                            const SizedBox(height: 16),

                            IconButton.filled(
                              onPressed: _togglePlayback,
                              iconSize: 36,
                              icon: Icon(
                                controller.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}