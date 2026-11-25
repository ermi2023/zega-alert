import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../widgets/auth_gate.dart';
import '../widgets/translatable_text.dart';
import '../widgets/offline_person_image.dart';
import 'missing_report_screen.dart';

/// Full bulletin for a missing or wanted person, matching the requirement that
/// citizens can open a person notice and see photographs, description, last
/// known location and contact/charges, then share it or report a sighting.
class PersonDetailScreen extends StatelessWidget {
  const PersonDetailScreen({
    super.key,
    required this.person,
    required this.kind,
    this.onChanged,
  });

  /// 'missing' or 'wanted'.
  final String kind;
  final Map<String, dynamic> person;
  final VoidCallback? onChanged;

  bool get _isWanted => kind == 'wanted';

  String get _status {
    final s =
        (person['status'] ??
                (person['is_approved'] == false ? 'pending' : 'active'))
            .toString();
    return s.replaceAll('_', ' ').toUpperCase();
  }

  bool get _active {
    final s = (person['status'] ?? '').toString();
    return _isWanted ? s != 'captured' : s == 'missing';
  }

  String _date(Object? value) {
    if (value == null) return '';
    final d = DateTime.tryParse(value.toString());
    if (d == null) return value.toString();
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {}
  }

  Future<void> _share(BuildContext context) async {
    final name = person['name'] ?? 'Unknown';
    final body = _isWanted
        ? 'WANTED PERSON: $name\nCrime: ${person['crime_description'] ?? 'unknown'}\n'
              'Danger level: ${person['danger_level'] ?? 'unknown'}\n'
        : 'MISSING PERSON: $name\nLast seen: ${person['last_seen_address'] ?? 'unknown'}\n'
              '${person['description'] ?? ''}\n';
    final r = await Share.share(
      '$body\nIf you have information, contact the Ethiopian Federal Police.\n'
      '#ZEGAALERT #EthiopianFederalPolice #PublicSafety',
    );
    await Api.recordShare(
      _isWanted ? 'wanted_person' : 'missing_person',
      person['id']?.toString(),
      platform: Api.platformFromRaw(r.raw),
    );
  }

  Future<void> _reportSighting(BuildContext context) async {
    if (!await ensureAuthed(context, reason: 'Sign in to report a sighting.'))
      return;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SightingReportScreen(
          missingPersonId: _isWanted ? null : person['id']?.toString(),
          wantedPersonId: _isWanted ? person['id']?.toString() : null,
          onDone: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final photo = Api.assetUrl(person['photo_url']?.toString());
    final name = (person['name'] ?? 'Unknown').toString();
    final phone = person['contact_phone']?.toString();
    final accent = _isWanted
        ? const Color(0xFFDC2626)
        : const Color(0xFFD97706);

    return Scaffold(
      appBar: AppBar(title: Text(_isWanted ? loc.wanted : loc.missing)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 280,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photo != null && photo.isNotEmpty)
                  OfflinePersonImage(
                    url: photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoFallback(scheme, name),
                  )
                else
                  _photoFallback(scheme, name),
                Positioned(
                  left: 16,
                  top: 16,
                  child: Chip(
                    label: Text(
                      _status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: accent,
                    side: BorderSide.none,
                  ),
                ),
                if (_isWanted)
                  Positioned(
                    right: 16,
                    top: 16,
                    child: Chip(
                      label: Text(
                        'DANGER: ${(person['danger_level'] ?? 'low').toString().toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor:
                          (person['danger_level'] == 'high' ||
                              person['danger_level'] == 'critical')
                          ? const Color(0xFF991B1B)
                          : const Color(0xFFB45309),
                      side: BorderSide.none,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (person['case_code'] != null)
                      _metaChip('Case ${person['case_code']}', Icons.tag),
                    if (person['age'] != null)
                      _metaChip('Age ${person['age']}', Icons.cake_outlined),
                    if (person['gender'] != null)
                      _metaChip('${person['gender']}', Icons.person_outline),
                  ],
                ),
                const SizedBox(height: 16),
                if (!_active)
                  Card(
                    color: _isWanted
                        ? Colors.green.shade50
                        : Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isWanted
                                  ? 'This person has been captured.'
                                  : 'This person has been found.',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_isWanted && person['crime_description'] != null) ...[
                  _label('Crime / charges'),
                  TranslatableText(
                    text: person['crime_description'].toString(),
                    style: const TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!_isWanted) ...[
                  _label('Last seen'),
                  _infoTile(
                    Icons.location_on_outlined,
                    person['last_seen_address'] ?? loc.unknownLocation,
                  ),
                  if (person['last_seen_at'] != null)
                    _infoTile(Icons.schedule, _date(person['last_seen_at'])),
                  if (phone != null && phone.isNotEmpty)
                    _infoTile(
                      Icons.phone_outlined,
                      phone,
                      trailing: IconButton.filledTonal(
                        icon: const Icon(Icons.call),
                        tooltip: 'Call reporter',
                        onPressed: () => _call(phone),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                if (person['description'] != null &&
                    person['description'].toString().isNotEmpty) ...[
                  _label('Description'),
                  TranslatableText(
                    text: person['description'].toString(),
                    style: const TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                ],
                if (person['created_at'] != null)
                  Text(
                    'Published ${_date(person['created_at'])}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _share(context),
                        icon: const Icon(Icons.share),
                        label: Text(loc.share),
                      ),
                    ),
                    if (_active) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _reportSighting(context),
                          icon: const Icon(Icons.visibility),
                          label: Text(loc.reportSighting),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoFallback(ColorScheme scheme, String name) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary.withValues(alpha: 0.85), scheme.primary],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: Colors.white24,
              child: Text(
                name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'No photo available',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    ),
  );

  Widget _metaChip(String text, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 15),
      label: Text(text, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _infoTile(IconData icon, Object? text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1E40AF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text?.toString() ?? '',
              style: const TextStyle(height: 1.35),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
