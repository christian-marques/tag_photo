
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tag_photo/main.dart';

void main() {
  testWidgets(
    'A tela inicial apresenta as funcionalidades principais',
    (WidgetTester tester) async {
      await tester.pumpWidget(const TagPhotoApp());

      expect(
        find.text('Tag Photo'),
        findsOneWidget,
      );

      expect(
        find.text('Tirar fotos'),
        findsOneWidget,
      );

      expect(
        find.text('Adicionar fotos e vídeos'),
        findsOneWidget,
      );

      expect(
        find.text('Buscar fotos e vídeos'),
        findsOneWidget,
      );

      expect(
        find.byIcon(Icons.camera_alt),
        findsOneWidget,
      );
    },
  );
}