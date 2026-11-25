import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api.dart';
import '../widgets/translatable_text.dart';

class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({super.key, required this.item});

  final Map<String, dynamic> item;

  String get _category => (item['category'] ?? 'news').toString();

  Color get _color => switch (_category) {
        'warning' => Colors.amber.shade800,
        'road_closure' => Colors.deepOrange,
        'missing_item' => Colors.teal,
        'wanted' => Colors.red,
        'missing' => Colors.orange,
        'legal' => Colors.indigo,
        'event' => Colors.purple,
        _ => const Color(0xFF1E40AF),
      };

  IconData get _icon => switch (_category) {
        'warning' => Icons.warning_amber,
        'road_closure' => Icons.traffic,
        'missing_item' => Icons.inventory_2_outlined,
        'wanted' => Icons.gavel,
        'missing' => Icons.person_search,
        'legal' => Icons.gavel,
        'event' => Icons.event,
        _ => Icons.article,
      };

  String get _label => switch (_category) {
        'warning' => 'Safety alert',
        'road_closure' => 'Road closure',
        'missing_item' => 'Lost & found',
        'wanted' => 'Wanted person',
        'missing' => 'Missing person',
        'legal' => 'Legal information',
        'event' => 'Event',
        _ => 'News',
      };

  String get _date {
    final raw = item['published_at'] ?? item['created_at'];
    if (raw == null) return '';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return raw.toString();
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  Future<void> _share(BuildContext context) async {
    final r = await Share.share(
      '${item['title'] ?? ''}\n\n${item['body'] ?? ''}\n\n'
      'Shared via ZEGA-ALERT\n#ZEGAALERT #EthiopianFederalPolice #PublicSafety',
    );
    await Api.recordShare('announcement', item['id']?.toString(), platform: Api.platformFromRaw(r.raw));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final translations = item['translations'];
    final body = (item['body'] ?? '').toString();
    final image = Api.assetUrl(item['image_url']?.toString());

    return Scaffold(
      appBar: AppBar(
        title: Text(_label),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: () => _share(context),
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_color, _color.withValues(alpha: 0.8)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_icon, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(_label.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
                  ],
                ),
                const SizedBox(height: 10),
                TranslatableText(
                  text: item['title'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.25),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (_date.isNotEmpty) _headerBadge(Icons.schedule, _date),
                    if (item['region'] != null) _headerBadge(Icons.location_on_outlined, item['region'].toString()),
                    if (item['author_name'] != null) _headerBadge(Icons.verified_user_outlined, item['author_name'].toString()),
                  ],
                ),
              ],
            ),
          ),
          if (image != null && image.isNotEmpty)
            Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TranslatableText(
              text: body,
              style: const TextStyle(fontSize: 16, height: 1.55),
            ),
          ),
          if (_category == 'road_closure' && item['latitude'] != null && item['longitude'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.traffic, size: 18, color: scheme.primary),
                      const SizedBox(width: 6),
                      const Text('Affected area', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 220,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(
                            (item['latitude'] as num).toDouble(),
                            (item['longitude'] as num).toDouble(),
                          ),
                          initialZoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                            userAgentPackageName: 'com.zega.alert',
                          ),
                          MarkerLayer(markers: [
                            Marker(
                              point: LatLng(
                                (item['latitude'] as num).toDouble(),
                                (item['longitude'] as num).toDouble(),
                              ),
                              width: 44,
                              height: 44,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 44),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (translations is List && translations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.translate, size: 18, color: scheme.primary),
                      const SizedBox(width: 6),
                      const Text('Other languages', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...translations.whereType<Map>().map((t) {
                    final lang = (t['language'] ?? '').toString().toUpperCase();
                    return Card(
                      child: ExpansionTile(
                        dense: true,
                        title: Text(lang.isEmpty ? 'Translation' : lang),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (t['title'] != null)
                                  Text(t['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text((t['body'] ?? '').toString(), style: const TextStyle(height: 1.45)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}
