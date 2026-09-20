
import 'dart:io';

import 'package:share_plus/share_plus.dart';

class MediaShareService {
  const MediaShareService();

  Future<void> shareMedia(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw const FileSystemException(
        'Arquivo não encontrado para compartilhamento.',
      );
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(filePath),
        ],
      ),
    );
  }
}