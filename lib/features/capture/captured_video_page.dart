
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/sharing/media_share_service.dart';
import '../tags/media_tag_edit_button.dart';
import '../tags/media_info_menu.dart';

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

  
  final MediaShareService _shareService =
      const MediaShareService();

  bool _isSharing = false;

  Future<void> _shareVideo() async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
    });

    try {
      // Pausa a reprodução antes de abrir
      // o menu de compartilhamento.

      await _controller?.pause();

      await _shareService.shareMedia(
        widget.videoPath,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível compartilhar o vídeo: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
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

        actions: [
          // Editar tags do vídeo.
          MediaTagEditButton(
            mediaPath: widget.videoPath,

            beforeOpen: () async {
              // Pausa o vídeo antes de abrir o painel.
              await _controller?.pause();
            },
          ),

          MediaInfoMenu(
            mediaPath: widget.videoPath,
            beforeOpen: () async { await _controller?.pause(); },
          ),
          // Compartilhar vídeo.
          IconButton(
            tooltip: 'Compartilhar vídeo',

            onPressed: _isSharing
                ? null
                : _shareVideo,

            icon: const Icon(
              Icons.share_outlined,
            ),
          ),
        ],
      
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