import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import 'qr_scan_screen.dart';

class IdVerificationScreen extends StatefulWidget {
  const IdVerificationScreen({super.key});

  @override
  State<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends State<IdVerificationScreen> {
  String _status = 'not_verified';
  XFile? _idFile;
  Uint8List? _idBytes;
  final _idNumber = TextEditingController();
  final _fullName = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final data = await Api.get('/verification/status');
      setState(() => _status = data['status'] ?? 'not_verified');
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final loc = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1920, imageQuality: 85);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() { _idFile = picked; _idBytes = bytes; });
    }
  }

  Future<void> _scanQr() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (raw == null || raw.isEmpty) return;
    setState(() { _busy = true; _message = null; });
    try {
      final result = await Api.post('/verification/qr', {
        'qr_data': raw,
        'full_name': _fullName.text.trim().isNotEmpty ? _fullName.text.trim() : null,
      });
      setState(() {
        _status = result['status'] ?? 'verified';
        _message = result['message'] ?? 'Verified via Fayda QR.';
      });
    } catch (e) {
      setState(() => _message = 'Failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context);
    if (_idFile == null || _idNumber.text.trim().isEmpty) {
      setState(() => _message = loc.idNumberPhotoRequired);
      return;
    }

    setState(() { _busy = true; _message = null; });
    try {
      final uploadResult = await Api.upload('/upload/single', [MapEntry('file', _idFile!.path)]);
      final result = await Api.post('/verification/submit', {
        'id_number': _idNumber.text.trim(),
        'id_image_url': '${Api.baseUrl}${uploadResult['url']}',
        'full_name': _fullName.text.trim().isNotEmpty ? _fullName.text.trim() : null,
      });

      setState(() {
        _status = result['status'] ?? 'verified';
        _message = result['message'] ?? loc.verificationSubmitted;
      });
    } catch (e) {
      setState(() => _message = 'Failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final verified = _status == 'verified';
    return Scaffold(
      appBar: AppBar(title: Text(loc.faydaIdVerification)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: verified ? Colors.green.shade50 : Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(verified ? Icons.verified : Icons.info_outline, color: verified ? Colors.green : Colors.blue, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(verified ? loc.verified : loc.notVerified,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: verified ? Colors.green : Colors.blue)),
                        Text(verified ? loc.identityVerifiedDesc : loc.verifyIdentityDesc,
                          style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (!verified) ...[
            Text(loc.scanFaydaId, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(loc.scanIdInstruction, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _scanQr,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Fayda QR code'),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _idBytes != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(_idBytes!, fit: BoxFit.cover))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.credit_card, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(loc.tapToScanId, style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _idNumber,
              decoration: InputDecoration(
                labelText: loc.faydaIdNumber,
                hintText: loc.faydaIdHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fullName,
              decoration: InputDecoration(
                labelText: loc.fullNameAsOnId,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.verified_user),
              label: Text(_busy ? loc.verifying : loc.submitForVerification),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Card(
              color: _message!.startsWith('Failed') ? Colors.red.shade50 : Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_message!, style: TextStyle(color: _message!.startsWith('Failed') ? Colors.red : Colors.green)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
