
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

enum MediaKind {
  photo,
  video,
}

class SavedMedia {
  const SavedMedia({
    required this.file,
    required this.kind,
  });

  final File file;
  final MediaKind kind;
}

class MediaStorage {
  const MediaStorage();

  static const _uuid = Uuid();

  Future<Directory> get _mediaDirectory async {
    final appDirectory =
        await getApplicationDocumentsDirectory();

    final directory = Directory(
      p.join(
        appDirectory.path,
        'media',
        'originals',
      ),
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<File> saveCapturedMedia(
    String sourcePath, {
    required MediaKind kind,
  }) async {
    final source = File(sourcePath);

    if (!await source.exists()) {
      throw FileSystemException(
        'Arquivo original não encontrado.',
        sourcePath,
      );
    }

    final directory = await _mediaDirectory;

    final originalExtension =
        p.extension(sourcePath).toLowerCase();

    final extension = originalExtension.isNotEmpty
        ? originalExtension
        : kind == MediaKind.photo
            ? '.jpg'
            : '.mp4';

    final timestamp =
        DateTime.now().toUtc().microsecondsSinceEpoch;

    final id = _uuid.v4();

    final fileName = '${timestamp}_$id$extension';

    final destination = File(
      p.join(directory.path, fileName),
    );

    // Preserva os bytes do arquivo original.
    await source.copy(destination.path);

    return destination;
  }

  Future<List<SavedMedia>> getSavedMedia() async {
    final directory = await _mediaDirectory;

    final files = await directory
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();

    final media = <SavedMedia>[];

    const photoExtensions = {
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.heic',
      '.heif',
    };

    const videoExtensions = {
      '.mp4',
      '.mov',
      '.m4v',
      '.3gp',
    };

    for (final file in files) {
      final extension =
          p.extension(file.path).toLowerCase();

      if (photoExtensions.contains(extension)) {
        media.add(
          SavedMedia(
            file: file,
            kind: MediaKind.photo,
          ),
        );
      } else if (videoExtensions.contains(extension)) {
        media.add(
          SavedMedia(
            file: file,
            kind: MediaKind.video,
          ),
        );
      }
    }

    media.sort(
      (a, b) => p
          .basename(b.file.path)
          .compareTo(p.basename(a.file.path)),
    );

    return media;
  }
}