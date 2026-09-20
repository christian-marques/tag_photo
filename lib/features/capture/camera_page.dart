
import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'captured_photo_page.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;

  List<CameraDescription> _cameras = [];

  int _cameraIndex = 0;
  int _cameraGeneration = 0;

  XFile? _lastPhoto;

  FlashMode _flashMode = FlashMode.off;
  bool _isFlashMenuOpen = false;

  double _minZoom = 1;
  double _maxZoom = 1;
  double _currentZoom = 1;
  double _baseZoom = 1;

  bool _isInitializing = true;
  bool _isTakingPicture = false;
  bool _isChangingCamera = false;
  bool _isShowingPhoto = false;
  bool _isInForeground = true;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _setupCamera();
  }

  // =================================================
  // INICIALIZAÇÃO
  // =================================================

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();

      if (!mounted) return;

      if (cameras.isEmpty) {
        throw Exception('Nenhuma câmera encontrada.');
      }

      _cameras = cameras;

      final backIndex = cameras.indexWhere(
        (camera) =>
            camera.lensDirection == CameraLensDirection.back,
      );

      _cameraIndex = backIndex >= 0 ? backIndex : 0;

      await _initializeCamera();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted ||
        !_isInForeground ||
        _isShowingPhoto ||
        _cameras.isEmpty) {
      return;
    }

    final generation = ++_cameraGeneration;

    final oldController = _controller;

    setState(() {
      _controller = null;
      _isInitializing = true;
      _errorMessage = null;
    });

    await oldController?.dispose();

    if (!mounted ||
        !_isInForeground ||
        _isShowingPhoto ||
        generation != _cameraGeneration) {
      return;
    }

    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.max,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      final minZoom =
          await controller.getMinZoomLevel();

      final maxZoom =
          await controller.getMaxZoomLevel();

      if (!mounted ||
          !_isInForeground ||
          _isShowingPhoto ||
          generation != _cameraGeneration) {
        await controller.dispose();
        return;
      }

      final initialZoom =
          1.0.clamp(minZoom, maxZoom).toDouble();

      await controller.setZoomLevel(initialZoom);

      setState(() {
        _controller = controller;

        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _currentZoom = initialZoom;
        _baseZoom = initialZoom;

        _flashMode = FlashMode.off;
        _isFlashMenuOpen = false;

        _isInitializing = false;
        _errorMessage = null;
      });
    } catch (error) {
      await controller.dispose();

      if (!mounted ||
          generation != _cameraGeneration) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _errorMessage = error.toString();
      });
    }
  }

  // =================================================
  // LIBERAR A CÂMERA
  // =================================================

  Future<void> _releaseCamera() async {
    ++_cameraGeneration;

    final controller = _controller;

    _controller = null;

    if (mounted) {
      setState(() {
        _isInitializing = true;
      });
    }

    await controller?.dispose();
  }

  // =================================================
  // CAPTURAR FOTO
  // =================================================

  Future<void> _takePicture() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPicture ||
        _isInitializing ||
        _isShowingPhoto) {
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
    } catch (error) {
      _showMessage(
        'Erro ao capturar foto: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  // =================================================
  // VISUALIZAR FOTO
  // =================================================

  Future<void> _openLastPhoto() async {
    final photo = _lastPhoto;

    if (photo == null ||
        _isShowingPhoto ||
        _isTakingPicture ||
        _isInitializing) {
      return;
    }

    _isShowingPhoto = true;

    // Desliga e libera a câmera antes de abrir a foto.

    await _releaseCamera();

    if (!mounted) return;

    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => CapturedPhotoPage(
            photoPath: photo.path,
          ),
        ),
      );
    } finally {
      // Quando o usuário volta, liga a câmera novamente.

      _isShowingPhoto = false;

      if (mounted && _isInForeground) {
        await _initializeCamera();
      }
    }
  }

  // =================================================
  // TROCAR CÂMERA
  // =================================================

  Future<void> _switchCamera() async {
    if (_isInitializing ||
        _isTakingPicture ||
        _isChangingCamera) {
      return;
    }

    final currentDirection =
        _cameras[_cameraIndex].lensDirection;

    final targetDirection =
        currentDirection == CameraLensDirection.front
            ? CameraLensDirection.back
            : CameraLensDirection.front;

    final targetIndex = _cameras.indexWhere(
      (camera) =>
          camera.lensDirection == targetDirection,
    );

    if (targetIndex < 0) return;

    setState(() {
      _isChangingCamera = true;
    });

    try {
      _cameraIndex = targetIndex;

      await _initializeCamera();
    } finally {
      if (mounted) {
        setState(() {
          _isChangingCamera = false;
        });
      }
    }
  }

  // =================================================
  // FLASH
  // =================================================


  Future<void> _setFlashMode(FlashMode mode) async {
    final controller = _controller;

    if (controller == null ||
        _isInitializing ||
        _isTakingPicture) {
      return;
    }

    try {
      await controller.setFlashMode(mode);

      if (!mounted || controller != _controller) {
        return;
      }

      setState(() {
        _flashMode = mode;

        // Fecha a barra depois de selecionar a opção.
        _isFlashMenuOpen = false;
      });
    } catch (error) {
      _showMessage(
        'Este modo de flash não está disponível nesta câmera.',
      );
    }
  }
 

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;

      case FlashMode.auto:
        return Icons.flash_auto;

      case FlashMode.always:
        return Icons.flash_on;

      case FlashMode.torch:
        return Icons.flashlight_on;
    }
  }

  Widget _flashOption({
    required FlashMode mode,
    required String label,
  }) {
    final isSelected = _flashMode == mode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),

      child: TextButton(
        onPressed: () => _setFlashMode(mode),

        style: TextButton.styleFrom(
          foregroundColor: isSelected
              ? Colors.amber
              : Colors.white,

          backgroundColor: isSelected
              ? Colors.white12
              : Colors.transparent,

          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),

        child: Text(
          label,

          maxLines: 1,

          style: TextStyle(
            fontSize: 13,

            fontWeight: isSelected
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // =================================================
  // ZOOM
  // =================================================

  Future<void> _setZoom(double requestedZoom) async {
    final controller = _controller;

    if (controller == null ||
        _isInitializing ||
        _isTakingPicture) {
      return;
    }

    final zoom = requestedZoom
        .clamp(_minZoom, _maxZoom)
        .toDouble();

    try {
      await controller.setZoomLevel(zoom);

      if (!mounted || controller != _controller) {
        return;
      }

      setState(() {
        _currentZoom = zoom;
      });
    } catch (error) {
      debugPrint('Erro no zoom: $error');
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _setZoom(_baseZoom * details.scale);
  }

  // =================================================
  // MENSAGENS
  // =================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =================================================
  // CICLO DE VIDA
  // =================================================

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.inactive) {
      _isInForeground = false;

      unawaited(_releaseCamera());
    } else if (state == AppLifecycleState.resumed) {
      _isInForeground = true;

      if (!_isShowingPhoto && !_isChangingCamera) {
        if (_cameras.isEmpty) {
          unawaited(_setupCamera());
        } else {
          unawaited(_initializeCamera());
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _isInForeground = false;

    _cameraGeneration++;

    final controller = _controller;

    _controller = null;

    controller?.dispose();

    super.dispose();
  }

  // =================================================
  // INTERFACE
  // =================================================

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Câmera'),
        centerTitle: true,
      ),

      body: SafeArea(
        child: Column(
          children: [
            // ÁREA PRINCIPAL DA CÂMERA

            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_errorMessage != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else if (controller == null ||
                      !controller.value.isInitialized)
                    const Center(
                      child: CircularProgressIndicator(),
                    )
                  else
                    GestureDetector(
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,

                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final aspectRatio =
                              controller.value.aspectRatio;

                          final isPortrait =
                              constraints.maxHeight >
                              constraints.maxWidth;

                          final previewWidth = isPortrait
                              ? constraints.maxWidth
                              : constraints.maxHeight *
                                  aspectRatio;

                          final previewHeight = isPortrait
                              ? constraints.maxWidth *
                                  aspectRatio
                              : constraints.maxHeight;

                          return ClipRect(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: previewWidth,
                                height: previewHeight,

                                child: CameraPreview(
                                  controller,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // FLASH NO CANTO SUPERIOR ESQUERDO

                  if (controller != null &&
                      controller.value.isInitialized)
                    Positioned(
                      top: 16,
                      left: 16,

                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isFlashMenuOpen = !_isFlashMenuOpen;
                          });
                        },

                        child: Container(
                          width: 48,
                          height: 48,

                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xCC292929),
                          ),

                          child: Icon(
                            _flashIcon,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),

                  // BARRA HORIZONTAL DE OPÇÕES DO FLASH

                  if (_isFlashMenuOpen &&
                      controller != null &&
                      controller.value.isInitialized)
                    Positioned(
                      top: 76,
                      left: 12,
                      right: 12,

                      child: Container(
                        height: 56,

                        decoration: BoxDecoration(
                          color: const Color(0xFF292929),

                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,

                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,

                            children: [
                              _flashOption(
                                mode: FlashMode.off,
                                label: 'Desativado',
                              ),

                              _flashOption(
                                mode: FlashMode.always,
                                label: 'Ativado',
                              ),

                              _flashOption(
                                mode: FlashMode.auto,
                                label: 'Automático',
                              ),

                              _flashOption(
                                mode: FlashMode.torch,
                                label: 'Sempre ativado',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),



                  // CONTROLES DE ZOOM

                  if (controller != null &&
                      controller.value.isInitialized)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,

                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,

                        children: [
                          if (_minZoom <= 0.6)
                            _zoomButton(0.6),

                          if (_minZoom <= 1 &&
                              _maxZoom >= 1)
                            _zoomButton(1),

                          if (_maxZoom >= 2)
                            _zoomButton(2),

                          if (_maxZoom >= 3)
                            _zoomButton(3),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // BARRA INFERIOR

            Container(
              height: 110,
              color: Colors.black,

              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),

              child: Row(
                children: [
                  // MINIATURA

                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: _lastPhoto == null
                            ? null
                            : _openLastPhoto,

                        child: Container(
                          width: 58,
                          height: 58,

                          decoration: BoxDecoration(
                            color: Colors.grey.shade900,

                            borderRadius:
                                BorderRadius.circular(10),
                          ),

                          clipBehavior: Clip.antiAlias,

                          child: _lastPhoto == null
                              ? const Icon(
                                  Icons.image_outlined,
                                  color: Colors.white54,
                                )
                              : Image.file(
                                  File(_lastPhoto!.path),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                  ),

                  // BOTÃO DE CAPTURA

                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: _isTakingPicture ||
                                _isInitializing
                            ? null
                            : _takePicture,

                        child: Container(
                          width: 84,
                          height: 84,

                          decoration: BoxDecoration(
                            shape: BoxShape.circle,

                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),

                          alignment: Alignment.center,

                          child: Container(
                            width: 66,
                            height: 66,

                            decoration: BoxDecoration(
                              shape: BoxShape.circle,

                              color: _isTakingPicture
                                  ? Colors.grey
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // TROCA DE CÂMERA

                  Expanded(
                    child: Center(
                      child: IconButton(
                        icon: const Icon(
                          Icons.cameraswitch_outlined,
                          size: 34,
                        ),

                        color: Colors.white,

                        onPressed: _isInitializing ||
                                _isChangingCamera ||
                                _isTakingPicture
                            ? null
                            : _switchCamera,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =================================================
  // BOTÃO DE ZOOM
  // =================================================

  Widget _zoomButton(double zoom) {
    final selected =
        (_currentZoom - zoom).abs() < 0.05;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
      ),

      child: GestureDetector(
        onTap: () => _setZoom(zoom),

        child: Container(
          width: selected ? 46 : 40,
          height: selected ? 46 : 40,

          alignment: Alignment.center,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            color: selected
                ? const Color(0xFF36302A)
                : Colors.black54,
          ),

          child: Text(
            '${zoom.toStringAsFixed(
              zoom == zoom.roundToDouble() ? 0 : 1,
            )}×',

            style: TextStyle(
              color: selected
                  ? Colors.amber
                  : Colors.white,

              fontWeight: selected
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}