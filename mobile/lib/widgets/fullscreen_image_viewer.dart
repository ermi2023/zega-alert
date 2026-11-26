import 'package:flutter/material.dart';

import 'offline_person_image.dart';

class FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String title;
  final Widget? details;
  final bool cachePersonPhotos;

  const FullscreenImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    required this.title,
    this.details,
    this.cachePersonPhotos = false,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _detailsVisible = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.85),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.images.length > 1)
              Text(
                '${_currentIndex + 1} of ${widget.images.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
      ),
      body: widget.images.isEmpty
          ? const Center(
              child: Text(
                'No image available',
                style: TextStyle(color: Colors.white),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: widget.images.length,
                        onPageChanged: (index) {
                          setState(() => _currentIndex = index);
                        },
                        itemBuilder: (context, index) {
                          return InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Center(
                              child: widget.cachePersonPhotos
                                  ? OfflinePersonImage(
                                      url: widget.images[index],
                                      fit: BoxFit.contain,
                                      placeholder: const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                      errorBuilder: (_, __, ___) =>
                                          const Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.broken_image,
                                                size: 64,
                                                color: Colors.white54,
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Failed to load image',
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            ],
                                          ),
                                    )
                                  : Image.network(
                                      widget.images[index],
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) =>
                                          const Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.broken_image,
                                                size: 64,
                                                color: Colors.white54,
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Failed to load image',
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            ],
                                          ),
                                    ),
                            ),
                          );
                        },
                      ),
                      if (widget.images.length > 1)
                        Positioned(
                          top: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(widget.images.length, (
                              idx,
                            ) {
                              return Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentIndex == idx
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                                ),
                              );
                            }),
                          ),
                        ),
                      if (widget.details != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            alignment: Alignment.bottomCenter,
                            child: _detailsVisible
                                ? Container(
                                    key: const ValueKey('image-details'),
                                    constraints: BoxConstraints(
                                      maxHeight:
                                          MediaQuery.sizeOf(context).height *
                                          0.4,
                                    ),
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    color: Colors.black.withOpacity(0.72),
                                    child: SingleChildScrollView(
                                      child: widget.details!,
                                    ),
                                  )
                                : const SizedBox(
                                    key: ValueKey('no-image-details'),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.details != null)
                  SafeArea(
                    top: false,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => _detailsVisible = !_detailsVisible);
                      },
                      icon: Icon(
                        _detailsVisible ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white,
                      ),
                      label: Text(
                        _detailsVisible ? 'Read less' : 'Read more',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
