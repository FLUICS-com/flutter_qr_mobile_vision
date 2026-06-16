import 'dart:ui';

class Barcode {
  final String? rawValue;
  final List<Offset>? _cornerPoints;
  final Rect? boundingBox;
  final num? frameWidth;
  final num? frameHeight;
  final num? frameRotation;

  Barcode(Map<dynamic, dynamic> data)
      : boundingBox = data['left'] != null
            ? Rect.fromLTWH(
                data['left'],
                data['top'],
                data['width'],
                data['height'],
              )
            : null,
        rawValue = data['rawValue'],
        frameWidth = data['frameWidth'],
        frameHeight = data['frameHeight'],
        frameRotation = data['frameRotation'],
        _cornerPoints = data['points']?.map<Offset>((dynamic item) {
          return Offset(
            item[0],
            item[1],
          );
        }).toList();

  List<Offset> get cornerPoints => List<Offset>.from(_cornerPoints!);
}
