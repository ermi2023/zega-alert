import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static Future<bool> isConnected() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  static Stream<bool> get onConnectivityChanged {
    return Connectivity().onConnectivityChanged.map((results) {
      return results.any((r) => r != ConnectivityResult.none);
    });
  }
}
