import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen scanner for the Fayda National ID QR code.
/// Pops with the raw scanned string (or null if cancelled).
class QrScanScreen extends StatefulWidget {
  final String title;
  const QrScanScreen({super.key, this.title = 'Scan Fayda QR'});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(raw);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Point the camera at the QR code on the Fayda National ID card.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
