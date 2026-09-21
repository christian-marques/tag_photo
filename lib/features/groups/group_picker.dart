import 'package:flutter/material.dart';

import '../../data/media_catalog.dart';

/// null = cancelado; Selection(group: null) = continuar sem grupo.
class GroupSelection {
  const GroupSelection(this.group);
  final MediaGroup? group;
}

Future<GroupSelection?> chooseGroup(
  BuildContext context, {
  List<MediaTag> initialTags = const [],
}) {
  return showModalBottomSheet<GroupSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _GroupPicker(initialTags: initialTags),
  );
}

class _GroupPicker extends StatefulWidget {
  const _GroupPicker({required this.initialTags});
  final List<MediaTag> initialTags;

  @override
  State<_GroupPicker> createState() => _GroupPickerState();
}

class _GroupPickerState extends State<_GroupPicker> {
  final _catalog = MediaCatalog.instance;
  late final Future<List<MediaGroup>> _groups = _catalog.getGroups();
  bool _creating = false;

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Novo grupo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 90,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ex.: Passeio em Paris'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    // O TextEditingController não é utilizado depois que o diálogo fecha.
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _creating = true);
    try {
      final group = await _catalog.createGroup(
        name,
        widget.initialTags.map((tag) => tag.id).toList(),
      );
      if (mounted) Navigator.pop(context, GroupSelection(group));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível criar o grupo: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return SizedBox(
      height: height * 0.65,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Escolher grupo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Pode adicionar mídias a este grupo em qualquer dia.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _creating ? null : _createGroup,
              icon: const Icon(Icons.add),
              label: const Text('Criar grupo com as tags atuais'),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Continuar sem grupo'),
              onTap: () => Navigator.pop(context, const GroupSelection(null)),
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<MediaGroup>>(
                future: _groups,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Erro: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.isEmpty) {
                    return const Center(child: Text('Nenhum grupo criado ainda.'));
                  }
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final group = snapshot.data![index];
                      return ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(group.name),
                        subtitle: Text('${group.mediaCount} mídias • '
                            '${group.tags.map((t) => t.name).join(', ')}'),
                        onTap: () => Navigator.pop(context, GroupSelection(group)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
