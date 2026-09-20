
import 'package:flutter/material.dart';

import '../../data/media_catalog.dart';

class CameraTagPicker extends StatefulWidget {
  const CameraTagPicker({
    super.key,
    required this.initialSelection,
  });

  final List<MediaTag> initialSelection;

  @override
  State<CameraTagPicker> createState() =>
      _CameraTagPickerState();
}

class _CameraTagPickerState extends State<CameraTagPicker> {
  final MediaCatalog _catalog = MediaCatalog.instance;

  final TextEditingController _searchController =
      TextEditingController();

  List<MediaTag> _allTags = [];
  List<MediaTag> _selectedTags = [];

  String _search = '';

  bool _isLoading = true;
  bool _isCreating = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _selectedTags = List.of(widget.initialSelection);

    _loadTags();
  }

  // Carrega as tags cadastradas no banco.

  Future<void> _loadTags() async {
    try {
      final tags = await _catalog.getAllTags();

      if (!mounted) return;

      setState(() {
        _allTags = tags;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  // Verifica se uma tag já está selecionada.

  bool _isSelected(MediaTag tag) {
    return _selectedTags.any(
      (selected) => selected.id == tag.id,
    );
  }

  // Adiciona ou remove uma tag da seleção.

  void _toggleTag(MediaTag tag) {
    setState(() {
      if (_isSelected(tag)) {
        _selectedTags.removeWhere(
          (selected) => selected.id == tag.id,
        );
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  // Cria uma tag sem sair do painel.

  Future<void> _createTag() async {
    final name = _searchController.text.trim();

    if (name.isEmpty || _isCreating) return;

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final tag = await _catalog.createTag(name);

      if (!mounted) return;

      setState(() {
        // Inclui a nova tag na lista de sugestões.

        if (!_allTags.any((item) => item.id == tag.id)) {
          _allTags.add(tag);
        }

        // Seleciona automaticamente a tag criada.

        if (!_isSelected(tag)) {
          _selectedTags.add(tag);
        }

        _search = '';
        _searchController.clear();
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  // Conclui a seleção e retorna à câmera.

  void _finishSelection() {
    Navigator.pop(
      context,
      List<MediaTag>.of(_selectedTags),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = _search.trim().toLowerCase();

    final filteredTags = _allTags.where((tag) {
      return tag.name.toLowerCase().contains(search);
    }).toList();

    // Se a tag digitada ainda não existir,
    // oferecemos a opção de criá-la.

    final exactMatch = _allTags.any(
      (tag) => tag.name.toLowerCase() == search,
    );

    final canCreate =
        search.isNotEmpty && !exactMatch;

    return Material(
      color: Theme.of(context).colorScheme.surface,

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            // TÍTULO

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Adicionar tags',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // CAMPO DE PESQUISA

            TextField(
              controller: _searchController,

              autofocus: true,

              textCapitalization:
                  TextCapitalization.sentences,

              decoration: const InputDecoration(
                hintText: 'Digite uma tag...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),

              onChanged: (value) {
                setState(() {
                  _search = value;
                });
              },

              onSubmitted: (_) {
                if (canCreate) {
                  _createTag();
                } else if (filteredTags.isNotEmpty) {
                  _toggleTag(filteredTags.first);
                  _searchController.clear();

                  setState(() {
                    _search = '';
                  });
                }
              },
            ),

            const SizedBox(height: 12),

            // TAGS JÁ SELECIONADAS

            if (_selectedTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),

                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,

                  child: Row(
                    children: _selectedTags.map((tag) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          right: 6,
                        ),

                        child: InputChip(
                          label: Text(tag.name),

                          selected: true,

                          onDeleted: () {
                            _toggleTag(tag);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            // LISTA DE SUGESTÕES

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior
                              .onDrag,

                      children: [
                        // OPÇÃO DE CRIAÇÃO RÁPIDA

                        if (canCreate)
                          ListTile(
                            leading: const Icon(
                              Icons.add_circle_outline,
                            ),

                            title: Text(
                              'Criar "$_search"',
                            ),

                            onTap: _isCreating
                                ? null
                                : _createTag,
                          ),

                        // TAGS EXISTENTES

                        for (final tag in filteredTags)
                          CheckboxListTile(
                            title: Text(tag.name),

                            value: _isSelected(tag),

                            controlAffinity:
                                ListTileControlAffinity
                                    .leading,

                            onChanged: (_) {
                              _toggleTag(tag);
                            },
                          ),

                        if (filteredTags.isEmpty && !canCreate)
                          const Padding(
                            padding: EdgeInsets.all(16),

                            child: Center(
                              child: Text(
                                'Nenhuma tag encontrada.',
                              ),
                            ),
                          ),
                      ],
                    ),
            ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),

                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .error,
                  ),
                ),
              ),

            // BOTÃO PARA VOLTAR À CÂMERA

            FilledButton(
              onPressed: _isCreating
                  ? null
                  : _finishSelection,

              child: Text(
                'Concluir (${_selectedTags.length})',
              ),
            ),
          ],
        ),
      ),
    );
  }
}