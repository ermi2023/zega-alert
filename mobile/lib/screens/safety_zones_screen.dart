import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import 'geofence_map_screen.dart';

class SafetyZonesScreen extends StatefulWidget {
  const SafetyZonesScreen({super.key});

  @override
  State<SafetyZonesScreen> createState() => _SafetyZonesScreenState();
}

class _SafetyZonesScreenState extends State<SafetyZonesScreen> {
  List<dynamic> _geofences = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final region = Api.region;
      final endpoint = region == null
          ? '/geofences'
          : '/geofences?region=${Uri.encodeQueryComponent(region)}';
      final result = await Api.get(endpoint);
      if (result is! List) {
        throw const FormatException('Unexpected safety-zone response');
      }
      if (mounted) setState(() => _geofences = result);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = Api.userMessage(
            error,
            fallback: AppLocalizations.of(context).safetyZonesLoadFailed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openZone(dynamic item) {
    final zone = Map<String, dynamic>.from(item as Map);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GeofenceMapScreen(geofence: zone)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Card(
            color: const Color(0xFFEAF2FF),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.health_and_safety_outlined,
                        color: Color(0xFF123B73),
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          loc.safetyZones,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: const Color(0xFF123B73),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(loc.safetyZonesHomeDescription),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading safety zones',
                ),
              ),
            )
          else if (_error != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text(_error!),
                trailing: IconButton(
                  tooltip: 'Retry loading safety zones',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            )
          else if (_geofences.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(loc.noSafetyZonesAvailable),
              ),
            )
          else
            ..._geofences.map((item) {
              final zone = Map<String, dynamic>.from(item as Map);
              final name = (zone['label'] ?? zone['name'] ?? 'Safety zone')
                  .toString();
              final type = (zone['type'] ?? 'area').toString().replaceAll(
                '_',
                ' ',
              );
              final location = [
                if (zone['region'] != null) zone['region'].toString(),
                if (zone['sub_city'] != null) zone['sub_city'].toString(),
              ].join(' · ');
              return Card(
                child: Semantics(
                  button: true,
                  label:
                      '$name, $type. ${location.isEmpty ? '' : '$location. '}Open map and boundary.',
                  child: ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF123B73),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      [type, if (location.isNotEmpty) location].join(' · '),
                    ),
                    trailing: const Icon(Icons.map_outlined),
                    onTap: () => _openZone(item),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
