import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';

class PhotoUploadField extends StatefulWidget {
  const PhotoUploadField({
    super.key,
    this.label,
    this.onUploaded,
    this.onPhotosChanged,
    this.allowMultiple = true,
  });

  final String? label;
  final ValueChanged<String?>? onUploaded;
  final ValueChanged<List<String>>? onPhotosChanged;
  final bool allowMultiple;

  @override
  State<PhotoUploadField> createState() => _PhotoUploadFieldState();
}

class _PhotoUploadFieldState extends State<PhotoUploadField> {
  final List<String> _urls = [];
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    final loc = AppLocalizations.of(context);
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
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
            ],
          ),
        ),
      );
      if (source == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      if (source == ImageSource.gallery && widget.allowMultiple) {
        final files = await ImagePicker().pickMultiImage(
          maxWidth: 1600,
          imageQuality: 80,
        );
        if (files.isEmpty) {
          if (mounted) setState(() => _busy = false);
          return;
        }
        for (final file in files) {
          String? url;
          if (kIsWeb) {
            final bytes = await file.readAsBytes();
            final res = await Api.uploadBytes(
              '/upload/single',
              [MapEntry('file', bytes)],
              filenames: {'file': file.name},
            );
            url = Api.assetUrl(res['url'] as String?);
          } else {
            final res = await Api.upload('/upload/single', [
              MapEntry('file', file.path),
            ]);
            url = Api.assetUrl(res['url'] as String?);
          }
          if (url != null) _urls.add(url);
        }
      } else {
        final file = await ImagePicker().pickImage(
          source: source,
          maxWidth: 1600,
          imageQuality: 80,
        );
        if (file == null) {
          if (mounted) setState(() => _busy = false);
          return;
        }
        String? url;
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          final res = await Api.uploadBytes(
            '/upload/single',
            [MapEntry('file', bytes)],
            filenames: {'file': file.name},
          );
          url = Api.assetUrl(res['url'] as String?);
        } else {
          final res = await Api.upload('/upload/single', [
            MapEntry('file', file.path),
          ]);
          url = Api.assetUrl(res['url'] as String?);
        }
        if (url != null) {
          if (widget.allowMultiple) {
            _urls.add(url);
          } else {
            _urls.clear();
            _urls.add(url);
          }
        }
      }

      setState(() {
        _busy = false;
      });
      widget.onUploaded?.call(_urls.isNotEmpty ? _urls.first : null);
      widget.onPhotosChanged?.call(_urls);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = Api.userMessage(
          e,
          fallback: 'Could not upload the photo. Try again later.',
        );
      });
    }
  }

  void _removeAt(int index) {
    setState(() {
      _urls.removeAt(index);
    });
    widget.onUploaded?.call(_urls.isNotEmpty ? _urls.first : null);
    widget.onPhotosChanged?.call(_urls);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final displayLabel =
        widget.label ?? (widget.allowMultiple ? 'Add photos' : 'Add photo');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_urls.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _urls.length + (widget.allowMultiple ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                if (idx == _urls.length && widget.allowMultiple) {
                  return InkWell(
                    onTap: _busy ? null : _pick,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade400,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey.shade50,
                      ),
                      child: Center(
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.add_a_photo_outlined,
                                color: Colors.grey,
                              ),
                      ),
                    ),
                  );
                }
                final u = _urls[idx];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        u,
                        width: 90,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 90,
                          height: 100,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.broken_image,
                            size: 28,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeAt(idx),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_urls.isEmpty)
          OutlinedButton.icon(
            onPressed: _busy ? null : _pick,
            icon: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera_alt_outlined),
            label: Text(_busy ? loc.uploading : displayLabel),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
