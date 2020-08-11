import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:qr_mobile_vision/barcode.dart';
import 'package:qr_mobile_vision/camera_config.dart';

class PreviewDetails {
  num width;
  num height;
  num sensorOrientation;
  int textureId;

  PreviewDetails(
    this.width,
    this.height,
    this.sensorOrientation,
    this.textureId,
  );
}

enum BarcodeFormats {
  ALL_FORMATS,
  AZTEC,
  CODE_128,
  CODE_39,
  CODE_93,
  CODABAR,
  DATA_MATRIX,
  EAN_13,
  EAN_8,
  ITF,
  PDF417,
  QR_CODE,
  UPC_A,
  UPC_E,
}

const _defaultBarcodeFormats = const [
  BarcodeFormats.ALL_FORMATS,
];

class QrMobileVision {
  static const MethodChannel _channel =
      const MethodChannel('com.github.rmtmckenzie/qr_mobile_vision');
  static QrChannelReader channelReader = new QrChannelReader(_channel);

  //Set target size before starting
  static Future<PreviewDetails> start({
    @required int width,
    @required int height,
    int scaleResolution,
    @required int cameraLensDirectionValue,
    @required double cameraZoomFactorValue,
    @required QRCodeHandler qrCodeHandler,
    List<BarcodeFormats> formats = _defaultBarcodeFormats,
  }) async {
    width = width * scaleResolution;
    height = height * scaleResolution;
    final _formats = formats ?? _defaultBarcodeFormats;
    assert(_formats.length > 0);

    List<String> formatStrings = _formats
        .map((format) => format.toString().split('.')[1])
        .toList(growable: false);

    channelReader.setQrCodeHandler(qrCodeHandler);
    var details = await _channel.invokeMethod('start', {
      'targetWidth': width,
      'targetHeight': height,
      'cameraLensFacing': cameraLensDirectionValue,
      'zoomFactor': cameraZoomFactorValue,
      'heartbeatTimeout': 0,
      'formats': formatStrings
    });

    // invokeMethod returns Map<dynamic,...> in dart 2.0
    assert(details is Map<dynamic, dynamic>);

    int textureId = details["textureId"];
    num orientation = details["surfaceOrientation"];
    num surfaceHeight = details["surfaceHeight"];
    num surfaceWidth = details["surfaceWidth"];

    return new PreviewDetails(
        surfaceWidth, surfaceHeight, orientation, textureId);
  }

  static Future stop() {
    channelReader.setQrCodeHandler(null);
    return _channel.invokeMethod('stop').catchError(print);
  }

  static Future<void> setCameraLensFacing(
      CameraLensDirection cameraLensDirection) {
    return _channel
        .invokeMethod('setCameraLensFacing', cameraLensDirection.index)
        .catchError(print);
  }

  static Future toggleTorch() {
    return _channel.invokeMethod('toggleTorch');
  }

  static Future<CameraStatus> getCameraStatus() async {
    if (await getCameraLensFacing() != null) {
      return CameraStatus.active;
    }
    return CameraStatus.inactive;
  }

  static Future<void> setZoomFactor(CameraZoomFactor zoomFactor) {
    double zoomFactorValue;
    switch (zoomFactor) {
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
    return _channel
        .invokeMethod('setZoomFactor', zoomFactorValue)
        .catchError(print);
  }

  static Future<CameraZoomFactor> getZoomFactor() async {
    final double zoomValue = await _channel.invokeMethod('getZoomFactor');
    if (zoomValue == null) return null;

    CameraZoomFactor zoomFactor;
    if (zoomValue == 1.0) {
      zoomFactor = CameraZoomFactor.zoom_1x;
    } else if (zoomValue == 2.0) {
      zoomFactor = CameraZoomFactor.zoom_2x;
    } else if (zoomValue == 4.0) {
      zoomFactor = CameraZoomFactor.zoom_4x;
    }
    return zoomFactor;
  }

  static Future<CameraLensDirection> getCameraLensFacing() async {
    final int cameraLensFacing =
        await _channel.invokeMethod('getCameraLensFacing');
    if (cameraLensFacing == null) return null;
    return CameraLensDirection.values.elementAt(cameraLensFacing);
  }

  static Future heartbeat() {
    return _channel.invokeMethod('heartbeat').catchError(print);
  }

  static Future<List<List<int>>> getSupportedSizes() {
    return _channel.invokeMethod('getSupportedSizes').catchError(print);
  }
}

enum FrameRotation { none, ninetyCC, oneeighty, twoseventyCC }

typedef void QRCodeHandler(List<Barcode> qr);

class QrChannelReader {
  QrChannelReader(this.channel) {
    channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'qrRead':
          if (qrCodeHandler != null) {
            assert(call.arguments is List);
            final List<Barcode> barcodes = (call.arguments as List)
                .map((barcode) => Barcode(barcode))
                .toList();
            qrCodeHandler(barcodes);
          }
          break;
        default:
          print("QrChannelHandler: unknown method call received at "
              "${call.method}");
      }
    });
  }

  void setQrCodeHandler(QRCodeHandler qrch) {
    this.qrCodeHandler = qrch;
  }

  MethodChannel channel;
  QRCodeHandler qrCodeHandler;
}
