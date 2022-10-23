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
  bool isShow = false;
  String? qr;
  CameraStatus camState = CameraStatus.active;
  late Offset position;
  Set<String> listQr = Set();
  GlobalKey<QrCameraState> key = GlobalKey();

  List<Barcode>? barcodes;

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
              TextButton(
                child: Text('Change camera'),
                onPressed: () {
                  QrMobileVision.setCameraLensFacing(CameraLensDirection.front);
                  key.currentState!.updateTextureSize();
                },
              ),
              TextButton(
                child: Text('Torch'),
                onPressed: () {
                  QrMobileVision.toggleTorch();
                },
              ),
              TextButton(
                child: Text('Clear'),
                onPressed: () {
                  barcodes!.clear();
                },
              ),
              TextButton(
                child: Text('Zoom'),
                onPressed: () {
                  QrMobileVision.setZoomFactor(CameraZoomFactor.zoom_2x);
                },
              ),
              isShow
                  ? Camera(
                      qrCodeCallback: (List<Barcode> code) {
                        setState(() {
                          barcodes = code;
                        });
                      },
                      customPainter: _buildCustomPainter())
                  : SizedBox.shrink(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            isShow = !isShow;
          });
        },
        child: Icon(Icons.camera),
      ),
    );
  }

  CustomPainter? _buildCustomPainter() {
    if ((barcodes?.isNotEmpty ?? false)) {
      return BarcodePainter(
        barcodes: barcodes,
        listQr: listQr,
      );
    }
    return null;
  }
}

class Camera extends StatelessWidget {
  const Camera({
    Key? key,
    required this.qrCodeCallback,
    required this.customPainter,
  }) : super(key: key);
  final ValueSetter<List<Barcode>> qrCodeCallback;
  final CustomPainter? customPainter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        width: 400,
        height: 200,
        child: QrCamera(
          key: key,
          customPainter: customPainter,
          scaleResolution: 2,
          onError: (context, error) => Text(
            error.toString(),
            style: TextStyle(color: Colors.red),
          ),
          qrCodeCallback: qrCodeCallback,
        ),
      ),
    );
  }
}

class BarcodePainter extends CustomPainter {
  BarcodePainter({this.barcodes, this.detectorImageSize, this.listQr});

  final Size? detectorImageSize;
  final List<Barcode>? barcodes;
  final Set<String?>? listQr;

  @override
  void paint(Canvas canvas, Size size) {
    for (var barcode in barcodes!) {
      Rect scaleRect(Barcode barcode) {
        return Rect.fromLTRB(
          barcode.boundingBox!.left,
          barcode.boundingBox!.top,
          barcode.boundingBox!.right,
          barcode.boundingBox!.bottom,
        );
      }

      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;

      paint.color =
          listQr!.contains(barcode.rawValue) ? Colors.green : Colors.white;
      if (!listQr!.contains(barcode.rawValue)) {
        HapticFeedback.mediumImpact();
        listQr!.add(barcode.rawValue);
      }

      canvas.drawRect(scaleRect(barcode), paint);
    }
  }

  @override
  bool shouldRepaint(BarcodePainter oldDelegate) {
    return true;
  }
}
