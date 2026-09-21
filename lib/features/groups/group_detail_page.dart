import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/storage/media_storage.dart';
import '../../data/media_catalog.dart';
import '../capture/camera_page.dart';
import '../capture/camera_tag_picker.dart';
import '../capture/captured_photo_page.dart';
import '../capture/captured_video_page.dart';
import '../gallery_import/gallery_import_page.dart';
import 'existing_media_picker_page.dart';
import 'groups_page.dart';
import 'group_actions_menu.dart';

class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({super.key, required this.groupId, this.matchingPaths});
  final String groupId;
  /// Quando aberto pela busca, exibe inicialmente só os resultados filtrados.
  final Set<String>? matchingPaths;

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final _catalog = MediaCatalog.instance;
  late Future<MediaGroup?> _group;
  late Future<List<GroupMedia>> _media;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _group = _catalog.getGroup(widget.groupId);
    _media = _catalog.getMediaInGroup(widget.groupId);
  }

  void _reload() {
    setState(() {
      _group = _catalog.getGroup(widget.groupId);
      _media = _catalog.getMediaInGroup(widget.groupId);
    });
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.push<void>(
      context, MaterialPageRoute(builder: (context) => page),
    );
    if (mounted) _reload();
  }

  Future<void> _editGroupTags(MediaGroup group) async {
    final result = await showModalBottomSheet<List<MediaTag>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: CameraTagPicker(initialSelection: group.tags),
        ),
      ),
    );
    if (!mounted || result == null) return;
    try {
      await _catalog.setGroupTags(
        group.id, result.map((tag) => tag.id).toList(),
      );
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar grupo: $error')),
        );
      }
    }
  }

  Future<void> _openMedia(SavedMedia media) async {
    await _openPage(media.kind == MediaKind.photo
        ? CapturedPhotoPage(photoPath: media.file.path)
        : CapturedVideoPage(videoPath: media.file.path));
  }

  Widget _mediaGrid(List<GroupMedia> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 5, mainAxisSpacing: 5,
      ),
      itemBuilder: (context, index) {
        final media = items[index].media;
        return InkWell(
          onTap: () => _openMedia(media),
          onLongPress: () async {
            final yes = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Retirar mídia deste grupo?'),
                content: const Text('A mídia será mantida na biblioteca. Tags individuais permanecem.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retirar')),
                ],
              ),
            );
            if (yes != true || !mounted) return;
            await _catalog.removeMediaFromGroup(media.file.path);
            if (mounted) _reload();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: media.kind == MediaKind.video
                ? const ColoredBox(color: Colors.black87,
                    child: Icon(Icons.play_circle_outline,
                        color: Colors.white, size: 38))
                : Image.file(File(media.file.path), fit: BoxFit.cover,
                    cacheWidth: 300),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MediaGroup?>(
      future: _group,
      builder: (context, groupSnapshot) {
        final group = groupSnapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(group?.name ?? 'Sessão'),
            actions: [
              if (group != null) GroupActionsMenu(
                group: group,
                onChanged: (deleted) {
                  if (deleted) {
                    Navigator.pop(context);
                  } else {
                    _reload();
                  }
                },
              ),
            ],
          ),
          body: !groupSnapshot.hasData
              ? const Center(child: CircularProgressIndicator())
              : group == null
                  ? const Center(child: Text('Grupo não encontrado.'))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          for (final tag in group.tags) Chip(label: Text(tag.name)),
                          ActionChip(label: const Text('+ Tags da sessão'),
                              onPressed: () => _editGroupTags(group)),
                        ]),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => _openPage(CameraPage(initialGroupId: group.id)),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Continuar fotografando / gravando'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openPage(GalleryImportPage(initialGroupId: group.id)),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Importar da galeria'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openPage(ExistingMediaPickerPage(groupId: group.id)),
                          icon: const Icon(Icons.add_to_photos_outlined),
                          label: const Text('Adicionar mídias já cadastradas'),
                        ),
                        const Divider(height: 28),
                        FutureBuilder<List<GroupMedia>>(
                          future: _media,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text('Erro ao carregar mídias: ${snapshot.error}');
                            }
                            if (!snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final allMedia = snapshot.data!;
                            final media = !_showAll && widget.matchingPaths != null
                                ? allMedia.where((item) => widget.matchingPaths!.contains(item.media.file.path)).toList()
                                : allMedia;
                            if (media.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('Nenhuma mídia corresponde ao filtro neste grupo.'),
                              );
                            }
                            final byDate = <String, List<GroupMedia>>{};
                            for (final item in media) {
                              final key = item.date == null ? 'Data não informada' : groupDate(item.date!);
                              byDate.putIfAbsent(key, () => []).add(item);
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.matchingPaths != null && !_showAll)
                                  TextButton.icon(
                                    onPressed: () => setState(() => _showAll = true),
                                    icon: const Icon(Icons.filter_alt_off),
                                    label: Text('Mostrando ${media.length} resultado(s) · Ver todas'),
                                  ),
                                Text('${media.length} mídias',
                                    style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 12),
                                for (final entry in byDate.entries) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(entry.key,
                                        style: Theme.of(context).textTheme.titleMedium),
                                  ),
                                  _mediaGrid(entry.value),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
        );
      },
    );
  }
}
