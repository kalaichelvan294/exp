import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../application/billing_controller.dart';
import '../../application/billing_state.dart';

/// Modal for controlling camera settings and viewing live feed.
class CameraControlModal extends ConsumerWidget {
  const CameraControlModal({super.key, required this.state});

  final BillingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(billingControllerProvider.notifier);

    return Dialog(
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Camera Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: c.closeCameraModal,
                  ),
                ],
              ),
            ),
            const Divider(),

            // Live feed preview (if camera is available)
            if (Platform.isWindows && state.cameraConnected)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  child: _CameraPreview(state: state),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x16),
                child: Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: AppRadius.card,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam_off,
                        size: 48,
                        color: AppColors.neutral400,
                      ),
                      const SizedBox(height: AppSpacing.x12),
                      Text(
                        state.cameraError.isNotEmpty
                            ? state.cameraError
                            : state.cameraTurnedOff
                                ? 'Camera is turned off'
                                : 'Camera not available',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.neutral600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.x16),
            const Divider(),

            // Camera status and controls
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status section
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.x12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(state).withValues(alpha: 0.1),
                      borderRadius: AppRadius.input,
                      border: Border.all(
                        color: _getStatusColor(state),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getStatusIcon(state),
                              color: _getStatusColor(state),
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.x8),
                            Text(
                              _getStatusText(state),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: _getStatusColor(state),
                                    fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (state.cameraStatus.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.x8),
                            child: Text(
                              state.cameraStatus,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: _getStatusColor(state)
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.x16),

                  // Camera toggle button
                  if (Platform.isWindows)
                    ElevatedButton.icon(
                      onPressed: () {
                        c.toggleCameraOff();
                        // Close modal if turning off
                        if (!state.cameraTurnedOff && Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      icon: Icon(
                        state.cameraTurnedOff
                            ? Icons.videocam
                            : Icons.videocam_off,
                      ),
                      label: Text(
                        state.cameraTurnedOff
                            ? 'Turn Camera On'
                            : 'Turn Camera Off',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: state.cameraTurnedOff
                            ? AppColors.success500
                            : AppColors.warning500,
                        foregroundColor: AppColors.neutral0,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.x12,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.x12),
                      decoration: BoxDecoration(
                        color: AppColors.neutral100,
                        borderRadius: AppRadius.input,
                      ),
                      child: Text(
                        'Camera is only available on Windows',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.neutral600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: AppSpacing.x12),

                  // Close button
                  TextButton(
                    onPressed: c.closeCameraModal,
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(BillingState state) {
    if (state.cameraError.isNotEmpty) {
      return AppColors.error500;
    } else if (state.cameraTurnedOff) {
      return AppColors.warning500;
    } else if (state.cameraBusy) {
      return AppColors.warning500;
    } else if (state.cameraLive && state.cameraConnected) {
      return AppColors.success500;
    } else {
      return AppColors.neutral500;
    }
  }

  IconData _getStatusIcon(BillingState state) {
    if (state.cameraError.isNotEmpty) {
      return Icons.error;
    } else if (state.cameraTurnedOff) {
      return Icons.videocam_off;
    } else if (state.cameraBusy) {
      return Icons.hourglass_top;
    } else if (state.cameraLive && state.cameraConnected) {
      return Icons.videocam;
    } else {
      return Icons.help;
    }
  }

  String _getStatusText(BillingState state) {
    if (state.cameraError.isNotEmpty) {
      return 'Camera Error';
    } else if (state.cameraTurnedOff) {
      return 'Camera Turned Off';
    } else if (state.cameraBusy) {
      return 'Scanning...';
    } else if (state.cameraLive && state.cameraConnected) {
      return 'Camera Live';
    } else if (!state.cameraConnected) {
      return 'Camera Offline';
    } else {
      return 'Unknown Status';
    }
  }
}

/// Live camera preview widget.
class _CameraPreview extends ConsumerStatefulWidget {
  const _CameraPreview({required this.state});

  final BillingState state;

  @override
  ConsumerState<_CameraPreview> createState() => _CameraPreviewState();
}

class _CameraPreviewState extends ConsumerState<_CameraPreview> {
  CameraController? _previewController;

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  Future<void> _initializePreview() async {
    try {
      if (!Platform.isWindows || !widget.state.cameraConnected) {
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _previewController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _previewController?.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Silently fail
    }
  }

  @override
  void dispose() {
    _previewController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_previewController == null || !_previewController!.value.isInitialized) {
      return Container(
        color: AppColors.neutral100,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return ClipRRect(
      borderRadius: AppRadius.card,
      child: CameraPreview(_previewController!),
    );
  }
}
