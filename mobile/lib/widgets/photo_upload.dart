import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';

class PhotoUploadField extends StatefulWidget {
  const PhotoUploadField({
    super.key,
    this.label,
    this.onUploaded,
  });

  final String? label;
  final ValueChanged<String?>? onUploaded;

  @override
  State<PhotoUploadField> createState() => _PhotoUploadFieldState();
}

class _PhotoUploadFieldState extends State<PhotoUploadField> {
  String? _url;
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    final loc = AppLocalizations.of(context);
    setState(() { _error = null; _busy = true; });
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Wrap(children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(loc.takePhoto),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(loc.chooseFromGallery),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ]),
        ),
      );
      if (source == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (file == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final res = await Api.upload('/upload/single', [
        MapEntry('file', file.path),
      ]);
      final url = res['url'] as String;
      setState(() {
        _url = '${Api.baseUrl}$url';
        _busy = false;
      });
      widget.onUploaded?.call('${Api.baseUrl}$url');
    } catch (e) {
      setState(() { _busy = false; _error = 'Upload failed: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final displayLabel = widget.label ?? 'Add photo';
    if (_url != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(_url!, height: 160, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 160, color: Colors.grey.shade200, child: const Icon(Icons.broken_image, size: 40))),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () {
                setState(() => _url = null);
                widget.onUploaded?.call(null);
              },
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _pick,
          icon: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.camera_alt_outlined),
          label: Text(_busy ? loc.uploading : displayLabel),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
      ],
    );
  }
}
