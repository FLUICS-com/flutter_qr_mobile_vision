import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:qr_mobile_vision/barcode.dart';
import 'package:qr_mobile_vision/camera_config.dart';
import 'package:qr_mobile_vision/qr_mobile_vision.dart';

final WidgetBuilder _defaultNotStartedBuilder =
    (context) => Text("Camera Loading ...");
final WidgetBuilder _defaultOffscreenBuilder =
    (context) => Text("Camera Paused.");
final ErrorCallback _defaultOnError = (BuildContext context, Object error) {
  print("Error reading from camera: $error");
  return Text("Error reading from camera...");
};

typedef Widget ErrorCallback(BuildContext context, Object error);

class QrCamera extends StatefulWidget {
  QrCamera({
    Key key,
    @required this.qrCodeCallback,
    this.cameraLensDirection,
    this.cameraZoomFactor,
    this.child,
    this.fit = BoxFit.cover,
    WidgetBuilder notStartedBuilder,
    WidgetBuilder offscreenBuilder,
    this.scaleResolution = 1,
    ErrorCallback onError,
    this.formats,
    this.customPainter,
    bool isFlipCameraPreview,
  })  : notStartedBuilder = notStartedBuilder ?? _defaultNotStartedBuilder,
        offscreenBuilder =
            offscreenBuilder ?? notStartedBuilder ?? _defaultOffscreenBuilder,
        onError = onError ?? _defaultOnError,
        isFlipCameraPreview = isFlipCameraPreview ?? false,
        assert(fit != null),
        super(key: key);

  final BoxFit fit;
  final ValueChanged<List<Barcode>> qrCodeCallback;
  final Widget child;
  final WidgetBuilder notStartedBuilder;
  final WidgetBuilder offscreenBuilder;
  final int scaleResolution;
  final ErrorCallback onError;
  final List<BarcodeFormats> formats;
  final CustomPainter customPainter;
  final CameraLensDirection cameraLensDirection;
  final CameraZoomFactor cameraZoomFactor;
  final bool isFlipCameraPreview;
  @override
  QrCameraState createState() => QrCameraState();
}

