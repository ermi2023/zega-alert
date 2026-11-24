import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../services/location_service.dart';
import 'auth_gate.dart';

/// People of Determination quick actions required by the requirements
/// (Report > People of Determination: Request Direct Call, Record Sign
/// Language Video). Shared by the Home dashboard and Settings.
class PodActions extends StatefulWidget {
  const PodActions({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  State<PodActions> createState() => _PodActionsState();
}

class _PodActionsState extends State<PodActions> {
  String? _busy;

  Future<({double? lat, double? lng})> _location() async {
    try {
      final pos = await LocationService.best();
      return (lat: pos?.latitude, lng: pos?.longitude);
    } catch (_) {
      return (lat: null, lng: null);
    }
  }

  Future<void> _directCall() async {
    if (!await ensureAuthed(
      context,
      reason: 'Sign in to request a direct call from the nearest police station.',
    )) {
      return;
    }
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    setState(() => _busy = 'call');
    try {
      final pos = await _location();
      final data = await Api.post('/pod/direct-call', {
        'latitude': pos.lat,
        'longitude': pos.lng,
      });
      final station = data is Map ? data['station'] : null;
      final stationName = station is Map ? (station['name'] ?? 'nearest station') : 'nearest station';
      final stationPhone = station is Map ? station['phone']?.toString() : null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Direct call request sent to $stationName.')),
      );
      if (stationPhone != null && stationPhone.isNotEmpty) {
        final uri = Uri(scheme: 'tel', path: stationPhone);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.callingNumber(stationPhone ?? '0911'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.couldNotStartCall(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _recordSignLanguage() async {
    if (!await ensureAuthed(
      context,
      reason: 'Sign in to send a sign language video to the police.',
    )) {
      return;
    }
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    setState(() => _busy = 'video');
    try {
      final file = await ImagePicker().pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 60),
      );
      if (file == null) return;

      String? videoUrl;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final up = await Api.uploadBytes('/upload/single', [
          MapEntry('file', bytes),
        ], filenames: {'file': file.name});
        videoUrl = Api.assetUrl(up['url']?.toString());
      } else {
        final up = await Api.upload('/upload/single', [MapEntry('file', file.path)]);
        videoUrl = Api.assetUrl(up['url']?.toString());
      }

      final pos = await _location();
      await Api.post('/pod/sign-language', {
        'video_url': videoUrl,
        'note': 'Sign language video message',
        'latitude': pos.lat,
        'longitude': pos.lng,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.signLanguageRecorded)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.couldNotRecordVideo(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeading) ...[
          Row(
            children: [
              Icon(Icons.accessible_forward, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              const Text(
                'People of Determination',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Call the nearest station or send a sign language video. No typing needed.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.tonalIcon(
          onPressed: _busy == null ? _directCall : null,
          icon: _busy == 'call'
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.phone_in_talk_outlined),
          label: Text(loc.requestDirectCall),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: _busy == null ? _recordSignLanguage : null,
          icon: _busy == 'video'
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.videocam_outlined),
          label: Text(loc.recordSignLanguage),
        ),
      ],
    );
  }
}
