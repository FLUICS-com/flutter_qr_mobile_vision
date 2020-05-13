import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_mobile_vision/qr_camera.dart';
import 'package:qr_mobile_vision/qr_mobile_vision.dart';

void main() {
  debugPaintSizeEnabled = false;
  runApp(new HomePage());
}

class HomePage extends StatefulWidget {
  @override
  HomeState createState() => new HomeState();
}

class HomeState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(home: new MyApp());
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String qr;
  bool camState = false;
  GlobalKey<QrCameraState> key = GlobalKey<QrCameraState>();

  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Plugin example app'),
      ),
      body: new Center(
        child: new Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            camState
                ? new SizedBox(
                  width: 300.0,
                  height: 200.0,
                  child: new QrCamera(
                    key: key,
                    scaleResolution: 2,
                    onError: (context, error) => Text(
                          error.toString(),
                          style: TextStyle(color: Colors.red),
                        ),
                    qrCodeCallback: (code) {
                      setState(() {
                        qr = code;
                      });
                    },
                    child: new Container(
                      decoration: new BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(color: Colors.orange, width: 10.0, style: BorderStyle.solid),
                      ),
                    ),
                  ),
                )
                : new Center(child: new Text("Camera inactive")),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: new Text("QRCODE: $qr"),
            ),
            FlatButton(child: Text('Change camera'),
            onPressed: () {
              key.currentState.switchCamera();
            },
            )
          ],
        ),
      ),
      floatingActionButton: new FloatingActionButton(
          child: new Text(
            "press me",
            textAlign: TextAlign.center,
          ),
          onPressed: () {
            setState(() {
              camState = !camState;
            });
          }),
    );
  }
}
