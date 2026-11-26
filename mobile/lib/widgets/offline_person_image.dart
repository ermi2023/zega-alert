import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/person_image_cache_service.dart';

class OfflinePersonImage extends StatefulWidget {
  const OfflinePersonImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorBuilder,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  State<OfflinePersonImage> createState() => _OfflinePersonImageState();
}

class _OfflinePersonImageState extends State<OfflinePersonImage> {
  ImageProvider<Object>? _provider;
  bool _loading = true;
  bool _useNetworkImage = false;
  Object? _error;
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    PersonImageCacheService.enabled.addListener(_preferenceChanged);
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant OfflinePersonImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _loadImage();
  }

  @override
  void dispose() {
    PersonImageCacheService.enabled.removeListener(_preferenceChanged);
    super.dispose();
  }

  void _preferenceChanged() => _loadImage();

  Future<void> _loadImage() async {
    final loadId = ++_loadId;
    final shouldCache = !kIsWeb && PersonImageCacheService.enabled.value;
    if (!shouldCache) {
      if (mounted) {
        setState(() {
          _provider = null;
          _loading = false;
          _useNetworkImage = true;
          _error = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _provider = null;
        _loading = true;
        _useNetworkImage = false;
        _error = null;
      });
    }

    try {
      var provider = await PersonImageCacheService.cachedImage(widget.url);
      if (provider == null) {
        final response = await http
            .get(Uri.parse(widget.url))
            .timeout(const Duration(seconds: 20));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw http.ClientException(
            'Image request failed with status ${response.statusCode}.',
            Uri.parse(widget.url),
          );
        }
        final bytes = response.bodyBytes;
        provider = MemoryImage(bytes);
        if (PersonImageCacheService.enabled.value) {
          try {
            provider =
                await PersonImageCacheService.storeImage(widget.url, bytes) ??
                provider;
          } catch (error) {
            debugPrint('Could not cache wanted/missing person photo: $error');
          }
        }
      }
      if (!mounted || loadId != _loadId) return;
      setState(() {
        _provider = provider;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || loadId != _loadId) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Widget _buildError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return widget.errorBuilder?.call(context, error, stackTrace) ??
        const ColoredBox(
          color: Color(0xFFE5E7EB),
          child: Center(child: Icon(Icons.person_outline, color: Colors.grey)),
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.placeholder ??
          const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_useNetworkImage) {
      return Image.network(
        widget.url,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: _buildError,
      );
    }
    final provider = _provider;
    if (provider != null) {
      return Image(
        image: provider,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: _buildError,
      );
    }
    return _buildError(
      context,
      _error ?? StateError('Image unavailable.'),
      null,
    );
  }
}
