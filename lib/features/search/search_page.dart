
import 'package:flutter/material.dart';

import '../../core/storage/media_storage.dart';
import '../../data/media_catalog.dart';

import '../capture/captured_photo_page.dart';
import '../capture/captured_video_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() =>
      _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final MediaCatalog _catalog = MediaCatalog.instance;

  final TextEditingController _searchController =
      TextEditingController();

  late Future<List<MediaTag>> _tagsFuture;

  late Future<List<SavedMedia>> _resultsFuture;

  final List<MediaTag> _selectedTags = [];

  String _searchText = '';

  @override
  void initState() {
    super.initState();

    // Carrega as tags existentes no banco.

    _tagsFuture = _catalog.getAllTags();

    // Inicialmente, mostra todas as mídias.

    _resultsFuture =
        _catalog.searchMediaByTags([]);
  }

  // ==========================================
  // ATUALIZAR RESULTADOS
  // ==========================================

  void _updateResults() {
    setState(() {
      _resultsFuture = _catalog.searchMediaByTags(
        _selectedTags
            .map((tag) => tag.id)
            .toList(),
      );
    });
  }

  // ==========================================
  // ADICIONAR TAG AO FILTRO
  // ==========================================

  void _addTag(MediaTag tag) {
    final alreadySelected = _selectedTags.any(
      (item) => item.id == tag.id,
    );

    if (alreadySelected) return;

    _selectedTags.add(tag);

    _searchController.clear();

    _searchText = '';

    _updateResults();
  }

  // ==========================================
  // REMOVER TAG DO FILTRO
  // ==========================================

  void _removeTag(MediaTag tag) {
    _selectedTags.removeWhere(
      (item) => item.id == tag.id,
    );

    _updateResults();
  }

  // ==========================================
  // LIMPAR TODOS OS FILTROS
  // ==========================================

  void _clearFilters() {
    _selectedTags.clear();

    _searchController.clear();

    _searchText = '';

    _updateResults();
  }

  // ==========================================
  // ABRIR FOTO OU VÍDEO
  // ==========================================

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

    // Reexecuta a busca ao voltar da visualização.
    if (mounted) {
      _updateResults();
    }
  }

  // ==========================================
  // MINIATURA DO RESULTADO
  // ==========================================

  Widget _buildMediaTile(SavedMedia media) {
    return InkWell(
      onTap: () => _openMedia(media),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),

        child: Stack(
          fit: StackFit.expand,

          children: [
            if (media.kind == MediaKind.photo)
              Image.file(
                media.file,

                fit: BoxFit.cover,

                cacheWidth: 400,

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

  // ==========================================
  // RESULTADOS DA BUSCA
  // ==========================================

  Widget _buildResults() {
    return FutureBuilder<List<SavedMedia>>(
      future: _resultsFuture,

      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),

              child: Text(
                'Erro ao buscar mídias:\n'
                '${snapshot.error}',

                textAlign: TextAlign.center,
              ),
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
                    Icons.search_off,
                    size: 64,
                    color: Colors.grey,
                  ),

                  SizedBox(height: 12),

                  Text(
                    'Nenhuma mídia encontrada.',
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Tente remover uma tag '
                    'ou selecionar outro filtro.',

                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                8,
              ),

              child: Text(
                '${media.length} mídias encontradas',

                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),

                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),

                itemCount: media.length,

                itemBuilder: (context, index) {
                  return _buildMediaTile(
                    media[index],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // INTERFACE PRINCIPAL
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final search = _searchText.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar mídias'),

        actions: [
          if (_selectedTags.isNotEmpty)
            IconButton(
              tooltip: 'Limpar filtros',

              onPressed: _clearFilters,

              icon: const Icon(
                Icons.filter_alt_off_outlined,
              ),
            ),
        ],
      ),

      body: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,

        children: [
          // ==================================
          // CAMPO DE PESQUISA
          // ==================================

          Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              8,
              12,
              8,
            ),

            child: TextField(
              controller: _searchController,

              decoration: const InputDecoration(
                hintText: 'Pesquisar tags...',

                prefixIcon: Icon(
                  Icons.search,
                ),

                border: OutlineInputBorder(),

                isDense: true,
              ),

              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
            ),
          ),

          // ==================================
          // TAGS SELECIONADAS
          // ==================================

          if (_selectedTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),

              child: Wrap(
                spacing: 6,
                runSpacing: 0,

                children: [
                  for (final tag in _selectedTags)
                    InputChip(
                      label: Text(tag.name),

                      selected: true,

                      onDeleted: () => _removeTag(tag),
                    ),
                ],
              ),
            ),

          // ==================================
          // SUGESTÕES DE TAGS
          // ==================================

          FutureBuilder<List<MediaTag>>(
            future: _tagsFuture,

            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final selectedIds = _selectedTags
                  .map((tag) => tag.id)
                  .toSet();

              final suggestions = snapshot.data!
                  .where(
                    (tag) =>
                        !selectedIds.contains(tag.id) &&
                        tag.name
                            .toLowerCase()
                            .contains(search),
                  )
                  .take(8)
                  .toList();

              if (suggestions.isEmpty) {
                return const SizedBox.shrink();
              }

              return Container(
                constraints: const BoxConstraints(
                  maxHeight: 190,
                ),

                child: ListView.builder(
                  shrinkWrap: true,

                  itemCount: suggestions.length,

                  itemBuilder: (context, index) {
                    final tag = suggestions[index];

                    return ListTile(
                      dense: true,

                      leading: const Icon(
                        Icons.tag,
                        size: 20,
                      ),

                      title: Text(tag.name),

                      onTap: () => _addTag(tag),
                    );
                  },
                ),
              );
            },
          ),

          const Divider(height: 1),

          // ==================================
          // GRADE DE RESULTADOS
          // ==================================

          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }
}