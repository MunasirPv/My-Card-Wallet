import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:my_card_wallet/features/cards/data/datasources/card_ocr_parser.dart';

class CardScanScreen extends StatefulWidget {
  const CardScanScreen({super.key});

  @override
  State<CardScanScreen> createState() => _CardScanScreenState();
}

class _CardScanScreenState extends State<CardScanScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _torchOn = false;
  String _statusMessage = 'Position card within the frame';
  ScannedCardData? _lastResult;

  // Scan cooldown so we don't spam ML Kit
  Timer? _scanCooldown;
  static const _cooldownMs = 800;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanCooldown?.cancel();
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _statusMessage = 'No camera available');
        return;
      }

      // Prefer back camera
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _controller!.initialize();
      if (!mounted) return;

      // Start streaming frames for live OCR
      await _controller!.startImageStream(_onCameraFrame);

      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _statusMessage = 'Camera error: $e');
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (_isProcessing || _scanCooldown != null) return;
    _processFrame(image);
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final inputImage = _cameraImageToInputImage(image);
      if (inputImage == null) return;

      final recognized = await _textRecognizer.processImage(inputImage);
      if (!mounted) return;

      if (recognized.text.isNotEmpty) {
        final result = CardOCRParser.parse(recognized.text);
        if (result.hasUsefulData) {
          // Stop streaming once we have a useful result
          if (result.cardNumber != null) {
            await _controller?.stopImageStream();
            setState(() {
              _lastResult = result;
              _statusMessage = 'Card detected! Tap confirm to continue.';
            });
          } else {
            setState(() => _statusMessage = 'Hold still, reading card…');
          }
        }
      }
    } catch (_) {
      // Silently ignore frame processing errors
    } finally {
      _isProcessing = false;
      // Cooldown before processing next frame
      _scanCooldown = Timer(
        const Duration(milliseconds: _cooldownMs),
        () => _scanCooldown = null,
      );
    }
  }

  InputImage? _cameraImageToInputImage(CameraImage image) {
    if (_controller == null) return null;
    final camera = _controller!.description;
    final rotation = InputImageRotationValue.fromRawValue(
          camera.sensorOrientation,
        ) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _captureManually() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    HapticFeedback.mediumImpact();
    setState(() => _statusMessage = 'Scanning…');

    try {
      // Stop stream, take high-res photo, then process
      await _controller!.stopImageStream();
      final file = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final recognized = await _textRecognizer.processImage(inputImage);

      if (!mounted) return;
      if (recognized.text.isEmpty) {
        setState(() => _statusMessage = 'Nothing detected. Try again.');
        await _controller!.startImageStream(_onCameraFrame);
        return;
      }

      final result = CardOCRParser.parse(recognized.text);
      if (!mounted) return;

      if (result.hasUsefulData) {
        setState(() {
          _lastResult = result;
          _statusMessage = result.cardNumber != null
              ? 'Card detected! Tap confirm to continue.'
              : 'Partial data found. Tap confirm to use it.';
        });
      } else {
        setState(() => _statusMessage = 'Could not read card. Try again.');
        await _controller!.startImageStream(_onCameraFrame);
      }
    } catch (e) {
      setState(() => _statusMessage = 'Scan failed. Try again.');
      await _controller!.startImageStream(_onCameraFrame);
    }
  }

  void _retryScanning() {
    setState(() {
      _lastResult = null;
      _statusMessage = 'Position card within the frame';
    });
    _controller?.startImageStream(_onCameraFrame);
  }

  void _confirm() {
    Navigator.of(context).pop(_lastResult);
  }

  Future<void> _toggleTorch() async {
    if (_controller == null) return;
    final next = !_torchOn;
    await _controller!
        .setFlashMode(next ? FlashMode.torch : FlashMode.off);
    setState(() => _torchOn = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Camera preview ─────────────────────────────────────────────
            if (_isInitialized && _controller != null)
              CameraPreview(_controller!)
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // ── Card frame overlay ──────────────────────────────────────────
            CustomPaint(
              painter: _CardOverlayPainter(
                detected: _lastResult != null,
              ),
              child: const SizedBox.expand(),
            ),

            // ── Top bar ────────────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(
                torchOn: _torchOn,
                onTorchToggle: _toggleTorch,
                onClose: () => Navigator.of(context).pop(null),
              ),
            ),

            // ── Status message ─────────────────────────────────────────────
            Positioned(
              bottom: 160,
              left: 24,
              right: 24,
              child: _StatusBadge(
                message: _statusMessage,
                detected: _lastResult != null,
              ),
            ),

            // ── Scanned data preview ───────────────────────────────────────
            if (_lastResult != null)
              Positioned(
                bottom: 90,
                left: 24,
                right: 24,
                child: _ScannedDataPreview(result: _lastResult!),
              ),

            // ── Bottom action buttons ──────────────────────────────────────
            Positioned(
              bottom: 20,
              left: 24,
              right: 24,
              child: _lastResult != null
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _retryScanning,
                            icon: const Icon(Icons.refresh_rounded,
                                color: Colors.white),
                            label: const Text('Retry',
                                style: TextStyle(color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white54),
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _confirm,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Use this card'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 52),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    )
                  : FilledButton.icon(
                      onPressed: _captureManually,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Capture'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overlay painter ────────────────────────────────────────────────────────────

class _CardOverlayPainter extends CustomPainter {
  final bool detected;
  _CardOverlayPainter({required this.detected});

  @override
  void paint(Canvas canvas, Size size) {
    // Card frame: 85% width, 16:10 aspect ratio, centred vertically at 42%
    const hPad = 0.075;
    final cardW = size.width * (1 - hPad * 2);
    final cardH = cardW * 0.63; // standard card ratio
    final left = size.width * hPad;
    final top = size.height * 0.42 - cardH / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, cardW, cardH),
      const Radius.circular(16),
    );

    // Darken everything outside the card frame
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dimPaint);

    // Card border
    final borderPaint = Paint()
      ..color = detected ? Colors.greenAccent : Colors.white
      ..strokeWidth = detected ? 3 : 2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rect, borderPaint);

    // Corner accent marks
    const cornerLen = 24.0;
    const cw = 3.0;
    final accentPaint = Paint()
      ..color = detected ? Colors.greenAccent : Colors.white
      ..strokeWidth = cw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final corners = [
      // top-left
      [Offset(left, top + cornerLen), Offset(left, top), Offset(left + cornerLen, top)],
      // top-right
      [Offset(left + cardW - cornerLen, top), Offset(left + cardW, top), Offset(left + cardW, top + cornerLen)],
      // bottom-left
      [Offset(left, top + cardH - cornerLen), Offset(left, top + cardH), Offset(left + cornerLen, top + cardH)],
      // bottom-right
      [Offset(left + cardW - cornerLen, top + cardH), Offset(left + cardW, top + cardH), Offset(left + cardW, top + cardH - cornerLen)],
    ];

    for (final pts in corners) {
      final p = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(p, accentPaint);
    }

    // Scan line animation hint (static dashed line across middle of frame)
    if (!detected) {
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final midY = top + cardH / 2;
      const dashW = 12.0;
      const gapW = 6.0;
      var x = left + 8.0;
      while (x < left + cardW - 8) {
        canvas.drawLine(Offset(x, midY), Offset(x + dashW, midY), linePaint);
        x += dashW + gapW;
      }
    }
  }

  @override
  bool shouldRepaint(_CardOverlayPainter old) => old.detected != detected;
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool torchOn;
  final VoidCallback onTorchToggle;
  final VoidCallback onClose;

  const _TopBar({
    required this.torchOn,
    required this.onTorchToggle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: onClose,
          ),
          const Text(
            'Scan Card',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: Icon(
              torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: torchOn ? Colors.yellow : Colors.white,
            ),
            onPressed: onTorchToggle,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String message;
  final bool detected;

  const _StatusBadge({required this.message, required this.detected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: detected
              ? Colors.green.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (detected) ...[
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    ).animate(key: ValueKey(message)).fadeIn(duration: 250.ms);
  }
}

class _ScannedDataPreview extends StatelessWidget {
  final ScannedCardData result;

  const _ScannedDataPreview({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Detected data',
            style: TextStyle(
                color: Colors.white54, fontSize: 11, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          if (result.cardNumber != null)
            _DataRow(
              icon: Icons.credit_card_rounded,
              label: _formatPreviewNumber(result.cardNumber!),
            ),
          if (result.holderName != null)
            _DataRow(
              icon: Icons.person_outline_rounded,
              label: result.holderName!,
            ),
          if (result.expiryMonth != null)
            _DataRow(
              icon: Icons.calendar_today_rounded,
              label: '${result.expiryMonth}/${result.expiryYear}',
            ),
          if (result.cardNumber == null &&
              result.holderName == null &&
              result.expiryMonth == null)
            const Text(
              'No clear data found — you can still proceed and fill in manually.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2);
  }

  String _formatPreviewNumber(String digits) {
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      // Mask middle digits
      buf.write(i < 4 || i >= digits.length - 4 ? digits[i] : '•');
    }
    return buf.toString();
  }
}

class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DataRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white60, size: 14),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
