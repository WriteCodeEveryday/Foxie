import 'dart:math';

class GeoObject {
  double lat;
  double lon;
  double head;
  double acc;

  double x = 0;
  double y = 0;
  double z = 0;

  GeoObject(this.lat, this.lon, this.head, this.acc) {
    lat = lat;
    lon = lon;
    head = head;
    acc = acc;

    preComputeGrid();
  }

  factory GeoObject.fromList(List<String> input) {
    if (input.length < 4) {
      throw Exception("Not enough points to make GeoPoint") ;
    }

    double lat = double.parse(input[0]);
    double lon = double.parse(input[1]);
    double head = double.parse(input[2]);
    double acc = double.parse(input[3]);
    //preComputeGrid();
    return GeoObject(lat, lon, head, acc);

  }

  void preComputeGrid() {
    int R = 6371; // Approximate radius of earth in KM.
    double latDegrees = lat * (pi / 180.0);
    double lonDegrees = lon * (pi / 180.0);

    x = R * cos(latDegrees) * cos(lonDegrees);
    y = R * cos(latDegrees) * sin(lonDegrees);
    z = R * sin(latDegrees);
  }

  @override
  String toString() {
    String returned = "";
    returned += "\nlat: "  + lat.toString() + "\nlon: " + lon.toString();
    returned += "\ndeg: " + head.toString() + "\ndir: " + bearingAsHuman();
    returned += "\nx: " + x.toString() + "\ny: " + y.toString() + "\nz: " + z.toString();
    return returned;
  }

  String toHumanString() {
    String returned = "";
    returned += lat.toString() + "," + lon.toString() + " @ " + bearingAsHuman();
    returned += "\n[" + x.toString() + ", " + y.toString() + ", " + z.toString() + "]";
    return returned;
  }

  String bearingAsHuman() {
    List<String> valid = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"]; // LOL, North is also valid from 315 to 360... magic.
    int value = head ~/ 45.0;
    String bearing = valid[value];
    return bearing;
  }

  @override
  bool operator ==(other) => other is GeoObject && toHumanString() == other.toHumanString();

  @override
  int get hashCode => toHumanString().hashCode;
}

class GeoPolygon {

  final List<GeoObject> _points;

  GeoPolygon({required List<GeoObject> points}): _points = List.from(points);

  // Source: https://stackoverflow.com/a/14231286
  GeoObject getCentralGeoCoordinate()
  {
    if (_points.length == 1)
    {
      return _points.single;
    }

    double x = 0;
    double y = 0;
    double z = 0;


    for (var geoCoordinate in _points)
    {
      var latitude = geoCoordinate.lat * pi / 180;
      var longitude = geoCoordinate.lon * pi / 180;

      x += cos(latitude) * cos(longitude);
      y += cos(latitude) * sin(longitude);
      z += sin(latitude);
    }

    var total = _points.length;

    x = x / total;
    y = y / total;
    z = z / total;

    var centralLongitude = atan2(y, x);
    var centralSquareRoot = sqrt(x * x + y * y);
    var centralLatitude = atan2(z, centralSquareRoot);

    return GeoObject(centralLatitude * 180 / pi, centralLongitude * 180 / pi, -1, -1);
  }

}
