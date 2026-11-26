import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/api.dart';
import 'qr_scan_screen.dart';

class IdVerificationScreen extends StatefulWidget {
  const IdVerificationScreen({super.key});

  @override
  State<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends State<IdVerificationScreen> {
  final _fanNumber = TextEditingController();
  String _status = 'not_verified';
  Map<String, dynamic>? _mockRecord;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _fanNumber.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final data = await Api.get('/verification/status');
      if (mounted) {
        setState(() {
          _status = data['status'] ?? 'not_verified';
          final record = data['mock_record'];
          _mockRecord = record is Map
              ? Map<String, dynamic>.from(record)
              : null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = Api.userMessage(
            error,
            fallback: 'Verification status is unavailable right now. Try again later.',
          );
        });
      }
    }
  }

  Future<void> _verifyFan() async {
    final fanNumber = _fanNumber.text.trim();
    if (!RegExp(r'^\d{16}$').hasMatch(fanNumber)) {
      setState(() => _message = 'Enter a valid 16-digit FAN number.');
      return;
    }

    await _submitVerification('/verification/fan', {'fan_number': fanNumber});
  }

  Future<void> _scanAndVerify() async {
    final qrData = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScanScreen(title: 'Scan original ID QR'),
      ),
    );
    if (!mounted || qrData == null) return;
    await _submitVerification('/verification/qr', {'qr_data': qrData});
  }

  Future<void> _submitVerification(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final response = await Api.post(endpoint, body);
      final result = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _status = result['status']?.toString() ?? 'not_verified';
        _message = result['message']?.toString();
        final record = result['mock_record'];
        _mockRecord = record is Map ? Map<String, dynamic>.from(record) : null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = Api.userMessage(
            error,
            fallback: 'We could not verify this FAN right now. Please try again later.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final verified = _status == 'verified';
    final messageColor = verified ? Colors.green : Colors.blue;

    return Scaffold(
      appBar: AppBar(title: const Text('FAN Identity Verification')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: verified ? Colors.green.shade50 : Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    verified ? Icons.verified : Icons.info_outline,
                    color: messageColor,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          verified ? loc.verified : loc.notVerified,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: messageColor,
                          ),
                        ),
                        Text(
                          verified
                              ? 'Your FAN number matched an active record.'
                              : 'Enter a FAN number added by an administrator. '
                                    'Numbers not in the records remain unverified.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!verified) ...[
            const SizedBox(height: 20),
            const Text(
              'Verify with your original ID',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan the QR code on your original ID or enter its 16-digit FAN. '
              'The app checks only the FAN against the administrator’s mock '
              'record and displays the saved mock details, not QR contents.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _scanAndVerify,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan original ID QR'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fanNumber,
              keyboardType: TextInputType.number,
              maxLength: 16,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'FAN number',
                hintText: '16 digits',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.badge_outlined),
                suffixIcon: IconButton(
                  tooltip: 'Clear FAN number',
                  onPressed: _busy ? null : _fanNumber.clear,
                  icon: const Icon(Icons.clear),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _verifyFan,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.verified_user),
              label: Text(_busy ? 'Checking FAN…' : 'Verify FAN'),
            ),
          ],
          if (verified && _mockRecord != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Matched administrator record (mock data)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _recordDetail('Name', _mockRecord!['full_name']),
                    _recordDetail('Phone', _mockRecord!['phone']),
                    _recordDetail('FAN number', _mockRecord!['fan_number']),
                  ],
                ),
              ),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Card(
              color: messageColor.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _message!,
                  style: TextStyle(color: messageColor.shade700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recordDetail(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 92, child: Text(label)),
        Expanded(child: Text(value?.toString() ?? '—')),
      ],
    ),
  );
}
