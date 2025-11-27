import 'package:app_location_alarm_reconecta/views/pages/simpleview_page.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;

class DestinationPage extends StatefulWidget {
  const DestinationPage({super.key});

  @override
  State<DestinationPage> createState() => _DestinationPageState();
}

class _DestinationPageState extends State<DestinationPage> {
  MapboxMap? mapboxMap;
  geo.Position? position;

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    // Obtener ubicación cuando el mapa está listo
    _getLastKnownLocation();
    _getMyLocation();
  }

  @override
  void initState() {
    super.initState();

    print('initState');
    if (mapboxMap?.location.updateSettings(LocationComponentSettings(enabled: true)) != null) {
      print('LocationComponentSettings updated');
    } else {
      print('LocationComponentSettings not updated');
    }
  }

  @override
  void dispose() {
    // Limpiar la referencia cuando el widget se destruye
    // para evitar usar el objeto Style después de que el MapView sea destruido
    mapboxMap = null;
    super.dispose();
  }

  MapWidget get mapWidget => MapWidget(
        key: ValueKey("mapWidget"),
        onMapCreated: _onMapCreated,
        styleUri: MapboxStyles.OUTDOORS,

        cameraOptions: position != null
            ? CameraOptions(
                center: Point(
                  coordinates: Position(position!.longitude, position!.latitude),
                ),
                zoom: 12,
              )
            : CameraOptions(
                zoom: 12,
              ),
        //bearing: -17.6,
        //pitch: 60

        // You can set the initial center (camera position) of the Mapbox map using 'cameraOptions':
      );

  Future<Widget> _getLastKnownLocation() async {
    position = await geo.Geolocator.getLastKnownPosition();
    print('Mi ubicación: ${position?.latitude}, ${position?.longitude}');
    mapboxMap?.location.updateSettings(LocationComponentSettings(enabled: true));
    try {
      mapboxMap?.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(position!.longitude, position!.latitude)),
            zoom: 14,
          ),
          MapAnimationOptions(startDelay: 0, duration: 0));
    } catch (e) {
      return mapWidget;
    }

    return mapWidget;
  }

  Future<void> _getMyLocation() async {
    position = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high,
    );
    print('Mi ubicación: ${position?.latitude}, ${position?.longitude}');
    mapboxMap?.location.updateSettings(LocationComponentSettings(enabled: true));
    mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(position!.longitude, position!.latitude)),
          zoom: 14,
        ),
        MapAnimationOptions(startDelay: 0, duration: 0));
  }

  @override
  Widget build(BuildContext context) {
    mapboxMap?.location.updateSettings(LocationComponentSettings(enabled: true));
    return Scaffold(
        appBar: AppBar(
          title: Text('Select the point of interest'),
          leading: IconButton(
            onPressed: () {
              _getMyLocation();
              print('Refreshed');
            },
            icon: Icon(Icons.refresh),
            alignment: Alignment.topRight,
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: MapWidget(
                  key: ValueKey("mapWidget"),
                  onMapCreated: _onMapCreated,
                  //styleUri: MapboxStyles.LIGHT,
                ),
              ),
            ),
            FilledButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) {
                      return SimpleviewPage();
                    },
                  ));
                },
                child: Text('Save'))
          ],
        ));
  }
}
