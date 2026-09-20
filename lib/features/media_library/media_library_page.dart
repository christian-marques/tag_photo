
import 'package:flutter/material.dart';

import '../../core/storage/media_storage.dart';
import '../capture/captured_photo_page.dart';
import '../capture/captured_video_page.dart';

class MediaLibraryPage extends StatefulWidget {
  const MediaLibraryPage({super.key});

  @override
  State<MediaLibraryPage> createState() =>
      _MediaLibraryPageState();
}

class _MediaLibraryPageState
    extends State<MediaLibraryPage> {
  final MediaStorage _storage = const MediaStorage();

  late Future<List<SavedMedia>> _mediaFuture;

  @override
  void initState() {
    super.initState();

    _loadMedia();
  }

  void _loadMedia() {
    _mediaFuture = _storage.getSavedMedia();
  }

  void _refresh() {
    setState(() {
      _loadMedia();
    });
  }

  Future<void> _openMedia(SavedMedia media) async {
    if (media.kind == MediaKind.photo) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => CapturedPhotoPage(
            photoPath: media.file.path,
          ),
        ),
      );
    } else {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => CapturedVideoPage(
            videoPath: media.file.path,
          ),
        ),
      );
    }
  }

  Widget _buildMediaTile(SavedMedia media) {
    return InkWell(
      onTap: () => _openMedia(media),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),

        child: Stack(
          fit: StackFit.expand,

          children: [
            // Fotos mostram uma miniatura.
            // Vídeos mostram um ícone temporariamente.

            if (media.kind == MediaKind.photo)
              Image.file(
                media.file,
                fit: BoxFit.cover,

                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return const ColoredBox(
                    color: Colors.black12,

                    child: Icon(
                      Icons.broken_image_outlined,
                    ),
                  );
                },
              )
            else
              const ColoredBox(
                color: Color(0xFF303030),

                child: Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),

            // Identificador do tipo de mídia.

            Positioned(
              top: 6,
              right: 6,

              child: Icon(
                media.kind == MediaKind.video
                    ? Icons.videocam
                    : Icons.photo_camera,

                color: Colors.white,

                shadows: const [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas mídias'),

        actions: [
          IconButton(
            tooltip: 'Atualizar biblioteca',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: FutureBuilder<List<SavedMedia>>(
        future: _mediaFuture,

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro ao carregar mídias:\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final media = snapshot.data!;

          if (media.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Icon(
                      Icons.perm_media_outlined,
                      size: 72,
                      color: Colors.grey,
                    ),

                    SizedBox(height: 16),

                    Text(
                      'Nenhuma mídia cadastrada.',
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 8),

                    Text(
                      'Capture uma foto ou grave um vídeo '
                      'para começar sua biblioteca.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),

            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),

            itemCount: media.length,

            itemBuilder: (context, index) {
              return _buildMediaTile(media[index]);
            },
          );
        },
      ),
    );
  }
}