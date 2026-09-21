
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

/// Grupo reutilizável, não precisa ser encerrado ao virar o dia.
class MediaGroup {
  const MediaGroup({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.tags,
    required this.mediaCount,
    this.firstMediaAt,
    this.lastMediaAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final List<MediaTag> tags;
  final int mediaCount;
  final DateTime? firstMediaAt;
  final DateTime? lastMediaAt;
}

class GroupMedia {
  const GroupMedia({required this.media, required this.date});
  final SavedMedia media;
  final DateTime? date;
}

class MediaSearchEntry {
  const MediaSearchEntry({
    required this.media,
    required this.groupId,
    required this.capturedAt,
    required this.tags,
  });

  final SavedMedia media;
  final String? groupId;
  final DateTime? capturedAt;
  final List<MediaTag> tags;
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
    String? groupId,
    bool importedFromGallery = false,
    DateTime? originalCapturedAt,
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
        capturedAt: importedFromGallery ? originalCapturedAt : now,
        addedAt: now,
        groupId: groupId,
      );

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
        await _database.into(_database.mediaTags).insert(
          MediaTagsCompanion.insert(mediaId: mediaRecord.id, tagId: tagId),
          mode: InsertMode.insertOrIgnore,
        );
      }
      if (groupId != null) {
        await (_database.update(_database.photoGroups)
              ..where((g) => g.id.equals(groupId)))
            .write(PhotoGroupsCompanion(updatedAt: Value(now)));
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
    String? groupId,
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
        groupId: Value(groupId),

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

  
  // ==========================================
  // BUSCAR MÍDIAS POR MÚLTIPLAS TAGS
  // ==========================================

  Future<List<SavedMedia>> searchMediaByTags(List<String> tagIds) async {
    await _indexExistingMedia();
    final selected = tagIds.toSet();
    if (selected.isEmpty) return getSavedMedia();

    final records = await _database.select(_database.mediaItems).get();
    final mediaRelations = await _database.select(_database.mediaTags).get();
    final groupRelations = await _database.select(_database.groupTags).get();

    final tagsByMedia = <String, Set<String>>{};
    for (final relation in mediaRelations) {
      tagsByMedia.putIfAbsent(relation.mediaId, () => <String>{})
          .add(relation.tagId);
    }
    final tagsByGroup = <String, Set<String>>{};
    for (final relation in groupRelations) {
      tagsByGroup.putIfAbsent(relation.groupId, () => <String>{})
          .add(relation.tagId);
    }

    final matched = records.where((media) {
      final effective = <String>{
        ...?tagsByMedia[media.id],
        ...?tagsByGroup[media.groupId],
      };
      return effective.containsAll(selected);
    }).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    final result = <SavedMedia>[];
    for (final record in matched) {
      final file = File(record.localPath);
      if (!await file.exists()) continue;
      result.add(SavedMedia(
        file: file,
        kind: record.kind == MediaKind.video.name
            ? MediaKind.video : MediaKind.photo,
      ));
    }
    return result;
  }

  Future<MediaGroup?> getGroupForMedia(String mediaPath) async {
    final row = await (_database.select(_database.mediaItems)
          ..where((m) => m.localPath.equals(mediaPath)))
        .getSingleOrNull();
    if (row?.groupId == null) return null;
    return getGroup(row!.groupId!);
  }

  // ==========================================
  // CONSULTAR AS TAGS DE UMA MÍDIA
  // ==========================================

  Future<List<MediaTag>> getTagsForMedia(
    String mediaPath,
  ) async {
    // Garante que mídias antigas estejam cadastradas.
    await _indexExistingMedia();

    final media = await (
      _database.select(_database.mediaItems)
        ..where(
          (row) => row.localPath.equals(mediaPath),
        )
    ).getSingleOrNull();

    if (media == null) {
      throw StateError('Mídia não encontrada no banco.');
    }

    // Consulta as associações da mídia.
    final relations = await (
      _database.select(_database.mediaTags)
        ..where(
          (row) => row.mediaId.equals(media.id),
        )
    ).get();

    final selectedIds = relations
        .map((relation) => relation.tagId)
        .toSet();

    // Recupera os nomes das tags.
    final allTags = await getAllTags();

    return allTags
        .where((tag) => selectedIds.contains(tag.id))
        .toList();
  }

  // ==========================================
  // SALVAR AS TAGS DE UMA MÍDIA EXISTENTE
  // ==========================================

  Future<void> setTagsForMedia(
    String mediaPath,
    List<String> tagIds,
  ) async {
    final media = await (
      _database.select(_database.mediaItems)
        ..where(
          (row) => row.localPath.equals(mediaPath),
        )
    ).getSingleOrNull();

    if (media == null) {
      throw StateError('Mídia não encontrada no banco.');
    }

    final selectedIds = tagIds.toSet();

    await _database.transaction(() async {
      // Remove as associações anteriores.
      await (
        _database.delete(_database.mediaTags)
          ..where(
            (row) => row.mediaId.equals(media.id),
          )
      ).go();

      // Salva a nova seleção.
      for (final tagId in selectedIds) {
        await _database
            .into(_database.mediaTags)
            .insert(
              MediaTagsCompanion.insert(
                mediaId: media.id,
                tagId: tagId,
              ),
            );
      }

      // Atualiza a data de modificação.
      await (
        _database.update(_database.mediaItems)
          ..where(
            (row) => row.id.equals(media.id),
          )
      ).write(
        MediaItemsCompanion(
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  // ==========================================
  // GRUPOS: criar, consultar, atualizar, reutilizar
  // ==========================================

  Future<MediaGroup> createGroup(String name, List<String> tagIds) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Informe o nome do grupo.');
    final id = _uuid.v4();
    final now = DateTime.now();
    await _database.transaction(() async {
      await _database.into(_database.photoGroups).insert(
        PhotoGroupsCompanion.insert(
          id: id, name: clean, createdAt: now, updatedAt: now,
        ),
      );
      for (final tagId in tagIds.toSet()) {
        await _database.into(_database.groupTags).insert(
          GroupTagsCompanion.insert(groupId: id, tagId: tagId),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
    return (await getGroup(id))!;
  }

  Future<List<MediaGroup>> getGroups() async {
    await _indexExistingMedia();
    final groups = await (_database.select(_database.photoGroups)
          ..orderBy([(g) => OrderingTerm.desc(g.updatedAt)]))
        .get();
    final links = await _database.select(_database.groupTags).get();
    final tags = await getAllTags();
    final tagsById = {for (final tag in tags) tag.id: tag};
    final allMedia = await _database.select(_database.mediaItems).get();
    return groups.map((group) {
      final items = allMedia.where((m) => m.groupId == group.id).toList();
      final dates = items.where((m) => m.capturedAt != null)
          .map((m) => m.capturedAt!).toList()..sort();
      return MediaGroup(
        id: group.id,
        name: group.name,
        createdAt: group.createdAt,
        tags: [for (final link in links)
          if (link.groupId == group.id && tagsById.containsKey(link.tagId))
            tagsById[link.tagId]!],
        mediaCount: items.length,
        firstMediaAt: dates.isEmpty ? null : dates.first,
        lastMediaAt: dates.isEmpty ? null : dates.last,
      );
    }).toList();
  }

  Future<MediaGroup?> getGroup(String id) async {
    final groups = await getGroups();
    for (final group in groups) {
      if (group.id == id) return group;
    }
    return null;
  }

  Future<void> setGroupTags(String groupId, List<String> tagIds) async {
    final now = DateTime.now();
    await _database.transaction(() async {
      await (_database.delete(_database.groupTags)
            ..where((r) => r.groupId.equals(groupId))).go();
      for (final tagId in tagIds.toSet()) {
        await _database.into(_database.groupTags).insert(
          GroupTagsCompanion.insert(groupId: groupId, tagId: tagId),
        );
      }
      await (_database.update(_database.photoGroups)
            ..where((g) => g.id.equals(groupId)))
          .write(PhotoGroupsCompanion(updatedAt: Value(now)));
    });
  }

  Future<List<GroupMedia>> getMediaInGroup(String groupId) async {
    await _indexExistingMedia();
    final rows = await (_database.select(_database.mediaItems)
          ..where((m) => m.groupId.equals(groupId)))
        .get();
    rows.sort((a, b) {
      final left = a.capturedAt;
      final right = b.capturedAt;
      if (left == null) return right == null ? 0 : 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    final output = <GroupMedia>[];
    for (final row in rows) {
      final file = File(row.localPath);
      if (!await file.exists()) continue;
      output.add(GroupMedia(
        media: SavedMedia(file: file,
          kind: row.kind == MediaKind.video.name
              ? MediaKind.video : MediaKind.photo),
        date: row.capturedAt,
      ));
    }
    return output;
  }

  /// Permite incluir mídias antigas no grupo sem copiar seus arquivos.
  /// Uma mídia pertence no máximo a um grupo; tags individuais são preservadas.
  Future<void> attachMediaToGroup(
      String groupId, List<String> mediaPaths) async {
    await _indexExistingMedia();
    final now = DateTime.now();
    await _database.transaction(() async {
      for (final path in mediaPaths.toSet()) {
        await (_database.update(_database.mediaItems)
              ..where((m) => m.localPath.equals(path)))
            .write(MediaItemsCompanion(
              groupId: Value(groupId), updatedAt: Value(now)));
      }
      await (_database.update(_database.photoGroups)
            ..where((g) => g.id.equals(groupId)))
          .write(PhotoGroupsCompanion(updatedAt: Value(now)));
    });
  }


  /// Lista para a busca: tags individuais + tags herdadas do grupo.
  /// Datas desconhecidas permanecem nulas; addedAt nunca vira data da foto.
  Future<List<MediaSearchEntry>> searchEntries(List<String> selectedTagIds) async {
    await _indexExistingMedia();
    final rows = await _database.select(_database.mediaItems).get();
    final personal = await _database.select(_database.mediaTags).get();
    final inherited = await _database.select(_database.groupTags).get();
    final allTags = await getAllTags();
    final byId = {for (final tag in allTags) tag.id: tag};
    final own = <String, Set<String>>{};
    final byGroup = <String, Set<String>>{};
    for (final link in personal) {
      own.putIfAbsent(link.mediaId, () => <String>{}).add(link.tagId);
    }
    for (final link in inherited) {
      byGroup.putIfAbsent(link.groupId, () => <String>{}).add(link.tagId);
    }
    final selected = selectedTagIds.toSet();
    final result = <MediaSearchEntry>[];
    for (final row in rows) {
      final ids = <String>{...?own[row.id], ...?byGroup[row.groupId]};
      if (!ids.containsAll(selected)) continue;
      final file = File(row.localPath);
      if (!await file.exists()) continue;
      result.add(MediaSearchEntry(
        media: SavedMedia(
          file: file,
          kind: row.kind == MediaKind.video.name ? MediaKind.video : MediaKind.photo,
        ),
        groupId: row.groupId,
        capturedAt: row.capturedAt,
        tags: [for (final id in ids) if (byId.containsKey(id)) byId[id]!],
      ));
    }
    result.sort((a, b) {
      if (a.capturedAt == null) return b.capturedAt == null ? 0 : 1;
      if (b.capturedAt == null) return -1;
      return b.capturedAt!.compareTo(a.capturedAt!);
    });
    return result;
  }

  Future<DateTime?> getMediaCapturedAt(String mediaPath) async {
    await _indexExistingMedia();
    final row = await (_database.select(_database.mediaItems)
      ..where((m) => m.localPath.equals(mediaPath))).getSingleOrNull();
    if (row == null) throw StateError('Mídia não cadastrada.');
    return row.capturedAt;
  }

  Future<void> setMediaCapturedAt(String mediaPath, DateTime? date) async {
    await _indexExistingMedia();
    final now = DateTime.now();
    await (_database.update(_database.mediaItems)
      ..where((m) => m.localPath.equals(mediaPath))).write(
      MediaItemsCompanion(capturedAt: Value(date), updatedAt: Value(now)),
    );
  }

  /// Apenas desfaz a associação: não apaga arquivos ou tags próprias.
  Future<void> removeMediaFromGroup(String mediaPath) async {
    await _indexExistingMedia();
    final now = DateTime.now();
    await (_database.update(_database.mediaItems)
      ..where((m) => m.localPath.equals(mediaPath))).write(
      MediaItemsCompanion(groupId: const Value(null), updatedAt: Value(now)),
    );
  }

  Future<void> renameGroup(String groupId, String newName) async {
    final name = newName.trim();
    if (name.isEmpty) throw ArgumentError('Informe um nome para o grupo.');
    await (_database.update(_database.photoGroups)
      ..where((g) => g.id.equals(groupId))).write(
      PhotoGroupsCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
  }

  /// Exclui somente o agrupamento; mídias e tags individuais continuam salvas.
  Future<void> deleteGroup(String groupId) async {
    await _database.transaction(() async {
      await (_database.update(_database.mediaItems)
        ..where((m) => m.groupId.equals(groupId))).write(
        MediaItemsCompanion(groupId: const Value(null), updatedAt: Value(DateTime.now())),
      );
      await (_database.delete(_database.groupTags)
        ..where((g) => g.groupId.equals(groupId))).go();
      await (_database.delete(_database.photoGroups)
        ..where((g) => g.id.equals(groupId))).go();
    });
  }

}