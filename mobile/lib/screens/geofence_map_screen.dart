import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
      appBar: AppBar(title: Text(geofence['name'] ?? loc.safetyZones)),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(lat, lng),
          initialZoom: 15,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.zega.alert',
          ),
          // visual geofence circle
          CircleLayer(
            circles: [
              CircleMarker(
                point: LatLng(lat, lng),
                radius: radius, // meters – flutter_map scales automatically
                color: Colors.blue.withValues(alpha: 0.2),
                borderStrokeWidth: 2,
                borderColor: Colors.blue,
              ),
            ],
          ),
          // marker for centre
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(lat, lng),
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
