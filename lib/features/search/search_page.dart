import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/storage/media_storage.dart';
import '../../data/media_catalog.dart';
import '../capture/captured_photo_page.dart';
import '../capture/captured_video_page.dart';
import '../groups/group_actions_menu.dart';
import '../groups/group_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchRow {
  _SearchRow.group(MediaGroup value, List<MediaSearchEntry> matches)
      : group = value,
        items = matches,
        solo = null,
        date = _latestDate(matches);

  _SearchRow.media(MediaSearchEntry entry)
      : solo = entry,
        group = null,
        items = const [],
        date = entry.capturedAt;

  final MediaGroup? group;
  final MediaSearchEntry? solo;
  final List<MediaSearchEntry> items;
  final DateTime? date;

  static DateTime? _latestDate(List<MediaSearchEntry> items) {
    DateTime? latest;
    for (final item in items) {
      final date = item.capturedAt;
      if (date != null && (latest == null || date.isAfter(latest))) {
        latest = date;
      }
    }
    return latest;
  }
}

class _SearchPageState extends State<SearchPage> {
  final _catalog = MediaCatalog.instance;
  final _searchController = TextEditingController();
  final _selectedTags = <MediaTag>[];
  late Future<List<MediaTag>> _tagsFuture;
  late Future<List<_SearchRow>> _resultsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tagsFuture = _catalog.getAllTags();
    _resultsFuture = _loadResults();
  }

  Future<List<_SearchRow>> _loadResults() async {
    final entries = await _catalog.searchEntries(
      _selectedTags.map((tag) => tag.id).toList(),
    );
    final groups = await _catalog.getGroups();
    final groupById = {for (final group in groups) group.id: group};
    final grouped = <String, List<MediaSearchEntry>>{};
    final results = <_SearchRow>[];
    for (final entry in entries) {
      final groupId = entry.groupId;
      if (groupId != null && groupById.containsKey(groupId)) {
        grouped.putIfAbsent(groupId, () => []).add(entry);
      } else {
        results.add(_SearchRow.media(entry));
      }
    }
    for (final entry in grouped.entries) {
      results.add(_SearchRow.group(groupById[entry.key]!, entry.value));
    }
    results.sort((a, b) {
      if (a.date == null) return b.date == null ? 0 : 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    return results;
  }

  void _refresh() {
    setState(() {
      _tagsFuture = _catalog.getAllTags();
      _resultsFuture = _loadResults();
    });
  }

  void _addTag(MediaTag tag) {
    if (_selectedTags.any((selected) => selected.id == tag.id)) return;
    _selectedTags.add(tag);
    _searchController.clear();
    _query = '';
    _refresh();
  }

  void _removeTag(MediaTag tag) {
    _selectedTags.removeWhere((selected) => selected.id == tag.id);
    _refresh();
  }

  Future<void> _openMedia(MediaSearchEntry entry) async {
    final media = entry.media;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => media.kind == MediaKind.photo
            ? CapturedPhotoPage(photoPath: media.file.path)
            : CapturedVideoPage(videoPath: media.file.path),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _openGroup(_SearchRow row) async {
    final group = row.group!;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailPage(
          groupId: group.id,
          matchingPaths: _selectedTags.isEmpty
              ? null
              : row.items.map((entry) => entry.media.file.path).toSet(),
        ),
      ),
    );
    if (mounted) _refresh();
  }

  String _date(DateTime? value) {
    if (value == null) return 'Data não informada';
    final date = value.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _thumbnail(SavedMedia media) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: media.kind == MediaKind.photo
            ? Image.file(
                File(media.file.path),
                width: 68,
                height: 68,
                fit: BoxFit.cover,
                cacheWidth: 160,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 68,
                  height: 68,
                  child: Icon(Icons.broken_image_outlined),
                ),
              )
            : const SizedBox(
                width: 68,
                height: 68,
                child: ColoredBox(
                  color: Color(0xFF303030),
                  child: Icon(Icons.play_circle_outline, color: Colors.white),
                ),
              ),
      );

  Widget _tagStrip(List<MediaTag> tags) => SizedBox(
        height: 25,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tags.length,
          separatorBuilder: (_, __) => const SizedBox(width: 5),
          itemBuilder: (_, index) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(tags[index].name, style: const TextStyle(fontSize: 11)),
          ),
        ),
      );

  Widget _resultTile(_SearchRow row) {
    final group = row.group;
    final solo = row.solo;
    final sample = group != null ? row.items.first : solo!;
    final tags = group == null
        ? solo!.tags
        : <MediaTag>[
            ...group.tags,
            for (final entry in row.items)
              for (final tag in entry.tags)
                if (!group.tags.any((existing) => existing.id == tag.id)) tag,
          ];
    final uniqueTags = <String, MediaTag>{for (final tag in tags) tag.id: tag};
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: _thumbnail(sample.media),
      title: Text(group?.name ?? (solo!.media.kind == MediaKind.photo ? 'Foto sem grupo' : 'Vídeo sem grupo'),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group == null
              ? _date(solo!.capturedAt)
              : '${_date(row.date)} · ${row.items.length} mídia(s) encontrada(s)',
              style: Theme.of(context).textTheme.bodySmall),
          if (uniqueTags.isNotEmpty) ...[
            const SizedBox(height: 4),
            _tagStrip(uniqueTags.values.toList()),
          ],
        ],
      ),
      trailing: group == null
          ? const Icon(Icons.chevron_right)
          : GroupActionsMenu(group: group, onChanged: (_) => _refresh()),
      onTap: () => group != null ? _openGroup(row) : _openMedia(solo!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar mídias')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Digite para buscar uma tag...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (_selectedTags.isNotEmpty)
            SizedBox(
              height: 43,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _selectedTags.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, index) {
                  final tag = _selectedTags[index];
                  return InputChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(tag.name),
                    onDeleted: () => _removeTag(tag),
                  );
                },
              ),
            ),
          // Sugestões apenas enquanto o usuário digita: não listamos milhares de tags.
          if (_query.trim().isNotEmpty)
            FutureBuilder<List<MediaTag>>(
              future: _tagsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final query = _query.trim().toLowerCase();
                final excluded = _selectedTags.map((tag) => tag.id).toSet();
                final suggestions = snapshot.data!
                    .where((tag) => !excluded.contains(tag.id) && tag.name.toLowerCase().contains(query))
                    .take(6)
                    .toList();
                if (suggestions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Nenhuma tag correspondente.'),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 190),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.tag),
                      title: Text(suggestions[index].name),
                      onTap: () => _addTag(suggestions[index]),
                    ),
                  ),
                );
              },
            ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<_SearchRow>>(
              future: _resultsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao buscar: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!;
                if (rows.isEmpty) {
                  return const Center(child: Text('Nenhuma mídia encontrada.'));
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => _resultTile(rows[index]),
                );
              },
            ),
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
