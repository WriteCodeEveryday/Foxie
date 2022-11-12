import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
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

  GeoObject(lat, lon, head, acc) {
    this.lat = lat;
    this.lon = lon;
    this.head = head;
    this.acc = acc;

    preComputeGrid();
  }

  GeoObject.fromList(List<String> input) {
    if (input.length < 4) {
      return;
    }

    lat = double.parse(input[0]);
    lon = double.parse(input[1]);
    head = double.parse(input[2]);
    acc = double.parse(input[3]);

    preComputeGrid();
  }

  void preComputeGrid() {
    int R = 6371; // Approximate radius of earth in KM.
    double latDegrees = lat! * (pi / 180.0);
    double lonDegrees = lon! * (pi / 180.0);

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
  late MapController controller;

  @override
  void initState() {
    super.initState();
    resetMap();
  }

  Future<GeoObject> getGeoObject() async {
    Position gps = await _determinePosition();
    CompassEvent compass = await _determineBearing();
    return GeoObject(
        gps.latitude, gps.longitude, compass.heading, compass.accuracy);
  }

  void resetMap() {
    controller = MapController(
      initMapWithUserPosition: true,
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
    map = !map;

    setState(() {
      value = "Toggling Map.";
    });
  }

  void createNewPoint() async {
    GeoObject obj = await getGeoObject();
    points.add(obj);
    controller.addMarker(GeoPointWithOrientation(
        latitude: obj.lat!, longitude: obj.lon!, angle: obj.head!));

    if (thread != null) {
      thread?.cancel();
      thread = null;
    }

    setState(() {
      value = "Tap to Restart GPS Testing.";
    });
  }

  void purgePoints() async {
    resetMap();
    points.clear();

    setState(() {
      value = "Points Purged.";
    });
  }

  GeoObject calculateCenter(List<GeoObject> points) {
    return GeoObject(1, 1, 1, 1);
  }

  int calculateSearchRadius(List<GeoObject> points) {
    return 200;
  }

  void addPointsToMap(ready) async {
    if (ready) {
      for (var element in points) {
        controller.addMarker(GeoPointWithOrientation(latitude: element.lat!,
            longitude: element.lon!,
            angle: element.head!));
      }
    }

    /*
    if (ready && points.length > 1) {
      // Calculate center point.
      double x = counterX / counter;
      double y = counterY / counter;
      double z = counterZ / counter;

      // Derive the lat and long.
      double hyp = sqrt((x * x) + (y * y));
      double lon = atan2(y, x);
      double lat = atan2(z, hyp);

      //Convert back to degrees
      lon = lon * (180/pi);
      lat = lat * (180/pi);

      controller.addMarker(GeoPoint(latitude: lat, longitude: lon), markerIcon: const MarkerIcon(
        icon: Icon(
          FontAwesomeIcons.walkieTalkie,
          color: Colors.black,
          size: 72,
        ),
      ));

      double radius = (((counterX * counterX) + (counterY * counterY))/counter);

      controller.drawCircle(CircleOSM(key: "transmitter",
          centerPoint: GeoPoint(latitude: lat, longitude: lon), radius: radius,
          color: Colors.red, strokeWidth: 10));
    } */

    setState(() {
      value = "Points Imported.";
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
                  child: OSMFlutter(
                    controller: controller,
                    showContributorBadgeForOSM: true,
                    onMapIsReady: addPointsToMap,
                    markerOption: MarkerOption(
                      defaultMarker: const MarkerIcon(
                        icon: Icon(
                          FontAwesomeIcons.signal,
                          color: Colors.black,
                          size: 96,
                        ),
                      ),
                    ),
                    userLocationMarker: UserLocationMaker(
                      personMarker: const MarkerIcon(
                        icon: Icon(
                          FontAwesomeIcons.satelliteDish,
                          color: Colors.black,
                          size: 72,
                        ),
                      ), directionArrowMarker: const MarkerIcon(
                      icon: Icon(
                        FontAwesomeIcons.arrowUp,
                        color: Colors.black,
                        size: 72,
                      ),
                    ),
                    ),
                    trackMyPosition: true,
                    initZoom: 12,
                  ),
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