class QrCameraState extends State<QrCamera> with WidgetsBindingObserver {
  Size _textureSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => onScreen = true);
    } else {
      if (_asyncInitOnce != null && onScreen) {
        QrMobileVision.stop();
      }
      setState(() {
        onScreen = false;
        _asyncInitOnce = null;
      });
    }
  }

  bool onScreen = true;
  Future<PreviewDetails> _asyncInitOnce;

  Future<PreviewDetails> _asyncInit(
    num width,
    num height,
    CameraLensDirection cameraLensDirection,
    CameraZoomFactor cameraZoomFactor,
  ) async {
    var previewDetails = await QrMobileVision.start(
      width: width.toInt(),
      height: height.toInt(),
      cameraLensDirectionValue:
          _cameraLensDirectionValue(widget.cameraLensDirection),
      cameraZoomFactorValue: _cameraZoomFactorValue(widget.cameraZoomFactor),
      scaleResolution: widget.scaleResolution,
      qrCodeHandler: widget.qrCodeCallback,
      formats: widget.formats,
    );
    return previewDetails;
  }

  int _cameraLensDirectionValue(CameraLensDirection cameraLensDirection) {
    if (cameraLensDirection == null) return CameraLensDirection.back.index;
    return cameraLensDirection.index;
  }

  double _cameraZoomFactorValue(CameraZoomFactor cameraZoomFactor) {
    double zoomFactorValue;
    switch (cameraZoomFactor) {
      case CameraZoomFactor.zoom_1x:
        zoomFactorValue = 1.0;
        break;
      case CameraZoomFactor.zoom_2x:
        zoomFactorValue = 2.0;
        break;
      case CameraZoomFactor.zoom_4x:
        zoomFactorValue = 4.0;
        break;
      default:
        zoomFactorValue = 1.0;
    }
    return zoomFactorValue;
  }

  /// This method can be used to restart scanning
  ///  the event that it was paused.
  void restart() {
    (() async {
      await QrMobileVision.stop();
      setState(() {
        _asyncInitOnce = null;
      });
    })();
  }

  /// This method can be used to manually stop the
  /// camera.
  void stop() {
    (() async {
      await QrMobileVision.stop();
    })();
  }

  @override
  deactivate() {
    super.deactivate();
    QrMobileVision.stop();
  }

  void updateTextureSize() {
    QrMobileVision.getTextureSize().then((value) {
      if (value != null) {
        setState(() {
          _textureSize = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      if (_asyncInitOnce == null && onScreen) {
        _asyncInitOnce = _asyncInit(constraints.maxWidth, constraints.maxHeight,
            widget.cameraLensDirection, widget.cameraZoomFactor);
      } else if (!onScreen) {
        return widget.offscreenBuilder(context);
      }

      return FutureBuilder(
        future: _asyncInitOnce,
        builder: (BuildContext context, AsyncSnapshot<PreviewDetails> details) {
          switch (details.connectionState) {
            case ConnectionState.none:
            case ConnectionState.waiting:
              return widget.notStartedBuilder(context);
            case ConnectionState.done:
              if (details.hasError) {
                debugPrint(details.error.toString());
                return widget.onError(context, details.error);
              }
              Widget preview = SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Preview(
                  previewDetails: _getPreviewDetails(details.data),
                  targetWidth: constraints.maxWidth,
                  targetHeight: constraints.maxHeight,
                  fit: widget.fit,
                  customPainter: widget.customPainter,
                  isFlipCameraPreview: widget.isFlipCameraPreview,
                ),
              );

              if (widget.child != null) {
                return Stack(
                  children: [
                    preview,
                    widget.child,
                  ],
                );
              }
              return preview;

            default:
              throw AssertionError("${details.connectionState} not supported.");
          }
        },
      );
    });
  }

  PreviewDetails _getPreviewDetails(PreviewDetails previewDetails) {
    if (_textureSize == null) {
      return previewDetails;
    }
    return PreviewDetails(_textureSize.width, _textureSize.height,
        previewDetails.sensorOrientation, previewDetails.textureId);
  }
}

class Preview extends StatelessWidget {
  final double width, height;
  final double targetWidth, targetHeight;
  final int textureId;
  final int sensorOrientation;
  final BoxFit fit;
  final CustomPainter customPainter;
  final bool isFlipCameraPreview;

  Preview({
    @required PreviewDetails previewDetails,
    @required this.targetWidth,
    @required this.targetHeight,
    @required this.fit,
    this.isFlipCameraPreview,
    this.customPainter,
  })  : assert(previewDetails != null),
        textureId = previewDetails.textureId,
        width = previewDetails.width.toDouble(),
        height = previewDetails.height.toDouble(),
        sensorOrientation = previewDetails.sensorOrientation;

  @override
  Widget build(BuildContext context) {
    return NativeDeviceOrientationReader(
      builder: (context) {
        var nativeOrientation =
            NativeDeviceOrientationReader.orientation(context);

        int nativeRotation = 0;
        switch (nativeOrientation) {
          case NativeDeviceOrientation.portraitUp:
            nativeRotation = 0;
            break;
          case NativeDeviceOrientation.landscapeRight:
            nativeRotation = 90;
            break;
          case NativeDeviceOrientation.portraitDown:
            nativeRotation = 180;
            break;
          case NativeDeviceOrientation.landscapeLeft:
            nativeRotation = 270;
            break;
          case NativeDeviceOrientation.unknown:
          default:
            break;
        }

        print(
            "Native orientation: $nativeRotation, sensorOrientation: $sensorOrientation");

        int rotationCompensation =
            ((nativeRotation - sensorOrientation + 450) % 360) ~/ 90;

        double frameHeight = width;
        double frameWidth = height;

        return FittedBox(
          fit: fit,
          child: RotatedBox(
            quarterTurns: rotationCompensation,
            child: CameraPreview(
              textureId: textureId,
              customPainter: customPainter,
              width: frameWidth,
              height: frameHeight,
              isFlipCameraPreview: isFlipCameraPreview,
            ),
          ),
        );
      },
    );
  }
}

class CameraPreview extends StatelessWidget {
  const CameraPreview({
    Key key,
    this.textureId,
    this.customPainter,
    this.height,
    this.width,
    this.isFlipCameraPreview,
  }) : super(key: key);

  final int textureId;
  final CustomPainter customPainter;
  final double height;
  final double width;
  final bool isFlipCameraPreview;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        foregroundPainter: customPainter,
        child: _buildTexture(),
      ),
    );
  }

  Widget _buildTexture() {
    if (isFlipCameraPreview) {
      final flipMatrix = Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(-math.pi);

      return Transform(
        transform: flipMatrix,
        alignment: Alignment.center,
        child: Texture(textureId: textureId),
      );
    } else {
      return Texture(textureId: textureId);
    }
  }
}
