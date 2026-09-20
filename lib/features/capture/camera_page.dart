
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;

  XFile? _lastPhoto;

  String? _errorMessage;

  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('Nenhuma câmera encontrada.');
      }

      final camera = cameras.firstWhere(
        (camera) =>
            camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.max,
        enableAudio: false,
      );

      _controller = controller;

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    try {
      setState(() {
        _isTakingPicture = true;
      });

      final photo = await controller.takePicture();

      if (!mounted) return;

      setState(() {
        _lastPhoto = photo;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto capturada com sucesso!'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao capturar foto: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;

    if (controller == null) return;

    if (state == AppLifecycleState.inactive) {
      _controller = null;
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _controller?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        title: const Text('Câmera'),
      ),

      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _errorMessage != null
                  ? Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    )
                  : controller == null ||
                          !controller.value.isInitialized
                      ? const CircularProgressIndicator()
                      : CameraPreview(controller),
            ),
          ),

          if (_lastPhoto != null)
            SizedBox(
              height: 100,
              child: Image.file(
                File(_lastPhoto!.path),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton.icon(
              onPressed: _isTakingPicture ||
                      controller == null ||
                      !controller.value.isInitialized
                  ? null
                  : _takePicture,

              icon: const Icon(Icons.camera_alt),

              label: const Text('Tirar foto'),
            ),
          ),
        ],
      ),
    );
  }
}