import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_mobile_vision/qr_camera.dart';
import 'package:qr_mobile_vision/qr_mobile_vision.dart';

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
  bool camState = false;
  int counter = 0;
  Offset position;
  Set<String> listQr = Set();
  OverlayEntry overlayEntry;

  @override
  initState() {
    super.initState();
    position = Offset(30, 30);
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
                    QrMobileVision.switchCamera();
                  },
                ),
                child: FlatButton(
                  child: Text('Change camera'),
                  onPressed: () {
                    QrMobileVision.switchCamera();
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
                child: Text('Zoom'),
                onPressed: () {
                  QrMobileVision.toggleZoom();
                },
              ),
              FlatButton(
                child: Text('Position'),
                onPressed: () {
                  position = Offset(30, 30);
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
          onPressed: () {
            camState = !camState;
            showCameraPreview();
            overlayEntry.markNeedsBuild();
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
            child: camState ? buildCamera() : const SizedBox.shrink(),
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
      child: SizedBox(
        width: 300,
        height: 200,
        child: Material(
          elevation: 7,
          child: QrCamera(
            scaleResolution: 2,
            onError: (context, error) => Text(
              error.toString(),
              style: TextStyle(color: Colors.red),
            ),
            qrCodeCallback: (code) {
              if (!listQr.contains(code)) {
                setState(() {
                  listQr.add(code);
                  qr = code;
                  counter++;
                });
              }
            },
          ),
        ),
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
}
