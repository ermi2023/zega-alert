import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

/// Wraps `local_auth` so the app can offer biometric (fingerprint/face)
/// unlock for returning users. All calls degrade safely when the device
/// has no biometric hardware or the user has not enrolled any.
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final enrolled = await _auth.getAvailableBiometrics();
      return supported && canCheck && enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate({String reason = 'Authenticate to sign in to ZEGA-ALERT'}) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
