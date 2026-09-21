import 'package:flutter/material.dart';
import '../../data/media_catalog.dart';

/// O grupo é excluído sem apagar fotos/vídeos.
class GroupActionsMenu extends StatelessWidget {
  const GroupActionsMenu({
    super.key,
    required this.group,
    required this.onChanged,
  });

  final MediaGroup group;
  final void Function(bool deleted) onChanged;

  Future<void> _rename(BuildContext context) async {
    String editedName = group.name;

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Renomear grupo'),

          content: TextFormField(
            initialValue: group.name,
            autofocus: true,
            maxLength: 100,

            decoration: const InputDecoration(
              labelText: 'Nome do grupo',
            ),

            onChanged: (value) {
              editedName = value;
            },

            onFieldSubmitted: (value) {
              Navigator.of(dialogContext).pop(value.trim());
            },
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancelar'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  editedName.trim(),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (!context.mounted ||
        newName == null ||
        newName.trim().isEmpty) {
      return;
    }

    try {
      await MediaCatalog.instance.renameGroup(
        group.id,
        newName.trim(),
      );

      if (!context.mounted) return;

      onChanged(false);
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível renomear: $error',
          ),
        ),
      );
    }
  }
  
  Future<void> _delete(BuildContext context) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir grupo?'),
        content: const Text('As fotos e os vídeos serão mantidos no aplicativo, sem grupo. '
            'As tags que eram apenas do grupo deixarão de valer para eles.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Excluir grupo')),
        ],
      ),
    );
    if (approved != true || !context.mounted) return;
    try {
      await MediaCatalog.instance.deleteGroup(group.id);
      onChanged(true);
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível excluir: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Opções do grupo',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        if (action == 'rename') _rename(context);
        if (action == 'delete') _delete(context);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'rename', child: Text('Renomear grupo')),
        PopupMenuItem(value: 'delete', child: Text('Excluir grupo (manter mídias)')),
      ],
    );
  }
}
