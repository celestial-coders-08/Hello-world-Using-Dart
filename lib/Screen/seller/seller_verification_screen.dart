import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/seller_api_service.dart';
import '../../theme/pawstay_theme.dart';

class SellerVerificationScreen extends StatefulWidget {
  final String sellerLookup;
  final VoidCallback onVerificationComplete;

  const SellerVerificationScreen({
    super.key,
    required this.sellerLookup,
    required this.onVerificationComplete,
  });

  @override
  State<SellerVerificationScreen> createState() =>
      _SellerVerificationScreenState();
}

class _SellerVerificationScreenState extends State<SellerVerificationScreen> {
  final _picker = ImagePicker();
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.15,
    ),
  );
  bool _isShopOwner = false;

  XFile? _aadhaarFile;
  XFile? _shopProofFile;

  // Step 0: turn left; step 1: face forward; step 2: turn right.
  int _faceStep = 0;
  final List<XFile> _facePhotos = [];
  XFile? _capturedFacePhoto;
  CameraController? _cameraController;
  bool _isStartingCamera = false;
  bool _isProcessingImage = false;
  bool _faceFitsOval = false;
  bool _faceIsFacingForward = false;
  int _matchingPoseFrames = 0;
  bool _faceDetectionErrorShown = false;

  bool _isSubmitting = false;

  static const int _maxDocBytes = 1 * 1024 * 1024; // 1 MB limit
  static const int _poseFramesRequired = 3;

  Future<void> _pickDocument({required bool isAadhaar}) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) {
        return;
      }

      final bytes = await file.length();
      if (bytes > _maxDocBytes) {
        _showMessage(
          'Document size must be less than 1 MB (Current: ${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB)',
          isError: true,
        );
        return;
      }

      setState(() {
        if (isAadhaar) {
          _aadhaarFile = file;
        } else {
          _shopProofFile = file;
        }
      });
    } catch (e) {
      _showMessage('Failed to pick document: $e', isError: true);
    }
  }

  Future<void> _startFaceVerification() async {
    if (_isStartingCamera || _cameraController != null) {
      return;
    }

    setState(() => _isStartingCamera = true);
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      if (frontCamera.isEmpty) {
        throw StateError('No front-facing camera is available.');
      }

      controller = CameraController(
        frontCamera.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _faceStep = 0;
        _faceFitsOval = false;
        _faceIsFacingForward = false;
        _matchingPoseFrames = 0;
        _faceDetectionErrorShown = false;
      });
      await controller.startImageStream(_processCameraImage);
    } catch (e) {
      if (controller != null) {
        await controller.dispose();
      }
      if (mounted) {
        setState(() => _cameraController = null);
        _showMessage('Could not start the in-app camera: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingCamera = false);
      }
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameraController?.description;
    if (camera == null || image.planes.isEmpty) {
      return null;
    }

    final imageFormat = InputImageFormatValue.fromRawValue(image.format.raw);
    final rotation = _inputImageRotation(camera);
    if (imageFormat == null || rotation == null) {
      return null;
    }

    return InputImage.fromBytes(
      bytes: image.planes.length == 1
          ? image.planes.first.bytes
          : Uint8List.fromList(
              image.planes.expand((plane) => plane.bytes).toList(),
            ),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: imageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _inputImageRotation(CameraDescription camera) {
    final controller = _cameraController;
    if (controller == null) {
      return null;
    }

    final sensorOrientation = camera.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    final deviceRotation = switch (controller.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final rotation = camera.lensDirection == CameraLensDirection.front
        ? (sensorOrientation + deviceRotation) % 360
        : (sensorOrientation - deviceRotation + 360) % 360;
    return InputImageRotationValue.fromRawValue(rotation);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingImage || _cameraController == null) {
      return;
    }
    _isProcessingImage = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        throw StateError('The camera image format is not supported.');
      }
      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) {
        return;
      }

      final face = faces.length == 1 ? faces.first : null;
      final rotation = _inputImageRotation(_cameraController!.description);
      final fitsOval =
          face != null &&
          rotation != null &&
          _faceFitsCameraFrame(face, image, rotation);
      final yaw = face?.headEulerAngleY;
      final isFacingForward = fitsOval && yaw != null && yaw.abs() <= 15;
      final poseMatches =
          fitsOval &&
          yaw != null &&
          switch (_faceStep) {
            0 => yaw <= -12,
            1 => yaw.abs() <= 15,
            2 => yaw >= 12,
            _ => false,
          };

      setState(() {
        _faceFitsOval = fitsOval;
        _faceIsFacingForward = isFacingForward;
        if (poseMatches) {
          _matchingPoseFrames++;
          if (_matchingPoseFrames >= _poseFramesRequired) {
            _faceStep++;
            _matchingPoseFrames = 0;
          }
        } else {
          _matchingPoseFrames = 0;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _faceFitsOval = false);
        if (!_faceDetectionErrorShown) {
          _faceDetectionErrorShown = true;
          _showMessage('Face detection failed: $e', isError: true);
        }
      }
    } finally {
      _isProcessingImage = false;
    }
  }

  bool _faceFitsCameraFrame(
    Face face,
    CameraImage image,
    InputImageRotation rotation,
  ) {
    final bounds = face.boundingBox;
    final isQuarterTurn =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    final frameWidth = (isQuarterTurn ? image.height : image.width).toDouble();
    final frameHeight = (isQuarterTurn ? image.width : image.height).toDouble();
    final centerX = bounds.center.dx / frameWidth;
    final centerY = bounds.center.dy / frameHeight;
    final faceArea = bounds.width * bounds.height;
    final frameArea = frameWidth * frameHeight;
    final areaRatio = faceArea / frameArea;

    return centerX >= 0.30 &&
        centerX <= 0.70 &&
        centerY >= 0.25 &&
        centerY <= 0.75 &&
        areaRatio >= 0.025 &&
        areaRatio <= 0.45;
  }

  Future<void> _takeFacePhoto() async {
    final controller = _cameraController;
    if (controller == null ||
        _faceStep < 3 ||
        !_faceFitsOval ||
        !_faceIsFacingForward) {
      return;
    }

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final photo = await controller.takePicture();
      await controller.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _capturedFacePhoto = photo;
        _facePhotos
          ..clear()
          ..add(photo);
        _cameraController = null;
      });
    } catch (e) {
      if (mounted) {
        _showMessage('Could not capture face photo: $e', isError: true);
      }
    }
  }

  void _resetFaceVerification() {
    setState(() {
      _faceStep = 0;
      _facePhotos.clear();
      _capturedFacePhoto = null;
      _faceFitsOval = false;
      _faceIsFacingForward = false;
      _matchingPoseFrames = 0;
    });
  }

  @override
  void dispose() {
    final controller = _cameraController;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    unawaited(_faceDetector.close());
    super.dispose();
  }

  Future<void> _submitVerification() async {
    if (_aadhaarFile == null) {
      _showMessage(
        'Please upload your Aadhaar card image (< 1 MB)',
        isError: true,
      );
      return;
    }
    if (_isShopOwner && _shopProofFile == null) {
      _showMessage(
        'Please upload government shop proof document (< 1 MB)',
        isError: true,
      );
      return;
    }
    if (_faceStep < 3 || _capturedFacePhoto == null) {
      _showMessage(
        'Please complete face movement steps and click face photo',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    try {
      await SellerApiService.submitVerification(
        sellerLookup: widget.sellerLookup,
        isShopOwner: _isShopOwner,
        aadhaarFile: _aadhaarFile!,
        shopProofFile: _shopProofFile,
        facePhotos: _facePhotos.isNotEmpty
            ? _facePhotos
            : [_capturedFacePhoto!],
      );

      if (mounted) {
        _showMessage('Seller verification submitted successfully!');
        widget.onVerificationComplete();
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
        backgroundColor: isError ? PawStayTheme.error : PawStayTheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Seller Verification',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Info
                Card(
                  color: PawStayTheme.primaryContainer.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: PawStayTheme.primary,
                          radius: 20,
                          child: Icon(
                            Icons.verified_user,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Identity Check',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Upload documents & complete face verification to start selling.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Question 1: Shop Ownership
                Text(
                  '1. Shop Ownership',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Do you own a shop for pet items?',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: Center(
                                  child: Text(
                                    'YES (Shop)',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                selected: _isShopOwner,
                                selectedColor: PawStayTheme.primaryContainer,
                                onSelected: (val) {
                                  setState(() => _isShopOwner = true);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: Center(
                                  child: Text(
                                    'NO (Individual)',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                selected: !_isShopOwner,
                                selectedColor: PawStayTheme.primaryContainer,
                                onSelected: (val) {
                                  setState(() => _isShopOwner = false);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isShopOwner
                              ? 'Shop owners can sell Pets, Pet Food & Accessories.'
                              : 'Individual sellers can list Pets for sale.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: PawStayTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Question 2: Government Documents
                Text(
                  '2. Government Identity Proof (< 1 MB)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),

                _documentUploadCard(
                  title: 'Aadhaar Card (Required)',
                  subtitle: 'Upload Aadhaar image (< 1 MB)',
                  icon: Icons.badge_outlined,
                  file: _aadhaarFile,
                  onTap: () => _pickDocument(isAadhaar: true),
                ),

                if (_isShopOwner) ...[
                  const SizedBox(height: 8),
                  _documentUploadCard(
                    title: 'Government Shop License / Proof',
                    subtitle: 'Upload shop license image (< 1 MB)',
                    icon: Icons.store_outlined,
                    file: _shopProofFile,
                    onTap: () => _pickDocument(isAadhaar: false),
                  ),
                ],

                const SizedBox(height: 20),

                // Question 3: Circular Live Face Verification
                Text(
                  '3. Live Circular Face Verification',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),

                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _capturedFacePhoto != null
                          ? Colors.green
                          : PawStayTheme.primary,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 180,
                            height: 220,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.all(
                                Radius.elliptical(90, 110),
                              ),
                              border: Border.all(
                                color:
                                    _capturedFacePhoto != null || _faceFitsOval
                                    ? Colors.green
                                    : PawStayTheme.primary,
                                width: 3.5,
                              ),
                              color: colors.surfaceContainerHighest,
                            ),
                            child: ClipOval(
                              child: _capturedFacePhoto != null
                                  ? FutureBuilder<Uint8List>(
                                      future: _capturedFacePhoto!.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        }
                                        return Image.memory(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                          width: 180,
                                          height: 220,
                                        );
                                      },
                                    )
                                  : _cameraController != null &&
                                        _cameraController!.value.isInitialized
                                  ? FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: _cameraController!
                                            .value
                                            .previewSize!
                                            .height,
                                        height: _cameraController!
                                            .value
                                            .previewSize!
                                            .width,
                                        child: CameraPreview(
                                          _cameraController!,
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: _isStartingCamera
                                          ? const CircularProgressIndicator()
                                          : Icon(
                                              Icons.face_retouching_natural,
                                              size: 64,
                                              color: PawStayTheme.primary,
                                            ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        Text(
                          _cameraController == null &&
                                  _capturedFacePhoto == null
                              ? 'Allow camera access to start face verification.'
                              : _capturedFacePhoto != null
                              ? 'Face photo captured successfully.'
                              : _faceFitsOval
                              ? _faceStep >= 3 && !_faceIsFacingForward
                                    ? 'Look straight at the camera to capture.'
                                    : _promptTextForStep(_faceStep)
                              : 'Keep your face visible and centered in the oval.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _faceFitsOval || _capturedFacePhoto != null
                                ? Colors.green.shade700
                                : colors.onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _stepBadge('1. Right', verified: _faceStep > 0),
                            _stepBadge('2. Front', verified: _faceStep > 1),
                            _stepBadge('3. Left', verified: _faceStep > 2),
                          ],
                        ),

                        const SizedBox(height: 16),
                        if (_cameraController == null &&
                            _capturedFacePhoto == null)
                          ElevatedButton.icon(
                            onPressed: _isStartingCamera
                                ? null
                                : _startFaceVerification,
                            icon: const Icon(Icons.camera_alt),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PawStayTheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            label: Text(
                              _isStartingCamera
                                  ? 'Starting camera...'
                                  : 'Allow camera and start',
                            ),
                          )
                        else if (_cameraController != null && _faceStep >= 3)
                          ElevatedButton.icon(
                            onPressed: _faceFitsOval && _faceIsFacingForward
                                ? _takeFacePhoto
                                : null,
                            icon: const Icon(Icons.camera_alt),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            label: const Text('Capture face photo'),
                          )
                        else if (_capturedFacePhoto != null)
                          OutlinedButton.icon(
                            onPressed: _resetAndStartFaceVerification,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retake face photo'),
                          ),

                        if (_faceStep > 0 || _capturedFacePhoto != null)
                          TextButton.icon(
                            onPressed: _resetFaceVerification,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Restart Verification'),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Final Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PawStayTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Submit Verification Profile',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _promptTextForStep(int step) => switch (step) {
    0 => 'Turn your face to the RIGHT',
    1 => 'Look straight at the camera',
    2 => 'Turn your face to the LEFT',
    _ => 'Movement complete. Look forward and capture your photo.',
  };

  Future<void> _resetAndStartFaceVerification() async {
    _resetFaceVerification();
    await _startFaceVerification();
  }

  Widget _stepBadge(String title, {required bool verified}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: verified
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: verified ? Colors.green : Colors.grey.shade400,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: verified ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: verified ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required XFile? file,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isUploaded = file != null;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUploaded ? Colors.green : colors.outlineVariant,
          width: isUploaded ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: isUploaded
              ? Colors.green.withValues(alpha: 0.15)
              : colors.surfaceContainerHighest,
          child: Icon(
            isUploaded ? Icons.check_circle_rounded : icon,
            size: 20,
            color: isUploaded ? Colors.green : PawStayTheme.primary,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          isUploaded ? 'Selected (< 1 MB)' : subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: isUploaded ? Colors.green : colors.onSurfaceVariant,
          ),
        ),
        trailing: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
          child: Text(
            isUploaded ? 'Change' : 'Upload',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }
}
