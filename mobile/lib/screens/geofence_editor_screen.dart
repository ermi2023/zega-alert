import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api.dart';

const _types = ['zone', 'school', 'police_station', 'hospital', 'event', 'residence', 'market'];
const _sensitivities = ['low', 'medium', 'high'];

class GeofenceEditorScreen extends StatefulWidget {
  const GeofenceEditorScreen({super.key, this.geofence});

  final Map<String, dynamic>? geofence;

  @override
  State<GeofenceEditorScreen> createState() => _GeofenceEditorScreenState();
}

class _GeofenceEditorScreenState extends State<GeofenceEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _label;
  late final TextEditingController _radius;
  late String _type;
  late String _sensitivity;
  late bool _active;
  late LatLng _center;
  late List<LatLng> _polygon;
  bool _drawMode = false;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.geofence != null;

  @override
  void initState() {
    super.initState();
    final g = widget.geofence;
    _name = TextEditingController(text: g?['name']?.toString() ?? '');
    _label = TextEditingController(text: g?['label']?.toString() ?? '');
    _radius = TextEditingController(text: (g?['radius_m'] ?? 300).toString());
    _type = _types.contains(g?['type']) ? g!['type'] as String : 'zone';
    _sensitivity = _sensitivities.contains(g?['sensitivity']) ? g!['sensitivity'] as String : 'medium';
    _active = g?['is_active'] != false;
    _center = LatLng(
      (g?['center_lat'] as num?)?.toDouble() ?? 9.03,
      (g?['center_lng'] as num?)?.toDouble() ?? 38.74,
    );
    final poly = g?['polygon'];
    _polygon = poly is List
        ? poly.map<LatLng>((p) {
            if (p is List && p.length >= 2) return LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble());
            if (p is Map) {
              return LatLng(
                ((p['lat'] ?? p['latitude']) as num).toDouble(),
                ((p['lng'] ?? p['longitude']) as num).toDouble(),
              );
            }
            return const LatLng(0, 0);
          }).where((p) => p.latitude != 0 || p.longitude != 0).toList()
        : <LatLng>[];
  }

  @override
  void dispose() {
    _name.dispose();
    _label.dispose();
    _radius.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'label': _label.text.trim().isEmpty ? _name.text.trim() : _label.text.trim(),
      'type': _type,
      'sensitivity': _sensitivity,
      'is_active': _active,
      'center_lat': _center.latitude,
      'center_lng': _center.longitude,
      'radius_m': int.tryParse(_radius.text.trim()) ?? 300,
      'region': Api.region,
      'sub_city': Api.subCity,
      'polygon': _polygon.map((p) => [p.latitude, p.longitude]).toList(),
    };
    try {
      if (_editing) {
        await Api.patch('/geofences/${widget.geofence!['id']}', body);
      } else {
        await Api.post('/geofences', body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Could not save zone: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = double.tryParse(_radius.text.trim()) ?? 300;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit safety zone' : 'New safety zone'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.red)))),
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Zone name', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _label,
                  decoration: const InputDecoration(labelText: 'Label (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                      items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' ')))).toList(),
                      onChanged: (v) => setState(() => _type = v ?? 'zone'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sensitivity,
                      decoration: const InputDecoration(labelText: 'Sensitivity', border: OutlineInputBorder()),
                      items: _sensitivities.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _sensitivity = v ?? 'medium'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _radius,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Radius (meters)', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    return n == null || n < 50 ? 'Radius must be at least 50m' : null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => setState(() => _drawMode = false),
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Set centre'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _drawMode = true),
                icon: const Icon(Icons.polyline_outlined),
                label: const Text('Draw boundary'),
              ),
            ),
          ]),
          Row(children: [
            const Expanded(child: Text('Tap the map to set the centre or add boundary points.', style: TextStyle(fontSize: 12, color: Colors.grey))),
            TextButton(
              onPressed: _polygon.isEmpty ? null : () => setState(() => _polygon = []),
              child: const Text('Clear boundary'),
            ),
          ]),
          SizedBox(
            height: 360,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 15,
                  onTap: (_, point) {
                    setState(() {
                      if (_drawMode) {
                        _polygon = [..._polygon, point];
                      } else {
                        _center = point;
                      }
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.zega.alert',
                  ),
                  if (_polygon.length >= 2)
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: _polygon,
                          color: Colors.green.withValues(alpha: 0.18),
                          borderColor: Colors.green.shade700,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _center,
                        radius: radius,
                        color: Colors.blue.withValues(alpha: 0.18),
                        borderStrokeWidth: 2,
                        borderColor: Colors.blue,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _center,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      ),
                      ..._polygon.asMap().entries.map((e) => Marker(
                            point: e.value,
                            width: 22,
                            height: 22,
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                              child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 10))),
                            ),
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Centre: ${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)} · radius ${radius.round()}m',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
