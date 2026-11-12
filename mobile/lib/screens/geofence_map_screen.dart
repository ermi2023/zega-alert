import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api.dart';
import '../l10n/app_localizations.dart';

class GeofenceMapScreen extends StatelessWidget {
  const GeofenceMapScreen({super.key, required this.geofence});

  final Map<String, dynamic> geofence;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final double lat = (geofence['center_lat'] as num?)?.toDouble() ?? 9.03; // default Addis
    final double lng = (geofence['center_lng'] as num?)?.toDouble() ?? 38.74;
    final double radius = (geofence['radius_m'] as num?)?.toDouble() ?? 200.0;

    return Scaffold(
      appBar: AppBar(title: Text(geofence['name'] ?? loc.geofence)),
      body: FlutterMap(
        options: MapOptions(
          center: LatLng(lat, lng),
          zoom: 15,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.zega.alert',
          ),
          // marker for centre
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(lat, lng),
                width: 40,
                height: 40,
                builder: (_) => const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            ],
          ),
          // visual geofence circle
          CircleLayer(
            circles: [
              CircleMarker(
                point: LatLng(lat, lng),
                radius: radius, // meters – flutter_map scales automatically
                color: Colors.blue.withOpacity(0.2),
                borderStrokeWidth: 2,
                borderColor: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
