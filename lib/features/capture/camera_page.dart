
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
  bool _isInitializing = true;
  bool _isTakingPicture = false;
  bool _isShowingPhoto = false;
  bool _isInForeground = true;

  double _minZoom = 1;
  double _maxZoom = 1;
  double _currentZoom = 1;
  double _baseZoom = 1;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _setupCamera();
  }

  // ==================================================
  // INICIALIZAÇÃO DA CÂMERA
  // ==================================================

  Future<void> _setupCamera() async {
    try {
      _cameras = await availableCameras();

      if (!mounted) return;

      if (_cameras.isEmpty) {
        throw Exception('Nenhuma câmera encontrada.');
      }

      final backIndex = _cameras.indexWhere(
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
      _isFlashMenuOpen = false;
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

      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        // Algumas câmeras não possuem flash.
      }

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

  Future<void> _releaseCamera() async {
    ++_cameraGeneration;

    final controller = _controller;

    _controller = null;

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _isFlashMenuOpen = false;
      });
    }

    await controller?.dispose();
  }

  // ==================================================
  // CAPTURA E VISUALIZAÇÃO
  // ==================================================

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
        _isFlashMenuOpen = false;
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

  Future<void> _openLastPhoto() async {
    final photo = _lastPhoto;

    if (photo == null ||
        _isShowingPhoto ||
        _isTakingPicture ||
        _isInitializing) {
      return;
    }

    _isShowingPhoto = true;

    // Desliga a câmera antes de abrir a foto.

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
      _isShowingPhoto = false;

      if (mounted && _isInForeground) {
        await _initializeCamera();
      }
    }
  }

  // ==================================================
  // TROCA DE CÂMERA
  // ==================================================

  Future<void> _switchCamera() async {
    if (_isInitializing ||
        _isTakingPicture ||
        _cameras.isEmpty) {
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

    _cameraIndex = targetIndex;

    await _initializeCamera();
  }

  // ==================================================
  // FLASH
  // ==================================================

  Future<void> _setFlashMode(FlashMode mode) async {
    final controller = _controller;

    if (controller == null ||
        _isInitializing ||
        _isTakingPicture) {
      return;
    }

    try {
      await controller.setFlashMode(mode);

      if (!mounted ||
          controller != _controller) {
        return;
      }

      setState(() {
        _flashMode = mode;
        _isFlashMenuOpen = false;
      });
    } catch (error) {
      _showMessage(
        'Este modo de flash não está disponível.',
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

  // ==================================================
  // NOVO CABEÇALHO DO FLASH
  // ==================================================

  Widget _buildFlashHeader(bool cameraReady) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,

      child: Container(
        width: double.infinity,
        color: Colors.black,

        padding: const EdgeInsets.fromLTRB(
          16,
          4,
          16,
          12,
        ),

        child: !_isFlashMenuOpen
            ? SizedBox(
                height: 48,

                child: Align(
                  alignment: Alignment.centerLeft,

                  child: IconButton(
                    tooltip: 'Configurar flash',

                    onPressed: cameraReady
                        ? () {
                            setState(() {
                              _isFlashMenuOpen = true;
                            });
                          }
                        : null,

                    style: IconButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF292929),

                      minimumSize: const Size(
                        46,
                        46,
                      ),

                      fixedSize: const Size(
                        46,
                        46,
                      ),
                    ),

                    icon: Icon(
                      _flashIcon,
                      size: 25,
                      color: Colors.white,
                    ),
                  ),
                ),
              )

            // MENU ABERTO:
            // O ÍCONE DESAPARECE E A BARRA TOMA SEU LUGAR.

            : Container(
                height: 64,

                alignment: Alignment.center,

                decoration: BoxDecoration(
                  color: const Color(0xFF292929),

                  borderRadius:
                      BorderRadius.circular(12),
                ),

                child: Row(
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
    );
  }

  // ==================================================
  // OPÇÃO INDIVIDUAL DO FLASH
  // ==================================================

  Widget _flashOption({
    required FlashMode mode,
    required String label,
  }) {
    final isSelected = _flashMode == mode;

    return Expanded(
      child: InkWell(
        onTap: () => _setFlashMode(mode),

        borderRadius: BorderRadius.circular(8),

        child: SizedBox(
          height: 64,

          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 2,
              ),

              child: FittedBox(
                fit: BoxFit.scaleDown,

                child: Text(
                  label,

                  maxLines: 1,
                  softWrap: false,

                  style: TextStyle(
                    fontSize: 12,

                    color: isSelected
                        ? Colors.amber
                        : Colors.white,

                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================================================
  // ZOOM
  // ==================================================

  Future<void> _setZoom(
    double requestedZoom,
  ) async {
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

      if (!mounted ||
          controller != _controller) {
        return;
      }

      setState(() {
        _currentZoom = zoom;
      });
    } catch (error) {
      debugPrint('Erro no zoom: $error');
    }
  }

  void _onScaleStart(
    ScaleStartDetails details,
  ) {
    _baseZoom = _currentZoom;
  }

  void _onScaleUpdate(
    ScaleUpdateDetails details,
  ) {
    _setZoom(
      _baseZoom * details.scale,
    );
  }

  Widget _zoomButton(double zoom) {
    final selected =
        (_currentZoom - zoom).abs() < 0.05;

    final zoomLabel =
        zoom == zoom.roundToDouble()
            ? zoom.toStringAsFixed(0)
            : zoom.toStringAsFixed(1);

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
            '$zoomLabel×',

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

  // ==================================================
  // MENSAGENS
  // ==================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==================================================
  // CICLO DE VIDA
  // ==================================================

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.inactive) {
      _isInForeground = false;

      unawaited(_releaseCamera());
    } else if (
        state == AppLifecycleState.resumed
    ) {
      _isInForeground = true;

      if (!_isShowingPhoto) {
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

  // ==================================================
  // INTERFACE PRINCIPAL
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    final cameraReady =
        controller != null &&
        controller.value.isInitialized &&
        !_isInitializing;

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
            // ========================================
            // CABEÇALHO PRETO INTEGRADO AO FLASH
            // ========================================

            _buildFlashHeader(cameraReady),

            // ========================================
            // PREVIEW DA CÂMERA
            // ========================================

            Expanded(
              child: Stack(
                fit: StackFit.expand,

                children: [
                  if (_errorMessage != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(
                          24,
                        ),

                        child: Text(
                          _errorMessage!,

                          textAlign: TextAlign.center,

                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )

                  else if (!cameraReady)
                    const Center(
                      child:
                          CircularProgressIndicator(),
                    )

                  else
                    GestureDetector(
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,

                      // Ao tocar fora do menu,
                      // ele é fechado.

                      onTap: () {
                        if (_isFlashMenuOpen) {
                          setState(() {
                            _isFlashMenuOpen = false;
                          });
                        }
                      },

                      child: Center(
                        child: CameraPreview(
                          controller,
                        ),
                      ),
                    ),

                  // ==================================
                  // CONTROLES DO ZOOM
                  // ==================================

                  if (cameraReady)
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

            // ========================================
            // BARRA INFERIOR
            // ========================================

            Container(
              height: 110,
              color: Colors.black,

              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
              ),

              child: Row(
                children: [
                  // MINIATURA DA ÚLTIMA FOTO

                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: _lastPhoto == null
                            ? null
                            : _openLastPhoto,

                        child: Container(
                          width: 58,
                          height: 58,

                          clipBehavior:
                              Clip.antiAlias,

                          decoration: BoxDecoration(
                            color:
                                Colors.grey.shade900,

                            borderRadius:
                                BorderRadius.circular(
                              10,
                            ),
                          ),

                          child: _lastPhoto == null
                              ? const Icon(
                                  Icons.image_outlined,
                                  color:
                                      Colors.white54,
                                )
                              : Image.file(
                                  File(
                                    _lastPhoto!.path,
                                  ),

                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                  ),

                  // BOTÃO CIRCULAR DE CAPTURA

                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: !cameraReady ||
                                _isTakingPicture
                            ? null
                            : _takePicture,

                        child: Container(
                          width: 84,
                          height: 84,

                          alignment:
                              Alignment.center,

                          decoration: BoxDecoration(
                            shape: BoxShape.circle,

                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),

                          child: Container(
                            width: 66,
                            height: 66,

                            decoration:
                                BoxDecoration(
                              shape:
                                  BoxShape.circle,

                              color:
                                  _isTakingPicture
                                      ? Colors.grey
                                      : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // TROCAR CÂMERA

                  Expanded(
                    child: Center(
                      child: IconButton(
                        onPressed:
                            !cameraReady ||
                                    _isTakingPicture
                                ? null
                                : _switchCamera,

                        icon: const Icon(
                          Icons
                              .cameraswitch_outlined,
                          size: 34,
                        ),

                        color: Colors.white,

                        disabledColor:
                            Colors.white38,
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
}