
import 'package:flutter/material.dart';

import 'features/capture/camera_page.dart';

import 'features/media_library/media_library_page.dart';

import 'features/search/search_page.dart';
import 'features/groups/groups_page.dart';
import 'features/gallery_import/gallery_import_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const TagPhotoApp());
}

class TagPhotoApp extends StatelessWidget {
  const TagPhotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tag Photo',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),

      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tag Photo'),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const SizedBox(height: 30),

            const Icon(
              Icons.photo_library_outlined,
              size: 90,
              color: Colors.blue,
            ),

            const SizedBox(height: 20),

            const Text(
              'Organize suas fotos e vídeos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Adicione tags e encontre suas mídias '
              'com facilidade.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 50),

            // ABRIR CÂMERA

            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraPage(),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Tirar fotos'),
            ),

            const SizedBox(height: 16),

            // IMPORTAR DA GALERIA

            OutlinedButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const GalleryImportPage()),
              ),
              icon: const Icon(Icons.photo_library),
              label: const Text('Adicionar fotos e vídeos'),
            ),

            const SizedBox(height: 16),

            // BUSCAR MÍDIAS

            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchPage(),
                  ),
                );
              },

              icon: const Icon(Icons.search),

              label: const Text('Buscar fotos e vídeos'),
            ),

            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const GroupsPage()),
              ),
              icon: const Icon(Icons.folder_outlined),
              label: const Text('Meus grupos'),
            ),

            // MINHAS MÍDIAS

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const MediaLibraryPage(),
                  ),
                );
              },

              icon: const Icon(
                Icons.perm_media_outlined,
              ),

              label: const Text(
                'Minhas mídias',
              ),
            ),

          ],
        ),
      ),
    );
  }
}