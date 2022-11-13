import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' show distance2point, GeoPoint;
import 'package:foxie/main.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MyApp());
}

class GeoObject {
  double? lat;
  double? lon;
  double? head;
  double? acc;

  double x = 0;
  double y = 0;
  double z = 0;

  GeoObject(this.lat, this.lon, this.head, this.acc);

  GeoObject.fromList(List<String> input) {
    if (input.length < 4) {
      return;
    }

    lat = double.parse(input[0]);
    lon = double.parse(input[1]);
    head = double.parse(input[2]);
    acc = double.parse(input[3]);
  }

  @override
  String toString() {
    String returned = "";
    returned += "\nlat: "  + lat.toString() + "\nlon: " + lon.toString();
    returned += "\ndeg: " + head.toString() + "\ndir: " + bearingAsHuman();
    return returned;
  }

  String toHumanString() {
    String returned = "";
    returned += lat.toString() + "," + lon.toString() + " @ " + bearingAsHuman();
    return returned;
  }

  String bearingAsHuman() {
    List<String> valid = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"]; // LOL, North is also valid from 315 to 360... magic.
    int value = head! ~/ 45.0;
    String bearing = valid[value];
    return bearing;
  }

  @override
  bool operator ==(other) => other is GeoObject && toHumanString() == other.toHumanString();

}
Future<CompassEvent> _determineBearing() async {
  return FlutterCompass.events!.first;
}

Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await Geolocator.getCurrentPosition();
}

Future<double> getLargestDistance(GeoObject e, List<GeoObject> points) async {
  double largest = 0;
  for (var element in points) {
    double distance = await distance2point(
        GeoPoint(longitude: e.lon!,latitude: e.lat!),
        GeoPoint(longitude: element.lon!, latitude: element.lat!)
    );

    if (distance > largest) {
      largest = distance;
    }
  }
  return largest / 1000;
}

LatLng computeCoordinateAtDistance(GeoObject e, double head, double largest) {
  if (head < 0) {
    head += 360;
  } else if (head > 360) {
    head -= 360;
  }

  double R = 6738;
  double heading = head; // 0 - north;
  double x = sin(heading) * largest;
  double y = cos(heading) * largest;

  double lat  = e.lat!  + (y / R) * (180 / pi);
  double lon = e.lon! + (x / R) * (180 / pi) / cos(e.lat! * pi/180);

  if (lat > 90) {
    lat -= 90;
  } else if (lat < -90) {
    lat += 90;
  }

  if (lon > 180) {
    lon -= 180;
  } else if (lon < -180) {
    lon += 180;
  }


  return LatLng(lat, lon);
}

Future<List<LatLng>> computePolygon(GeoObject e, List<GeoObject> points) async {
  List<LatLng> polygon = List.empty(growable: true);
  polygon.add(LatLng(e.lat!, e.lon!));

  double largest = await getLargestDistance(e, points);

  polygon.add(computeCoordinateAtDistance(e, e.head! - e.acc!, largest));
  polygon.add(computeCoordinateAtDistance(e, e.head! + e.acc!, largest));

  polygon.add(LatLng(e.lat!, e.lon!));
  return polygon;
}

