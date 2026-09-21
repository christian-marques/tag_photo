import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/storage/media_storage.dart';
import '../../data/media_catalog.dart';

class ExistingMediaPickerPage extends StatefulWidget {
  const ExistingMediaPickerPage({super.key, required this.groupId});
  final String groupId;

  @override
  State<ExistingMediaPickerPage> createState() => _ExistingMediaPickerPageState();
}

class _ExistingMediaPickerPageState extends State<ExistingMediaPickerPage> {
  final _catalog = MediaCatalog.instance;
  late final Future<List<SavedMedia>> _media = _catalog.getSavedMedia();
  final Set<String> _selected = {};
  bool _saving = false;

  Future<void> _save() async {
    if (_selected.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await _catalog.attachMediaToGroup(widget.groupId, _selected.toList());
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar mídias: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mídias já cadastradas')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _saving || _selected.isEmpty ? null : _save,
            child: Text(_saving ? 'Adicionando...' : 'Adicionar ${_selected.length} ao grupo'),
          ),
        ),
      ),
      body: FutureBuilder<List<SavedMedia>>(
        future: _media,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('Nenhuma mídia cadastrada.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              final media = items[index];
              final path = media.file.path;
              final selected = _selected.contains(path);
              return InkWell(
                onTap: _saving ? null : () => setState(() {
                  if (selected) {
                    _selected.remove(path);
                  } else {
                    _selected.add(path);
                  }
                }),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: media.kind == MediaKind.video
                          ? const ColoredBox(color: Colors.black87,
                              child: Icon(Icons.play_circle_outline,
                                  color: Colors.white, size: 40))
                          : Image.file(File(path), fit: BoxFit.cover, cacheWidth: 300),
                    ),
                    Positioned(
                      top: 3, right: 3,
                      child: Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                          color: selected ? Colors.greenAccent : Colors.white,
                          shadows: const [Shadow(color: Colors.black, blurRadius: 4)]),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
