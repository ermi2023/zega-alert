import 'dart:io';

/// Returns the IPv4 /24 subnets (e.g. "192.168.1") the device is currently on,
/// so the app can scan the local network for the backend instead of relying on
/// a hardcoded IP that changes with DHCP.
Future<List<String>> localIpv4Subnets() async {
  final subnets = <String>{};
  try {
    final ifaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final iface in ifaces) {
      for (final addr in iface.addresses) {
        final ip = addr.address;
        if (ip.startsWith('127.')) continue;
        final parts = ip.split('.');
        if (parts.length == 4) subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
      }
    }
  } catch (_) {}
  return subnets.toList();
}
