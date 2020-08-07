import 'dart:ui';

class Barcode {
  final String rawValue;
  final List<Offset> _cornerPoints;
  final Rect boundingBox;

  Barcode(Map<dynamic, dynamic> _data)
      : boundingBox = _data['left'] != null
            ? Rect.fromLTWH(
                _data['left'],
                _data['top'],
                _data['width'],
                _data['height'],
              )
            : null,
        rawValue = _data['rawValue'],
        _cornerPoints = _data['points'] == null
            ? null
            : _data['points']
                .map<Offset>((dynamic item) => Offset(
                      item[0],
                      item[1],
                    ))
                .toList();

  List<Offset> get cornerPoints => List<Offset>.from(_cornerPoints);
}
