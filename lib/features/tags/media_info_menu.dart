import 'package:flutter/material.dart';
import '../../data/media_catalog.dart';

class MediaInfoMenu extends StatelessWidget {
  const MediaInfoMenu({super.key, required this.mediaPath, this.beforeOpen});
  final String mediaPath;
  final Future<void> Function()? beforeOpen;

  Future<void> _editDate(BuildContext context) async {
    await beforeOpen?.call();
    final current = await MediaCatalog.instance.getMediaCapturedAt(mediaPath);
    if (!context.mounted) return;
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'Data original da mídia',
    );
    if (selected == null) return;
    try {
      await MediaCatalog.instance.setMediaCapturedAt(mediaPath, selected);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data atualizada.')),
      );
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar data: $error')),
      );
    }
  }

  Future<void> _leaveGroup(BuildContext context) async {
    await beforeOpen?.call();
    final group = await MediaCatalog.instance.getGroupForMedia(mediaPath);
    if (!context.mounted) return;
    if (group == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta mídia não pertence a nenhum grupo.')),
      );
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirar mídia do grupo?'),
        content: Text('A mídia sairá de "${group.name}". O arquivo e as tags individuais serão mantidos; as tags herdadas do grupo deixarão de valer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Retirar')),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await MediaCatalog.instance.removeMediaFromGroup(mediaPath);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mídia retirada do grupo.')),
    );
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Mais opções da mídia',
    icon: const Icon(Icons.more_vert),
    onSelected: (action) async {
      try {
        if (action == 'date') await _editDate(context);
        if (action == 'group') await _leaveGroup(context);
      } catch (error) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível concluir a ação: $error')),
        );
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'date', child: Text('Corrigir data da mídia')),
      PopupMenuItem(value: 'group', child: Text('Retirar do grupo')),
    ],
  );
}