Future<List<LatLng>> computeLine(GeoObject e, List<GeoObject> points) async {
  List<LatLng> line = List.empty(growable: true);
  line.add(LatLng(e.lat!, e.lon!));

  double largest = await getLargestDistance(e, points);
  line.add(computeCoordinateAtDistance(e, e.head!, largest));

  line.add(LatLng(e.lat!, e.lon!));
  return line;
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foxie',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        //primarySwatch: Colors.cyan,
        colorScheme: const ColorScheme.dark(),
        secondaryHeaderColor: Colors.white,
        scaffoldBackgroundColor: Colors.black
      ),
      home: const MyHomePage(title: 'Foxie - Fox Hunt Them All!'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String value = "Tap to Run GPS/Bearing Tests\nBe Patient, this is SLOW!";
  List<GeoObject> points = List.empty(growable: true);
  bool map = false;
  StreamSubscription<CompassEvent>? thread;
  late FlutterMap flutterMap;

  @override
  void initState() {
    super.initState();
    repaintMap();
  }

  Future<GeoObject> getGeoObject() async {
    Position gps = await _determinePosition();
    CompassEvent compass = await _determineBearing();
    return GeoObject(
        gps.latitude, gps.longitude, compass.heading, compass.accuracy);
  }

  Future<void> repaintMap() async {
    GeoObject user = await getGeoObject();

    flutterMap = FlutterMap(
      mapController: MapController(),
      options: MapOptions(
        center: LatLng(user.lat!, user.lon!),
        zoom: 13,
        maxZoom: 19
      ), nonRotatedChildren: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          userAgentPackageName: 'com.foxhuntapp.foxie',
        ),
        PolygonLayer(
          polygonCulling: false,
          polygons: await _pointsToPolygons(points),
        ),PolylineLayer(
            polylineCulling: false,
            polylines: await _pointsToPolylines(points)
        ),
       MarkerLayer(
          markers: [ ...points.map((e) =>
                Marker(
                  point: LatLng(e.lat!, e.lon!),
                  width: 24,
                  height: 24,
                  builder: (context) => const Icon(
                    FontAwesomeIcons.signal,
                    color: Colors.black,
                    size: 24,
                    ),
                  ),
                ),
                Marker(
                  point: LatLng(user.lat!, user.lon!),
                  width: 24,
                  height: 24,
                  builder: (context) => const Icon(
                    FontAwesomeIcons.satelliteDish,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
              ],
        ),
        AttributionWidget.defaultWidget(
          source: '© OpenStreetMap via flutter_map',
          onSourceTapped: () {}, alignment: Alignment.bottomCenter
        ),
      ]
    );
  }

  ///
  /// Helper for converting a list of GoeObjects into
  /// a list of polygons
  ///
  Future<List<Polygon>> _pointsToPolygons(List<GeoObject> points) async {
    List<Future<Polygon>> polygonsFutures = points.map((e) async =>
    await _geoToPolygon(e, points)).toList();

    List<Polygon> outPoly = List.empty(growable: true);
    for (Future<Polygon> ft in polygonsFutures) {
      outPoly.add(await ft);
    }
    return outPoly;
  }

  Future<List<Polyline>> _pointsToPolylines(List<GeoObject> points) async {
    List<Future<Polyline>> polyFutures = points.map((e) async =>
    await _geoToPolyline(e, points)).toList();

    List<Polyline> outPolylines = List.empty(growable: true);
    for (Future<Polyline> ft in polyFutures) {
      outPolylines.add(await ft);
    }
    return outPolylines;
  }

  Future<Polygon> _geoToPolygon(GeoObject point, List<GeoObject> points) async {
    return Polygon(
        points: await computePolygon(point, points),
        color: Colors.teal.shade700,
        isFilled: true
    );
  }

  Future<Polyline> _geoToPolyline(GeoObject point, List<GeoObject> points) async {
    return Polyline(
            points: await computeLine(point, points),
            color: Colors.red.shade700,
        );
  }

  void updateValue() async {
    if (thread == null) {
      thread = FlutterCompass.events?.listen((event) async {
        Position gps = await _determinePosition();
        GeoObject obj = GeoObject(
            gps.latitude, gps.longitude, event.heading, event.accuracy);
        String newValue = obj.toString();
        setState(() {
          value = "Tap to Stop GPS Testing\n" + newValue;
        });
      });
    } else {
      thread?.cancel();
      thread = null;
      setState(() {
        value = "GPS Testing Stopped. Tap to Restart.";
      });
    }
  }

  void toggleMap() async {
    await repaintMap();
    map = !map;

    setState(() {
      value = "Toggling Map.";
    });
  }

  void createNewPoint() async {
    GeoObject obj = await getGeoObject();
    points.add(obj);
    repaintMap();

    if (thread != null) {
      thread?.cancel();
      thread = null;
    }

    setState(() {
      value = "Tap to Restart GPS Testing.";
    });
  }

  void purgePoints() async {
    points.clear();
    repaintMap();

    setState(() {
      value = "Points Purged.";
    });
  }

  void importPoints() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        withReadStream: true);

    if (result != null) {
      File file = File(result.files.single.path!);
      String input = await file.readAsString();
      List<String> lines = input.split("\n");
      for (var line in lines) {
        List<String> data = line.split(",");
        if (data.length == 4) {
          GeoObject point = GeoObject.fromList(data);
          if (!points.contains(point)) {
            points.add(point);
          }
        }
      }

      setState(() {
        value = "Points Added To Map.";
      });
    } else {
      // User canceled the picker
    }
  }

  void exportPoints() async {
    String values = "";
    for (var element in points) {
      values += element.lat.toString() + "," + element.lon.toString() + "," +
          element.head.toString() + "," + element.acc.toString() + "\n";
    }

    // storage permission ask
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    // the downloads folder path
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    var filePath = appDocPath + '/foxie-export.csv';
    await File(filePath).writeAsString(values);
    Share.shareXFiles([XFile(filePath)], text: 'Exported Points from Foxie');


    setState(() {
      value = "Points Exported.";
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
        ),
        body: Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
            child: Column(
              // Column is also a layout widget. It takes a list of children and
              // arranges them vertically. By default, it sizes itself to fit its
              // children horizontally, and tries to be as tall as its parent.
              //
              // Invoke "debug painting" (press "p" in the console, choose the
              // "Toggle Debug Paint" action from the Flutter Inspector in Android
              // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
              // to see the wireframe for each widget.
              //
              // Column has various properties to control how it sizes itself and
              // how it positions its children. Here we use mainAxisAlignment to
              // center the children vertically; the main axis here is the vertical
              // axis because Columns are vertical (the cross axis would be
              // horizontal).
              mainAxisAlignment: MainAxisAlignment.center,
              children: map ? <Widget>[
                TextButton(
                    style: ButtonStyle(
                      foregroundColor: MaterialStateProperty.all<Color>(
                          Colors.white),
                    ),
                    onPressed: toggleMap,
                    child: const Text("Close Map", textAlign: TextAlign.center,
                        textScaleFactor: 1.4)),
                Expanded(
                  child: flutterMap
                )
              ] :
              (points.isNotEmpty ?
              <Widget>[
                ListView(
                  children: [
                    TextButton(
                      style: ButtonStyle(
                        foregroundColor: MaterialStateProperty.all<Color>(
                            Colors.red),
                      ),
                      onPressed: purgePoints,
                      child: const Text('Delete Points', textScaleFactor: 1.3,),
                    ), ...points.map((element) {
                      return Text(
                          element.toHumanString(), textAlign: TextAlign.center,
                          textScaleFactor: 1.2);
                    }).toList(),
                    TextButton(
                        style: ButtonStyle(
                          foregroundColor: MaterialStateProperty.all<Color>(
                              Colors.white),
                        ),
                        onPressed: updateValue,
                        child: Text(value, textAlign: TextAlign.center)),
                    Row(
                      children: <Widget>[
                        Expanded(
                            child:  TextButton(
                              style:
                                ButtonStyle(
                                  foregroundColor: MaterialStateProperty.all<Color>(
                                    Colors.white),
                                  ),
                                  onPressed: toggleMap,
                                  child: const Text(
                                    "Open Map", textAlign: TextAlign.center,
                                  textScaleFactor: 1.4)
                            )
                        )
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                            child: TextButton(
                                style: ButtonStyle(
                                  foregroundColor: MaterialStateProperty.all<
                                      Color>(Colors.white),
                                ),
                                onPressed: importPoints,
                                child: const Text('Import Points',
                                    textAlign: TextAlign.center,
                                    textScaleFactor: 1.3)
                            )
                        ),
                        Expanded(
                            child: TextButton(
                                style: ButtonStyle(
                                  foregroundColor: MaterialStateProperty.all<
                                      Color>(Colors.white),
                                ),
                                onPressed: exportPoints,
                                child: const Text('Export Points',
                                    textAlign: TextAlign.center,
                                    textScaleFactor: 1.3)
                            )
                        ),
                      ],
                    ),
                  ],
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                )
              ] :
              <Widget>[
                TextButton(
                    style: ButtonStyle(
                      foregroundColor: MaterialStateProperty.all<Color>(
                          Colors.white),
                    ),
                    onPressed: updateValue,
                    child: Text(value, textAlign: TextAlign.center)),
                TextButton(
                    style: ButtonStyle(
                      foregroundColor: MaterialStateProperty.all<Color>(
                          Colors.white),
                    ),
                    onPressed: importPoints,
                    child: const Text(
                        'Import Points', textAlign: TextAlign.center,
                        textScaleFactor: 1.3)
                )
              ])
              ),
            ),
        floatingActionButton: !map ? (FloatingActionButton(
          onPressed: createNewPoint,
          tooltip: 'Add Point',
          backgroundColor: Colors.white,
          child: const Icon(Icons.explore, color: Colors.black),
        )) : null
    );
  }
}