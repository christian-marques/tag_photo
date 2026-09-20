
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/storage/media_storage.dart';


class MediaTag {
  const MediaTag({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class MediaCatalog {
  MediaCatalog._();

  // Mantém uma única instância do banco
  // durante a execução do aplicativo.

  static final MediaCatalog instance = MediaCatalog._();

  final AppDatabase _database = AppDatabase();

  final MediaStorage _storage = const MediaStorage();

  static const Uuid _uuid = Uuid();

  // ==========================================
  // SALVAR E CADASTRAR UMA NOVA MÍDIA
  // ==========================================

  Future<File> saveCapturedMedia(
    String sourcePath, {
    required MediaKind kind,

    // Tags selecionadas na câmera.
    List<String> tagIds = const [],
  }) async {
    // Primeiro salva o arquivo original.

    final savedFile =
        await _storage.saveCapturedMedia(
      sourcePath,
      kind: kind,
    );

    final now = DateTime.now();

    // Registra a mídia e suas tags no banco.

    await _database.transaction(() async {
      await _registerMedia(
        file: savedFile,
        kind: kind,
        capturedAt: now,
        addedAt: now,
      );

      if (tagIds.isEmpty) return;

      // Recupera o ID da mídia recém-cadastrada.

      final mediaRecord = await (
        _database.select(_database.mediaItems)
          ..where(
            (media) => media.localPath.equals(
              savedFile.path,
            ),
          )
      ).getSingle();

      // Associa todas as tags selecionadas à mídia.

      for (final tagId in tagIds.toSet()) {
        await _database
            .into(_database.mediaTags)
            .insert(
              MediaTagsCompanion.insert(
                mediaId: mediaRecord.id,
                tagId: tagId,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });

    return savedFile;
  }

  // ==========================================
  // CADASTRAR UMA MÍDIA NO BANCO
  // ==========================================

  Future<void> _registerMedia({
    required File file,
    required MediaKind kind,
    required DateTime? capturedAt,
    required DateTime addedAt,
  }) async {
    final now = DateTime.now();

    await _database.into(_database.mediaItems).insert(
      MediaItemsCompanion.insert(
        // Identificador único e permanente.

        id: _uuid.v4(),

        // Foto ou vídeo.

        kind: kind.name,

        // Caminho do arquivo no celular.

        localPath: file.path,

        // Datas da mídia.

        capturedAt: Value(capturedAt),

        addedAt: addedAt,

        createdAt: now,

        updatedAt: now,
      ),

      // Impede duplicar o cadastro
      // caso o arquivo já esteja registrado.

      mode: InsertMode.insertOrIgnore,
    );
  }

  // ==========================================
  // IDENTIFICAR DATA DOS ARQUIVOS ANTIGOS
  // ==========================================

  DateTime? _dateFromFileName(String filePath) {
    final fileName = p.basename(filePath);

    // Nosso MediaStorage gera nomes como:
    //
    // 1789999999999999_uuid.jpg
    //
    // O primeiro número representa a data
    // em microssegundos desde a época Unix.

    final firstPart = fileName.split('_').first;

    if (!RegExp(r'^\d{16}$').hasMatch(firstPart)) {
      return null;
    }

    final timestamp = int.tryParse(firstPart);

    if (timestamp == null) return null;

    try {
      return DateTime.fromMicrosecondsSinceEpoch(
        timestamp,
        isUtc: true,
      ).toLocal();
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // CADASTRAR AS MÍDIAS QUE JÁ EXISTEM
  // ==========================================

  Future<void> _indexExistingMedia() async {

    // Busca os arquivos salvos antes
    // de termos implementado o SQLite.

    final localMedia =
        await _storage.getSavedMedia();

    // Consulta os caminhos que já estão
    // cadastrados no banco.

    final registered =
        await _database.select(
      _database.mediaItems,
    ).get();

    final registeredPaths = registered
        .map((media) => media.localPath)
        .toSet();

    for (final media in localMedia) {

      // Não cadastra novamente um arquivo
      // que já está no banco.

      if (registeredPaths.contains(
        media.file.path,
      )) {
        continue;
      }

      // Recupera a data aproximada do cadastro
      // pelo nome criado pelo nosso MediaStorage.

      final fileDate =
          _dateFromFileName(media.file.path);

      final addedAt =
          fileDate ??
          await media.file.lastModified();

      await _registerMedia(
        file: media.file,
        kind: media.kind,
        capturedAt: fileDate,
        addedAt: addedAt,
      );

      registeredPaths.add(media.file.path);
    }
  }

  // ==========================================
  // CONSULTAR AS MÍDIAS DO BANCO
  // ==========================================

  Future<List<SavedMedia>> getSavedMedia() async {

    // Antes de consultar, identifica arquivos
    // antigos que ainda não estão no SQLite.

    await _indexExistingMedia();

    // Agora a biblioteca consulta o banco
    // em vez de depender da listagem da pasta.

    final records = await (
      _database.select(_database.mediaItems)
        ..orderBy([
          (table) => OrderingTerm.desc(
            table.addedAt,
          ),
        ])
    ).get();

    final result = <SavedMedia>[];

    for (final record in records) {
      final file = File(record.localPath);

      // Não tenta abrir arquivos que
      // não estão mais disponíveis no celular.

      if (!await file.exists()) continue;

      result.add(
        SavedMedia(
          file: file,

          kind: record.kind == MediaKind.video.name
              ? MediaKind.video
              : MediaKind.photo,
        ),
      );
    }

    debugPrint(
      'Banco local: ${records.length} mídias cadastradas.',
    );

    return result;
  }


  // ==========================================
  // CONSULTAR TAGS EXISTENTES
  // ==========================================

  Future<List<MediaTag>> getAllTags() async {
    final records =
        await _database.select(_database.tags).get();

    final result = records
        .map(
          (record) => MediaTag(
            id: record.id,
            name: record.name,
          ),
        )
        .toList();

    result.sort(
      (a, b) => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
    );

    return result;
  }

  // ==========================================
  // CRIAR OU REUTILIZAR UMA TAG
  // ==========================================

  Future<MediaTag> createTag(String name) async {
    // Remove espaços desnecessários.
    final cleanName = name.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    if (cleanName.isEmpty) {
      throw ArgumentError('O nome da tag não pode ser vazio.');
    }

    // Evita duplicatas como:
    // "Preventiva", "preventiva" e " PREVENTIVA ".

    final normalizedName = cleanName.toLowerCase();

    final now = DateTime.now();

    await _database.into(_database.tags).insert(
      TagsCompanion.insert(
        id: _uuid.v4(),
        name: cleanName,
        normalizedName: normalizedName,
        createdAt: now,
        updatedAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );

    // Recupera a tag existente ou recém-criada.

    final record = await (
      _database.select(_database.tags)
        ..where(
          (tag) => tag.normalizedName.equals(
            normalizedName,
          ),
        )
    ).getSingle();

    return MediaTag(
      id: record.id,
      name: record.name,
    );
  }

}