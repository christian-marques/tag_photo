import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../core/storage/media_storage.dart';
import '../../data/media_catalog.dart';
import '../capture/camera_tag_picker.dart';
import '../groups/group_picker.dart';

class GalleryImportPage extends StatefulWidget {
  const GalleryImportPage({super.key, this.initialGroupId});
  final String? initialGroupId;

  @override
  State<GalleryImportPage> createState() => _GalleryImportPageState();
}

class _GalleryImportPageState extends State<GalleryImportPage> {
  final _catalog = MediaCatalog.instance;
  final _picker = ImagePicker();
  List<XFile> _picked = [];
  List<MediaTag> _tags = [];
  MediaGroup? _group;
  bool _busy = false;
  int _progress = 0;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.initialGroupId != null) _loadInitialGroup();
  }

  Future<void> _loadInitialGroup() async {
    final group = await _catalog.getGroup(widget.initialGroupId!);
    if (!mounted) return;
    setState(() {
      _group = group;
      _tags = List.of(group?.tags ?? []);
    });
  }

  Future<void> _pick() async {
    if (_busy) return;
    try {
      // Sem limites de largura/altura/quality: não solicitamos compressão.
      final files = await _picker.pickMultipleMedia();
      if (!mounted || files.isEmpty) return;
      setState(() {
        _picked = files;
        _message = null;
      });
    } catch (error) {
      _show('Erro ao selecionar mídias: $error');
    }
  }

  Future<void> _chooseGroup() async {
    final selection = await chooseGroup(context, initialTags: _tags);
    if (!mounted || selection == null) return;
    setState(() {
      _group = selection.group;
      if (_group != null) {
        _tags = List.of(_group!.tags);
      }
    });
  }

  Future<void> _editTags() async {
    final result = await showModalBottomSheet<List<MediaTag>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: CameraTagPicker(
            initialSelection: _tags,
            lockedTagIds: _group?.tags.map((t) => t.id).toSet() ?? {},
          ),
        ),
      ),
    );
    if (mounted && result != null) {
      setState(() {
        _tags = [
          ...?_group?.tags,
          for (final tag in result)
            if (!(_group?.tags.any((g) => g.id == tag.id) ?? false)) tag,
        ];
      });
    }
  }

  MediaKind _kind(XFile file) {
    const videoExts = {'.mp4', '.mov', '.m4v', '.3gp', '.webm', '.avi'};
    final extension = p.extension(file.name).toLowerCase();
    final mime = file.mimeType?.toLowerCase() ?? '';
    return videoExts.contains(extension) || mime.startsWith('video/')
        ? MediaKind.video : MediaKind.photo;
  }

  Future<void> _import() async {
    if (_busy || _picked.isEmpty) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _message = null;
    });
    var imported = 0;
    var failed = 0;
    final remaining = <XFile>[];
    for (final file in _picked) {
      try {
        await _catalog.saveCapturedMedia(
          file.path,
          kind: _kind(file),
          tagIds: _tags
              .where((tag) => !(_group?.tags.any((g) => g.id == tag.id) ?? false))
              .map((tag) => tag.id).toList(),
          groupId: _group?.id,
          importedFromGallery: true,
        );
        imported++;
      } catch (error) {
        failed++;
        remaining.add(file);
        debugPrint('Falha ao importar ${file.name}: $error');
      }
      if (mounted) setState(() => _progress = imported + failed);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _picked = remaining;
      _message = '$imported mídia(s) importada(s).'
          '${failed > 0 ? ' $failed falharam; tente novamente.' : ''}';
    });
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar da galeria')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(_picked.isEmpty
                ? 'Selecionar fotos e vídeos' : 'Trocar seleção (${_picked.length})'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _chooseGroup,
            icon: const Icon(Icons.folder_outlined),
            label: Text(_group?.name ?? 'Grupo (opcional)'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final tag in _tags)
                Chip(label: Text(tag.name)),
              ActionChip(label: const Text('+ Tags'),
                  onPressed: _busy ? null : _editTags),
            ],
          ),
          const SizedBox(height: 16),
          Text('${_picked.length} mídias selecionadas'),
          const SizedBox(height: 8),
          if (_picked.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _picked.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, mainAxisSpacing: 4, crossAxisSpacing: 4,
              ),
              itemBuilder: (context, index) {
                final item = _picked[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _kind(item) == MediaKind.video
                      ? const ColoredBox(color: Colors.black87,
                          child: Icon(Icons.play_circle_outline, color: Colors.white))
                      : Image.file(File(item.path), fit: BoxFit.cover,
                          cacheWidth: 250),
                );
              },
            ),
          const SizedBox(height: 16),
          if (_busy) ...[
            LinearProgressIndicator(value: _picked.isEmpty ? null : _progress / _picked.length),
            const SizedBox(height: 8),
            Text('Importando $_progress / ${_picked.length}...'),
          ],
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_message!, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          FilledButton.icon(
            onPressed: _busy || _picked.isEmpty ? null : _import,
            icon: const Icon(Icons.download_done),
            label: Text('Importar ${_picked.length} mídias'),
          ),
          const SizedBox(height: 12),
          const Text('Os originais são copiados para o app sem redimensionamento. '
              'Neste protótipo a data de mídias importadas é a data do cadastro; '
              'a leitura da data original (EXIF) ficará para outra etapa.'),
        ],
      ),
    );
  }
}
