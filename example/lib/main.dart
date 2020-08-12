import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_mobile_vision/qr_camera.dart';
import 'package:qr_mobile_vision/qr_mobile_vision.dart';
import 'package:qr_mobile_vision/barcode.dart';
import 'package:qr_mobile_vision/camera_config.dart';

void main() {
  debugPaintSizeEnabled = false;
  runApp(HomePage());
}

class HomePage extends StatefulWidget {
  @override
  HomeState createState() => HomeState();
}

class HomeState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MyApp());
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String qr;
  CameraStatus camState = CameraStatus.inactive;
  Offset position;
  Set<String> listQr = Set();
  GlobalKey<QrCameraState> key = GlobalKey();

  List<Barcode> barcodes;
  OverlayEntry overlayEntry;
  @override
  initState() {
    super.initState();
    position = Offset(30, 30);
    QrMobileVision.getCameraStatus().then((status) {
      camState = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plugin example app'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("QRCODE: $listQr"),
              ),
              Draggable(
                feedback: FlatButton(
                  child: Text('Change camera'),
                  onPressed: () {
                    QrMobileVision.setCameraLensFacing(
                        CameraLensDirection.back);
                  },
                ),
                child: FlatButton(
                  child: Text('Change camera'),
                  onPressed: () {
                    QrMobileVision.setCameraLensFacing(
                        CameraLensDirection.front);
                    key.currentState.updateTextureSize();
                  },
                ),
              ),
              FlatButton(
                child: Text('Torch'),
                onPressed: () {
                  QrMobileVision.toggleTorch();
                },
              ),
              FlatButton(
                child: Text('Clear'),
                onPressed: () {
                  barcodes.clear();
                },
              ),
              FlatButton(
                child: Text('Zoom'),
                onPressed: () {
                  QrMobileVision.setZoomFactor(CameraZoomFactor.zoom_4x);
                  overlayEntry.markNeedsBuild();
                },
              ),
              FlatButton(
                child: Text('Position'),
                onPressed: () {
                  position = Offset(0, 0);
                  overlayEntry.markNeedsBuild();
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
          child: Icon(
            Icons.camera,
            color: Colors.white,
          ),
          onPressed: () async {
            await QrMobileVision.getCameraStatus().then((status) {
              camState = status;
            });
            if (camState == CameraStatus.inactive) {
              showCameraPreview();
            } else {
              await QrMobileVision.stop();
              overlayEntry?.remove();
              overlayEntry = null;
            }
            await QrMobileVision.getCameraStatus().then((status) {
              camState = status;
            });

            overlayEntry?.markNeedsBuild();
          }),
    );
  }

  void showCameraPreview() {
    if (overlayEntry == null) {
      overlayEntry = OverlayEntry(
        builder: (BuildContext context) {
          return Positioned(
            top: position.dy,
            left: position.dx,
            child: camState == CameraStatus.inactive
                ? buildCamera()
                : const SizedBox.shrink(),
          );
        },
      );

      Overlay.of(context).insert(overlayEntry);
    }
  }

  Widget buildCamera() {
    return GestureDetector(
      onPanUpdate: (details) {
        _onPanUpdate(context, details);
      },
      onPanStart: (details) {
        _onPanStart(context, details);
      },
      child: Stack(
        children: <Widget>[
          SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height / 3,
            child: Material(
              elevation: 7,
              child: QrCamera(
                key: key,
                customPainter: _buildCustomPainter(),
                fit: BoxFit.cover,
                scaleResolution: 2,
                onError: (context, error) => Text(
                  error.toString(),
                  style: TextStyle(color: Colors.red),
                ),
                qrCodeCallback: (List<Barcode> code) {
                  setState(() {
                    barcodes = code;
                  });
                  overlayEntry.markNeedsBuild();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onPanStart(BuildContext context, DragStartDetails details) {
    final RenderBox renderObject = context.findRenderObject() as RenderBox;
    print(details.localPosition);
    print(details.globalPosition);
    position = renderObject.globalToLocal(Offset(
        details.globalPosition.dx - renderObject.size.height / 6,
        details.globalPosition.dy - renderObject.size.width / 6));
    overlayEntry.markNeedsBuild();
  }

  void _onPanUpdate(BuildContext context, DragUpdateDetails details) {
    final RenderBox renderObject = context.findRenderObject() as RenderBox;
    position = renderObject.globalToLocal(Offset(
        details.globalPosition.dx - renderObject.size.height / 6,
        details.globalPosition.dy - renderObject.size.width / 6));
    overlayEntry.markNeedsBuild();
  }

  List<Widget> _buildCustomPainter() {
    print(barcodes);
    if ((barcodes?.isNotEmpty ?? false)) {
      return barcodes
          .map(
            (barcode) => CustomPaint(
              foregroundPainter: barcode == null
                  ? null
                  : BarcodePainter(
                      barcode: barcode,
                      listQr: listQr,
                    ),
            ),
          )
          .toList();
    }
    return null;
  }
}

class BarcodePainter extends CustomPainter {
  BarcodePainter({this.barcode, this.detectorImageSize, this.listQr});

  final Size detectorImageSize;
  final Barcode barcode;
  final Set<String> listQr;

  @override
  void paint(Canvas canvas, Size size) {
    Rect scaleRect(Barcode barcode) {
      return Rect.fromLTRB(
        barcode.boundingBox.left,
        barcode.boundingBox.top,
        barcode.boundingBox.right,
        barcode.boundingBox.bottom,
      );
    }

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    paint.color =
        listQr.contains(barcode.rawValue) ? Colors.green : Colors.white;
    if (!listQr.contains(barcode.rawValue)) {
      HapticFeedback.mediumImpact();
      listQr.add(barcode.rawValue);
    }

    canvas.drawRect(scaleRect(barcode), paint);
  }

  @override
  bool shouldRepaint(BarcodePainter oldDelegate) {
    return true;
  }
}
