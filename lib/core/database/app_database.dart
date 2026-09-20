
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

// ==========================================
// BANCO DE DADOS PRINCIPAL
// ==========================================

@DriftDatabase(
  tables: [
    MediaItems,
  ],
)
class AppDatabase extends _$AppDatabase {

  AppDatabase()
      : super(
          driftDatabase(
            name: 'tag_photo',
          ),
        );

  @override
  int get schemaVersion => 1;
}