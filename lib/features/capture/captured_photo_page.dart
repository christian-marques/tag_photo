
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/sharing/media_share_service.dart';

class CapturedPhotoPage extends StatefulWidget {
  const CapturedPhotoPage({
    super.key,
    required this.photoPath,
  });

  final String photoPath;

  @override
  State<CapturedPhotoPage> createState() =>
      _CapturedPhotoPageState();
}

class _CapturedPhotoPageState
    extends State<CapturedPhotoPage> {
  final MediaShareService _shareService =
      const MediaShareService();

  bool _isSharing = false;

  Future<void> _sharePhoto() async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
    });

    try {
      await _shareService.shareMedia(widget.photoPath);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível compartilhar a foto: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,

        title: const Text('Foto capturada'),

        centerTitle: true,

        actions: [
          IconButton(
            tooltip: 'Compartilhar foto',

            onPressed: _isSharing
                ? null
                : _sharePhoto,

            icon: const Icon(
              Icons.share_outlined,
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: SizedBox.expand(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,

            child: Image.file(
              File(widget.photoPath),

              fit: BoxFit.contain,

              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return const Center(
                  child: Text(
                    'Não foi possível abrir a foto.',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}