
import 'package:flutter/material.dart';

import '../../data/media_catalog.dart';
import '../capture/camera_tag_picker.dart';

class MediaTagEditButton extends StatefulWidget {
  const MediaTagEditButton({
    super.key,
    required this.mediaPath,
    this.beforeOpen,
  });

  final String mediaPath;

  // Permite pausar o vídeo antes de editar suas tags.
  final Future<void> Function()? beforeOpen;

  @override
  State<MediaTagEditButton> createState() =>
      _MediaTagEditButtonState();
}

class _MediaTagEditButtonState
    extends State<MediaTagEditButton> {
  final MediaCatalog _catalog = MediaCatalog.instance;

  bool _isEditing = false;

  Future<void> _editTags() async {
    if (_isEditing) return;

    setState(() {
      _isEditing = true;
    });

    try {
      // Pausa o vídeo, quando necessário.
      await widget.beforeOpen?.call();

      // Carrega as tags atuais da mídia.
      final currentTags =
          await _catalog.getTagsForMedia(
        widget.mediaPath,
      );

      if (!mounted) return;

      // Abre o seletor que já utilizamos na câmera.
      final selected =
          await showModalBottomSheet<List<MediaTag>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,

        builder: (sheetContext) {
          final screenHeight =
              MediaQuery.sizeOf(sheetContext).height;

          final keyboardHeight =
              MediaQuery.viewInsetsOf(
            sheetContext,
          ).bottom;

          final availableHeight =
              screenHeight - keyboardHeight - 100;

          return Padding(
            padding: EdgeInsets.only(
              bottom: keyboardHeight,
            ),

            child: SizedBox(
              height: availableHeight.clamp(
                180.0,
                screenHeight * 0.65,
              ).toDouble(),

              child: CameraTagPicker(
                initialSelection: currentTags,
              ),
            ),
          );
        },
      );

      // O usuário fechou sem concluir.
      if (!mounted || selected == null) return;

      // Salva a nova seleção no banco.
      await _catalog.setTagsForMedia(
        widget.mediaPath,
        selected.map((tag) => tag.id).toList(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tags atualizadas!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao editar tags: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isEditing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Editar tags',

      onPressed: _isEditing
          ? null
          : _editTags,

      icon: _isEditing
          ? const SizedBox(
              width: 20,
              height: 20,

              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          : const Icon(
              Icons.sell_outlined,
            ),
    );
  }
}