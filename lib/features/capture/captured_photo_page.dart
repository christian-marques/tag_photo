
import 'dart:io';

import 'package:flutter/material.dart';

class CapturedPhotoPage extends StatelessWidget {
  const CapturedPhotoPage({
    super.key,
    required this.photoPath,
  });

  final String photoPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Foto capturada'),
        centerTitle: true,
      ),

      body: SafeArea(
        child: SizedBox.expand(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,

            child: Image.file(
              File(photoPath),
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