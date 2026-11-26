import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';

List<LatLng> _readPolygon(dynamic value) {
  if (value is! List) return [];
  final points = <LatLng>[];
  for (final point in value) {
    if (point is List &&
        point.length >= 2 &&
        point[0] is num &&
        point[1] is num) {
      points.add(
        LatLng((point[0] as num).toDouble(), (point[1] as num).toDouble()),
      );
    } else if (point is Map && point['lat'] is num && point['lng'] is num) {
      points.add(
        LatLng(
          (point['lat'] as num).toDouble(),
          (point['lng'] as num).toDouble(),
        ),
      );
    } else if (point is Map &&
        point['latitude'] is num &&
        point['longitude'] is num) {
      points.add(
        LatLng(
          (point['latitude'] as num).toDouble(),
          (point['longitude'] as num).toDouble(),
        ),
      );
    }
  }
  return points;
}

class GeofenceMapScreen extends StatelessWidget {
  const GeofenceMapScreen({super.key, required this.geofence});

  final Map<String, dynamic> geofence;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final polygon = _readPolygon(geofence['polygon']);
    final centerLat = (geofence['center_lat'] as num?)?.toDouble();
    final centerLng = (geofence['center_lng'] as num?)?.toDouble();
    final center = centerLat != null && centerLng != null
        ? LatLng(centerLat, centerLng)
        : polygon.isNotEmpty
        ? LatLng(
            polygon.map((point) => point.latitude).reduce((a, b) => a + b) /
                polygon.length,
            polygon.map((point) => point.longitude).reduce((a, b) => a + b) /
                polygon.length,
          )
        : null;
    final radius = (geofence['radius_m'] as num?)?.toDouble();
    final hasPolygon = polygon.length >= 3;

    return Scaffold(
      appBar: AppBar(title: Text(geofence['name'] ?? loc.safetyZones)),
      body: center == null
          ? const Center(child: Text('The area boundary is not available yet.'))
          : Column(
              children: [
                Expanded(
                  child: FlutterMap(
                    options: MapOptions(initialCenter: center, initialZoom: 15),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.zega.alert',
                      ),
                      if (hasPolygon)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: polygon,
                              color: Colors.blue.withValues(alpha: 0.2),
                              borderStrokeWidth: 2,
                              borderColor: Colors.blue,
                            ),
                          ],
                        )
                      else if (radius != null && radius > 0)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: center,
                              radius: radius,
                              color: Colors.blue.withValues(alpha: 0.2),
                              borderStrokeWidth: 2,
                              borderColor: Colors.blue,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: center,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text(
                        (geofence['type'] ?? 'safety area')
                            .toString()
                            .replaceAll('_', ' '),
                      ),
                      subtitle: Text(
                        hasPolygon
                            ? 'Official mapped boundary. SOS reports inside it are highlighted for emergency staff.'
                            : radius != null && radius > 0
                            ? 'Official area · ${radius.round()} m radius. SOS reports inside it are highlighted for emergency staff.'
                            : 'The area boundary is not available yet.',
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
