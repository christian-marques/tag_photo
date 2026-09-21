import 'package:flutter/material.dart';

import '../../data/media_catalog.dart';
import 'group_detail_page.dart';
import 'group_picker.dart';

String groupDate(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  late Future<List<MediaGroup>> _future;

  @override
  void initState() {
    super.initState();
    _future = MediaCatalog.instance.getGroups();
  }

  void _reload() => setState(() => _future = MediaCatalog.instance.getGroups());

  Future<void> _create() async {
    final selection = await chooseGroup(context);
    if (!mounted || selection?.group == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) =>
          GroupDetailPage(groupId: selection!.group!.id)),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grupos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Novo grupo'),
      ),
      body: FutureBuilder<List<MediaGroup>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar grupos: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return const Center(child: Text('Crie um grupo para reunir mídias de vários dias.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final group = snapshot.data![index];
                final period = group.firstMediaAt == null
                    ? 'Sem mídias ainda'
                    : groupDate(group.firstMediaAt!) == groupDate(group.lastMediaAt!)
                        ? groupDate(group.firstMediaAt!)
                        : '${groupDate(group.firstMediaAt!)} – ${groupDate(group.lastMediaAt!)}';
                return ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(group.name),
                  subtitle: Text('${group.mediaCount} mídias • $period\n'
                      '${group.tags.map((t) => t.name).join(' • ')}'),
                  isThreeLine: group.tags.isNotEmpty,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(builder: (context) =>
                          GroupDetailPage(groupId: group.id)),
                    );
                    if (mounted) _reload();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
