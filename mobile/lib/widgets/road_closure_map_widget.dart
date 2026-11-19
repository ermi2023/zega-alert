import 'dart:math' as math;
import 'package:flutter/material.dart';

class RoadClosureMapWidget extends StatelessWidget {
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final String title;

  const RoadClosureMapWidget({
    super.key,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Map canvas visual with roads & closed segment
          CustomPaint(
            size: const Size(double.infinity, 150),
            painter: _RoadMapPainter(),
          ),

          // Start point marker (Meskel Sq / Start)
          const Positioned(
            left: 110,
            top: 38,
            child: Icon(
              Icons.radio_button_checked,
              color: Color(0xFFD97706),
              size: 16,
            ),
          ),

          // Red destination / pin marker
          const Positioned(
            right: 80,
            bottom: 30,
            child: Icon(
              Icons.location_on,
              color: Color(0xFFDC2626),
              size: 28,
            ),
          ),

          // Expand / Fullscreen icon button
          Positioned(
            right: 8,
            bottom: 8,
            child: InkWell(
              onTap: () {
                _showExpandedMap(context);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.open_in_full_rounded,
                  size: 16,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExpandedMap(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          height: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: const Size(double.infinity, double.infinity),
                        painter: _RoadMapPainter(),
                      ),
                      const Positioned(
                        left: 90,
                        top: 50,
                        child: Icon(Icons.radio_button_checked, color: Color(0xFFD97706), size: 20),
                      ),
                      const Positioned(
                        right: 80,
                        bottom: 60,
                        child: Icon(Icons.location_on, color: Color(0xFFDC2626), size: 36),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Text(
                    startLat != null && endLat != null
                        ? 'Closure: (${startLat!.toStringAsFixed(3)}, ${startLng!.toStringAsFixed(3)}) → (${endLat!.toStringAsFixed(3)}, ${endLng!.toStringAsFixed(3)})'
                        : 'Road closed to general transit — follow municipal detours',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoadMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Map background tiles color
    final bgPaint = Paint()..color = const Color(0xFFE2E8F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Green park/land patches
    final greenPaint = Paint()..color = const Color(0xFFD1FAE5);
    final parkPath = Path()
      ..moveTo(size.width * 0.45, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.8)
      ..lineTo(size.width * 0.5, size.height * 0.45)
      ..close();
    canvas.drawPath(parkPath, greenPaint);

    // Minor roads (grey lines)
    final minorRoadPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.35), minorRoadPaint);
    canvas.drawLine(Offset(size.width * 0.2, 0), Offset(size.width * 0.25, size.height), minorRoadPaint);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.6, size.height), minorRoadPaint);

    // Major road / closed road (Yellow/Amber Arterial road)
    final arterialPaint = Paint()
      ..color = const Color(0xFFFDE68A)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;

    final closedSegmentPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arterialPath = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.6, size.width * 0.4, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.55, size.height * 0.5, size.width * 0.75, size.height * 0.8)
      ..lineTo(size.width, size.height * 0.9);

    canvas.drawPath(arterialPath, arterialPaint);
    canvas.drawPath(arterialPath, closedSegmentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
