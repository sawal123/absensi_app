import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../services/image_service.dart';

enum AttendanceCaptureMode {
  checkIn('Absen Masuk'),
  checkOut('Absen Pulang'),
  faceEnrollment('Daftar Wajah');

  const AttendanceCaptureMode(this.title);

  final String title;
}

class CaptureResult {
  const CaptureResult({required this.path, required this.livenessPassed});

  final String path;
  final bool livenessPassed;
}

/// Kamera selfie dengan tantangan liveness (kedip mata) memakai ML Kit.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key, required this.mode});

  final AttendanceCaptureMode mode;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  FaceDetector? _detector;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;

  bool _initializing = true;
  bool _takingPicture = false;
  bool _processingFrame = false;
  bool _faceDetected = false;
  bool _eyesClosedSeen = false;
  bool _livenessPassed = false;
  bool _streaming = false;
  bool _mlKitBypassed = kIsWeb;
  String? _errorMessage;

  Uint8List? _previewBytes;
  String? _previewPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _controller?.dispose();
    _detector?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive) {
      if (controller == null) return;
      _stopStream();
      _controller = null;
      controller.dispose();
      if (mounted && _previewBytes == null) {
        setState(() => _initializing = true);
      }
    } else if (state == AppLifecycleState.resumed && _previewBytes == null) {
      _start();
    }
  }

  Future<void> _start({int? index}) async {
    if (!mounted) return;
    setState(() {
      _initializing = true;
      _errorMessage = null;
    });

    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        throw CameraException(
          'cameraNotFound',
          'Kamera tidak ditemukan pada perangkat ini.',
        );
      }

      var next = index ?? _cameraIndex;
      if (index == null) {
        final front = _cameras.indexWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
        if (front >= 0) next = front;
      }
      if (next < 0 || next >= _cameras.length) next = 0;

      final controller = CameraController(
        _cameras[next],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      final previous = _controller;
      _controller = controller;
      _cameraIndex = next;
      await previous?.dispose();

      if (!mounted) return;
      setState(() => _initializing = false);
      await _startStream();
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage = _messageFor(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage = 'Kamera tidak dapat dibuka saat ini.';
      });
    }
  }

  Future<void> _startStream() async {
    final controller = _controller;
    if (_mlKitBypassed ||
        controller == null ||
        !controller.value.isInitialized ||
        _streaming ||
        _previewBytes != null) {
      return;
    }

    try {
      _detector ??= FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      await controller.startImageStream(_onFrame);
      _streaming = true;
    } catch (_) {
      _mlKitBypassed = true;
      _livenessPassed = true;
    }
  }

  Future<void> _stopStream() async {
    final controller = _controller;
    if (controller == null || !_streaming) return;
    _streaming = false;
    try {
      await controller.stopImageStream();
    } catch (_) {
      // Kamera mungkin sudah dilepas.
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    final controller = _controller;
    final detector = _detector;
    if (_processingFrame ||
        _takingPicture ||
        _previewBytes != null ||
        controller == null ||
        detector == null) {
      return;
    }

    _processingFrame = true;
    try {
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null || image.planes.isEmpty) return;

      final rotation =
          InputImageRotationValue.fromRawValue(
            controller.description.sensorOrientation,
          ) ??
          InputImageRotation.rotation0deg;

      final plane = image.planes.first;
      final inputImage = InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );

      final faces = await detector.processImage(inputImage);
      if (!mounted) return;

      if (faces.isEmpty) {
        if (_faceDetected) {
          setState(() => _faceDetected = false);
        }
        return;
      }

      final face = faces.first;
      final left = face.leftEyeOpenProbability;
      final right = face.rightEyeOpenProbability;
      final bothClosed =
          left != null && right != null && left < 0.35 && right < 0.35;
      final bothOpen =
          left != null && right != null && left > 0.6 && right > 0.6;

      var changed = false;
      if (!_faceDetected) {
        _faceDetected = true;
        changed = true;
      }
      if (bothClosed && !_eyesClosedSeen) {
        _eyesClosedSeen = true;
        changed = true;
      }
      if (_eyesClosedSeen && bothOpen && !_livenessPassed) {
        _livenessPassed = true;
        changed = true;
      }

      if (changed && mounted) {
        setState(() {});
      }
    } catch (_) {
      // Frame gagal diproses; lanjutkan frame berikutnya.
    } finally {
      _processingFrame = false;
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _previewBytes != null) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    await _stopStream();
    final previous = _controller;
    _controller = null;
    await previous?.dispose();
    _resetLiveness();
    await _start(index: next);
  }

  void _resetLiveness() {
    _faceDetected = false;
    _eyesClosedSeen = false;
    _livenessPassed = _mlKitBypassed;
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _takingPicture) {
      return;
    }

    if (!_mlKitBypassed && !_livenessPassed) {
      _showMessage('Kedipkan mata terlebih dahulu untuk verifikasi liveness.');
      return;
    }

    setState(() => _takingPicture = true);
    try {
      await _stopStream();
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
        _previewPath = file.path;
        _takingPicture = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() => _takingPicture = false);
      _showMessage(_messageFor(error));
      await _startStream();
    } catch (_) {
      if (!mounted) return;
      setState(() => _takingPicture = false);
      _showMessage('Gagal mengambil foto. Coba lagi.');
      await _startStream();
    }
  }

  Future<void> _useNativeCamera() async {
    setState(() => _initializing = true);
    try {
      final path = await context.read<ImageService>().takeSelfie();
      if (!mounted) return;
      Navigator.of(context).pop(
        CaptureResult(path: path, livenessPassed: kIsWeb),
      );
    } on ImageException catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage = 'Kamera bawaan tidak dapat dibuka.';
      });
    }
  }

  void _retake() {
    setState(() {
      _previewBytes = null;
      _previewPath = null;
      _resetLiveness();
    });
    _startStream();
  }

  void _usePhoto() {
    final path = _previewPath;
    if (path == null) return;
    Navigator.of(context).pop(
      CaptureResult(
        path: path,
        livenessPassed: _mlKitBypassed ? true : _livenessPassed,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFor(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Izin kamera ditolak. Aktifkan izin kamera untuk aplikasi '
            'ini, lalu coba lagi.';
      case 'CameraAccessRestricted':
        return 'Akses kamera dibatasi oleh perangkat.';
      case 'cameraNotFound':
        return 'Kamera tidak ditemukan pada perangkat ini.';
      default:
        return error.description ?? 'Kamera tidak dapat dibuka saat ini.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _previewBytes != null
          ? _buildPreview()
          : SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(child: _buildCameraArea()),
                  _buildBottomBar(),
                ],
              ),
            ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.close_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Ambil Selfie',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.mode.title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _buildCameraArea() {
    final controller = _controller;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (_initializing)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else if (controller != null && controller.value.isInitialized)
          _CameraPreview(controller: controller)
        else
          _buildError(),
        if (!_initializing &&
            _errorMessage == null &&
            controller != null &&
            controller.value.isInitialized) ...[
          const IgnorePointer(child: Center(child: _FaceFrame())),
          Positioned(
            left: 24,
            right: 24,
            bottom: 16,
            child: Text(
              _mlKitBypassed
                  ? 'Posisikan wajahmu di dalam bingkai'
                  : !_faceDetected
                  ? 'Posisikan wajahmu di dalam bingkai'
                  : _livenessPassed
                  ? 'Liveness terverifikasi. Tekan tombol untuk foto.'
                  : _eyesClosedSeen
                  ? 'Buka matamu kembali untuk menyelesaikan verifikasi'
                  : 'Kedipkan matamu sekali untuk verifikasi liveness',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar() {
    final canCapture = _controller?.value.isInitialized ?? false;
    final livenessReady = _mlKitBypassed || _livenessPassed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Foto dipakai sebagai bukti ${widget.mode.title.toLowerCase()}.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 44),
              _ShutterButton(
                enabled: canCapture && livenessReady && !_takingPicture,
                busy: _takingPicture,
                onTap: _capture,
              ),
              if (_cameras.length > 1)
                _CircleButton(
                  icon: Icons.cameraswitch_rounded,
                  onTap: _switchCamera,
                )
              else
                const SizedBox(width: 44),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_outlined,
              size: 46,
              color: Colors.white.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 14),
            const Text(
              'Kamera tidak tersedia',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Kamera belum siap digunakan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _start(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
              style: FilledButton.styleFrom(minimumSize: const Size(220, 50)),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _useNativeCamera,
              child: const Text(
                'Gunakan kamera bawaan',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(_previewBytes!, fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.75),
              ],
              stops: const [0, 0.25, 0.55, 1],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _CircleButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                child: Column(
                  children: [
                    const Text(
                      'Gunakan foto ini?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _retake,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Ulangi'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _usePhoto,
                            icon: const Icon(Icons.check_rounded, size: 19),
                            label: const Text('Gunakan Foto'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final displayAspect =
        MediaQuery.orientationOf(context) == Orientation.landscape
        ? value.aspectRatio
        : 1 / value.aspectRatio;

    if (!displayAspect.isFinite || displayAspect <= 0) {
      return Center(child: CameraPreview(controller));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: height * displayAspect,
              height: height,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}

class _FaceFrame extends StatelessWidget {
  const _FaceFrame();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(150),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 2.5,
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: enabled ? 0.95 : 0.35),
            width: 3,
          ),
        ),
        child: Center(
          child: Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: enabled ? 1 : 0.35),
            ),
            child: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppPalette.primary,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}
