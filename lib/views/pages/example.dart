import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;

class Example extends StatefulWidget {
  final Widget leading = const Icon(Icons.map);
  final String title = 'Location Component';
  final String? subtitle = null;

  const Example({super.key});

  @override
  State<StatefulWidget> createState() => LocationExampleState();
}

class LocationExampleState extends State<Example> {
  LocationExampleState();

  final colors = [Colors.amber, Colors.black, Colors.blue];

  MapboxMap? mapboxMap;
  int _accuracyColor = 0;
  int _pulsingColor = 0;
  int _accuracyBorderColor = 0;
  double _puckScale = 10.0;

  // Variable de posición en el State (puede cambiar)
  geo.Position? position;

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    // Obtener ubicación cuando el mapa está listo
    _getMyLocation();
  }

  @override
  void initState() {
    super.initState();
    _getMyLocation();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _getMyLocation() {
    return TextButton(
      child: Text('Obtener mi ubicación'),
      onPressed: () async {
        // Aquí va el paso 4:
        position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
        );
        print('Mi ubicación: ${position?.latitude}, ${position?.longitude}');
      },
    );
  }

  Widget _show() {
    return TextButton(
      child: Text('show location'),
      onPressed: () async {
        mapboxMap?.location.updateSettings(LocationComponentSettings(enabled: true));
        position = await geo.Geolocator.getCurrentPosition();
        print('Mi ubicación: ${position?.latitude}, ${position?.longitude}');
        mapboxMap?.flyTo(
            CameraOptions(
              center: Point(coordinates: Position(position!.longitude, position!.latitude)),
              zoom: 15.5,
            ),
            MapAnimationOptions());
      },
    );
  }

  Widget _hide() {
    return TextButton(
      child: Text('hide location'),
      onPressed: () {
        mapboxMap?.location.updateSettings(LocationComponentSettings(enabled: false));
      },
    );
  }

  Widget _showBearing() {
    return TextButton(
      child: Text('show location bearing'),
      onPressed: () {
        mapboxMap?.location.updateSettings(LocationComponentSettings(puckBearingEnabled: true));
      },
    );
  }

  Widget _hideBearing() {
    return TextButton(
      child: Text('hide location bearing'),
      onPressed: () {
        mapboxMap?.location.updateSettings(LocationComponentSettings(puckBearingEnabled: false));
      },
    );
  }

  Widget _showPulsing() {
    return TextButton(
      child: Text('show pulsing'),
      onPressed: () {
        mapboxMap?.location.updateSettings(LocationComponentSettings(pulsingEnabled: true));
      },
    );
  }

  Widget _hidePulsing() {
    return TextButton(
      child: Text('hide pulsing'),
      onPressed: () {
        mapboxMap?.location.updateSettings(LocationComponentSettings(pulsingEnabled: false));
      },
    );
  }

  Widget _showAccuracy() {
    return TextButton(
      child: Text('show accuracy'),
      onPressed: () {
        mapboxMap?.location.updateSettings(LocationComponentSettings(showAccuracyRing: true));
      },
    );
  }

  Widget _hideAccuracy() {
    return TextButton(
      child: Text('hide accuracy'),
      onPressed: () {
        mapboxMap?.location.updateSettings(LocationComponentSettings(showAccuracyRing: false));
      },
    );
  }

  Widget _switchAccuracyBorderColor() {
    return TextButton(
      child: Text('switch accuracy border color'),
      onPressed: () {
        _accuracyBorderColor++;
        _accuracyBorderColor %= colors.length;
        mapboxMap?.location.updateSettings(
            LocationComponentSettings(accuracyRingBorderColor: colors[_accuracyBorderColor].value));
      },
    );
  }

  Widget _switchAccuracyColor() {
    return TextButton(
      child: Text('switch accuracy color'),
      onPressed: () {
        _pulsingColor++;
        _pulsingColor %= colors.length;
        mapboxMap?.location.updateSettings(
            LocationComponentSettings(accuracyRingColor: colors[_pulsingColor].value));
      },
    );
  }

  Widget _switchPulsingColor() {
    return TextButton(
      child: Text('switch pulsing color'),
      onPressed: () {
        _accuracyColor++;
        _accuracyColor %= colors.length;
        mapboxMap?.location
            .updateSettings(LocationComponentSettings(pulsingColor: colors[_accuracyColor].value));
      },
    );
  }

  Widget _switchLocationPuck2D() {
    return TextButton(
      child: Text('switch to 2d puck'),
      onPressed: () async {
        final ByteData bytes = await rootBundle.load('assets/symbols/custom-icon.png');
        final Uint8List list = bytes.buffer.asUint8List();

        mapboxMap?.location.updateSettings(LocationComponentSettings(
            enabled: true,
            puckBearingEnabled: true,
            locationPuck: LocationPuck(
                locationPuck2D:
                    DefaultLocationPuck2D(topImage: list, shadowImage: Uint8List.fromList([])))));
      },
    );
  }

  Widget _switchLocationPuck3D_duck() {
    return TextButton(
      child: Text('switch to 3d puck with duck model'),
      onPressed: () {
        mapboxMap?.location.updateSettings(LocationComponentSettings(
            locationPuck: LocationPuck(
                locationPuck3D: LocationPuck3D(
                    modelUri:
                        "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Duck/glTF-Embedded/Duck.gltf",
                    modelScale: [_puckScale, _puckScale, _puckScale]))));
      },
    );
  }

  Widget _switchLocationPuck3D_car() {
    return TextButton(
      child: Text('switch to 3d puck with car model'),
      onPressed: () {
        mapboxMap?.location.updateSettings(LocationComponentSettings(
            locationPuck: LocationPuck(
                locationPuck3D: LocationPuck3D(
                    modelUri: "asset://assets/sportcar.glb",
                    modelScale: [_puckScale, _puckScale, _puckScale]))));
      },
    );
  }

  Widget _switchPuckScale() {
    return TextButton(
      child: Text('scale 3d puck'),
      onPressed: () {
        _puckScale /= 2;
        if (_puckScale < 1) {
          _puckScale = 10.0;
        }
        print("Scale : $_puckScale");
        mapboxMap?.location.updateSettings(LocationComponentSettings(
            locationPuck: LocationPuck(
                locationPuck3D: LocationPuck3D(
                    modelUri:
                        "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Duck/glTF-Embedded/Duck.gltf",
                    modelScale: [_puckScale, _puckScale, _puckScale]))));
      },
    );
  }

  Widget _getPermission() {
    return TextButton(
      child: Text('get location permission'),
      onPressed: () async {
        var status = await geo.Geolocator.requestPermission();
        bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
        print("Location granted : $status" + "Service enabled: $serviceEnabled");
      },
    );
  }

  Widget _getSettings() {
    return TextButton(
      child: Text('get settings'),
      onPressed: () {
        mapboxMap?.location
            .getSettings()
            .then((value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("""
                  Location settings : 
                    enabled : ${value.enabled}, 
                    puckBearingEnabled : ${value.puckBearingEnabled}
                    puckBearing : ${value.puckBearing}
                    pulsing : ${value.pulsingEnabled}
                    pulsing radius : ${value.pulsingMaxRadius}
                    pulsing color : ${value.pulsingColor}
                    accuracy :  ${value.showAccuracyRing},
                    accuracy color :  ${value.accuracyRingColor}
                    accuracyRingBorderColor : ${value.accuracyRingBorderColor}
                    """
                      .trim()),
                  backgroundColor: Theme.of(context).primaryColor,
                  duration: Duration(seconds: 2),
                )));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final MapWidget mapWidget = MapWidget(
      key: ValueKey("mapWidget"),
      onMapCreated: _onMapCreated,
      cameraOptions: position != null
          ? CameraOptions(
              center: Point(
                coordinates: Position(position!.longitude, position!.latitude),
              ),
              zoom: 15.5,
            )
          : CameraOptions(
              zoom: 15.5,
            ),
      //bearing: -17.6,
      //pitch: 60

      // You can set the initial center (camera position) of the Mapbox map using 'cameraOptions':
    );

    final List<Widget> listViewChildren = <Widget>[];

    listViewChildren.addAll(
      <Widget>[
        _getPermission(),
        _show(),
        _hide(),
        _switchLocationPuck2D(),
        _switchLocationPuck3D_duck(),
        _switchLocationPuck3D_car(),
        _switchPuckScale(),
        _showBearing(),
        _hideBearing(),
        _showAccuracy(),
        _hideAccuracy(),
        _showPulsing(),
        _hidePulsing(),
        _switchAccuracyColor(),
        _switchPulsingColor(),
        _switchAccuracyBorderColor(),
        _getSettings(),
      ],
    );

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: mapWidget,
        ),
        Expanded(
          flex: 1,
          child: ListView(
            children: listViewChildren,
          ),
        )
      ],
    );
  }
}
