
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ==========================================
// TABELA DE MÍDIAS
// ==========================================

class MediaItems extends Table {

  // Identificador único da mídia.
  // Será gerado pelo aplicativo usando UUID.

  TextColumn get id => text()();

  // Tipo da mídia: photo ou video.

  TextColumn get kind => text()();

  // Caminho do arquivo original no celular.

  TextColumn get localPath => text().unique()();

  // Data em que a foto ou o vídeo foi capturado.
  // Pode ser desconhecida em arquivos importados.

  DateTimeColumn get capturedAt =>
      dateTime().nullable()();

  // Data em que a mídia foi adicionada ao aplicativo.

  DateTimeColumn get addedAt => dateTime()();

  // Grupo ao qual a mídia pertence.
  // Inicialmente pode ficar vazio.

  TextColumn get groupId => text().nullable()();

  // Espaço pessoal ou equipe.
  // Será utilizado futuramente.

  TextColumn get workspaceId => text().nullable()();

  // Controle de criação e atualização do registro.

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  // Status para a futura sincronização.
  // Por enquanto, todos os registros serão locais.

  TextColumn get syncStatus =>
      text().withDefault(const Constant('local'))();

  // O identificador é a chave primária da mídia.

  @override
  Set<Column> get primaryKey => {id};
}


/// Catálogo de tags reutilizáveis.
class Tags extends Table {
  TextColumn get id => text()();

  // Nome que aparece para o usuário.
  TextColumn get name => text()();

  // Usado para evitar duplicatas como:
  // "Preventiva" e "preventiva".
  TextColumn get normalizedName => text().unique()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Relação entre mídias e tags.
///
/// Uma mídia pode ter várias tags.
/// Uma tag pode pertencer a várias mídias.
class MediaTags extends Table {
  TextColumn get mediaId =>
      text().references(MediaItems, #id)();

  TextColumn get tagId =>
      text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {
    mediaId,
    tagId,
  };
}


/// Conjunto de mídias que pode receber novos itens em qualquer data.
class PhotoGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tags compartilhadas por todas as mídias de um grupo.
class GroupTags extends Table {
  TextColumn get groupId => text().references(PhotoGroups, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {groupId, tagId};
}

// ==========================================
// BANCO DE DADOS PRINCIPAL
// ==========================================


@DriftDatabase(
  tables: [
    MediaItems,
    Tags,
    MediaTags,
    PhotoGroups,
    GroupTags,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      : super(
          driftDatabase(
            name: 'tag_photo',
          ),
        );

  // A versão anterior tinha somente MediaItems.
  // Esta versão acrescenta Tags e MediaTags.

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator migrator) async {
        // Instalação nova:
        // cria todas as tabelas do aplicativo.
        await migrator.createAll();
      },

      onUpgrade: (
        Migrator migrator,
        int from,
        int to,
      ) async {
        if (from < 2) {
          // Atualiza o banco existente
          // sem apagar a tabela de mídias.

          await migrator.createTable(tags);

          await migrator.createTable(mediaTags);
        }
        if (from < 3) {
          await migrator.createTable(photoGroups);
          await migrator.createTable(groupTags);
        }
      },
    );
  }
}