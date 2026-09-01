import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ServerDiscoveryResult {
  final bool success;
  final String? discoveredUrl;
  final String message;

  ServerDiscoveryResult({required this.success, this.discoveredUrl, required this.message});
}

class ServerDiscoveryService {
  static const int serverPort = 8000;

  /// Tests if a candidate URL is a valid LAN Music Server.
  static Future<bool> testUrl(String baseUrl, {int timeoutMs = 600}) async {
    try {
      var base = baseUrl.trim();
      while (base.endsWith('/')) {
        base = base.substring(0, base.length - 1);
      }
      final uri = Uri.parse('$base/api/health');
      final response = await http.get(uri).timeout(Duration(milliseconds: timeoutMs));
      if (response.statusCode == 200 && response.body.contains('"status":"ok"')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Automatically discovers the LAN Music Server on the current local Wi-Fi network.
  static Future<ServerDiscoveryResult> discoverServer() async {
    // 1. Try currently configured URL
    if (await testUrl(ApiConfig.baseUrl, timeoutMs: 1000)) {
      return ServerDiscoveryResult(
        success: true,
        discoveredUrl: ApiConfig.baseUrl,
        message: 'Connected to configured server: ${ApiConfig.baseUrl}',
      );
    }

    // 2. Try mDNS hostname (lanmusic.local)
    const mdnsUrl = 'http://lanmusic.local:8000';
    if (await testUrl(mdnsUrl, timeoutMs: 1000)) {
      await ApiConfig.setBaseUrl(mdnsUrl);
      return ServerDiscoveryResult(
        success: true,
        discoveredUrl: mdnsUrl,
        message: 'Discovered server via mDNS: $mdnsUrl',
      );
    }

    // 3. Scan local Wi-Fi subnet dynamically
    final subnets = await _getLocalSubnets();
    if (subnets.isEmpty) {
      return ServerDiscoveryResult(
        success: false,
        message: 'No local Wi-Fi network interface detected.',
      );
    }

    for (final subnet in subnets) {
      debugPrint('Scanning Wi-Fi subnet: $subnet.1 - $subnet.254');
      
      // Batch scan 254 IPs in parallel with 400ms timeout
      final completer = Completer<String?>();
      int pending = 254;

      for (int i = 1; i <= 254; i++) {
        final targetIp = '$subnet.$i';
        final candidateUrl = 'http://$targetIp:$serverPort';

        testUrl(candidateUrl, timeoutMs: 500).then((isValid) {
          if (isValid && !completer.isCompleted) {
            completer.complete(candidateUrl);
          } else {
            pending--;
            if (pending == 0 && !completer.isCompleted) {
              completer.complete(null);
            }
          }
        }).catchError((_) {
          pending--;
          if (pending == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        });
      }

      final foundUrl = await completer.future;
      if (foundUrl != null) {
        await ApiConfig.setBaseUrl(foundUrl);
        return ServerDiscoveryResult(
          success: true,
          discoveredUrl: foundUrl,
          message: 'Dynamically discovered server IP: $foundUrl',
        );
      }
    }

    return ServerDiscoveryResult(
      success: false,
      message: 'Music server not found on local Wi-Fi. Ensure PC server is running.',
    );
  }

  /// Finds local IPv4 subnets (e.g. ['192.168.31', '192.168.1'])
  static Future<List<String>> _getLocalSubnets() async {
    final Set<String> subnets = {};
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          if (!ip.startsWith('127.') && !ip.startsWith('169.254.')) {
            final parts = ip.split('.');
            if (parts.length == 4) {
              subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting local network interfaces: $e');
    }
    
    // Default fallback subnets
    if (subnets.isEmpty) {
      subnets.addAll(['192.168.31', '192.168.1', '192.168.0', '192.168.43', '10.0.0']);
    }

    return subnets.toList();
  }
}
