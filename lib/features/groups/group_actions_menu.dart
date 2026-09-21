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
    var edited = group.name;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renomear sessão'),
        content: TextFormField(
          initialValue: group.name,
          autofocus: true,
          maxLength: 100,
          onChanged: (value) => edited = value,
          onFieldSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, edited.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (!context.mounted || name == null || name.isEmpty) return;
    try {
      await MediaCatalog.instance.renameGroup(group.id, name);
      if (context.mounted) onChanged(false);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível renomear: $error')),
        );
      }
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
