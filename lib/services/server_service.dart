import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/v2ray_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

class ServerService {
  /// GitHub raw base URL — ganti ke repo milikmu setelah push ke GitHub.
  /// Format: https://raw.githubusercontent.com/USERNAME/REPO/main/assets/config_vpn/
  static const String _kRawBase =
      'https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME/main/assets/config_vpn/';

  /// Remote URLs — in priority order (freshest first).
  static const List<String> kDefaultConfigUrls = [
    '${_kRawBase}configs4.txt',  // < 1 hour — freshest
    '${_kRawBase}configs.txt',   // 65 rotated
    '${_kRawBase}configs2.txt',  // 1 000 pool
    '${_kRawBase}configs3.txt',  // 3 000 chronological
  ];

  /// Bundled asset paths — same priority order.
  static const List<String> kBundledAssets = [
    'assets/config_vpn/configs4.txt',
    'assets/config_vpn/configs.txt',
    'assets/config_vpn/configs2.txt',
    'assets/config_vpn/configs3.txt',
  ];

  // ─── Bundled (offline) ───────────────────────────────────────────────────

  /// Load and merge all 4 bundled config files (offline fallback).
  /// Deduplicates by [fullConfig] so identical VPN links don't appear twice.
  Future<List<V2RayConfig>> loadBundledConfigs() async {
    final seen = <String>{};
    final result = <V2RayConfig>[];
    for (final asset in kBundledAssets) {
      try {
        final content = await rootBundle.loadString(asset);
        final configs = _parseConfigText(content);
        for (final c in configs) {
          if (seen.add(c.fullConfig)) result.add(c);
        }
        debugPrint('Bundled $asset → ${configs.length} configs');
      } catch (e) {
        debugPrint('Could not load bundled asset $asset: $e');
      }
    }
    debugPrint('loadBundledConfigs total: ${result.length} unique configs');
    return result;
  }

  // ─── Remote + fallback ───────────────────────────────────────────────────

  /// Fetch and merge all 4 remote config files.
  /// Falls back to the corresponding bundled file if a remote fetch fails.
  Future<List<V2RayConfig>> fetchServersWithFallback() async {
    final seen = <String>{};
    final result = <V2RayConfig>[];

    for (int i = 0; i < kDefaultConfigUrls.length; i++) {
      List<V2RayConfig> batch = [];
      try {
        batch = await fetchServers(customUrl: kDefaultConfigUrls[i]);
        debugPrint('Remote ${kDefaultConfigUrls[i]} → ${batch.length} configs');
      } catch (e) {
        debugPrint('Remote fetch failed for ${kDefaultConfigUrls[i]}: $e — using bundled');
        try {
          final content = await rootBundle.loadString(kBundledAssets[i]);
          batch = _parseConfigText(content);
          debugPrint('Bundled fallback ${kBundledAssets[i]} → ${batch.length} configs');
        } catch (e2) {
          debugPrint('Bundled fallback also failed: $e2');
        }
      }
      for (final c in batch) {
        if (seen.add(c.fullConfig)) result.add(c);
      }
    }

    if (result.isEmpty) {
      debugPrint('All remote sources failed — loading full bundled fallback');
      return loadBundledConfigs();
    }

    debugPrint('fetchServersWithFallback total: ${result.length} unique configs');
    return result;
  }

  Future<List<V2RayConfig>> fetchServers({required String customUrl}) async {
    try {
      final url = customUrl;
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw Exception('Network timeout: Check your internet connection');
            },
          );

      if (response.statusCode == 200) {
        final servers = _parseConfigText(response.body);
        debugPrint('Successfully parsed ${servers.length} servers from $url');
        return servers;
      } else {
        throw Exception('Failed to load servers: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching servers: $e');
      rethrow;
    }
  }

  /// Parse raw config text (one URI or JSON per line) into [V2RayConfig] list.
  List<V2RayConfig> _parseConfigText(String text) {
    final List<V2RayConfig> servers = [];
    final lines = text.split('\n');
    debugPrint('Parsing ${lines.length} lines of config text');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      debugPrint(
        'Processing line: ${line.substring(0, line.length > 30 ? 30 : line.length)}...',
      );

      try {
        // Try to parse as JSON first
        if (line.startsWith('{') && line.endsWith('}')) {
          final serverJson = jsonDecode(line);
          final config = _parseJsonConfig(serverJson);
          if (config != null) {
            servers.add(config);
            debugPrint('Added JSON config: ${config.remark}');
          }
        }
        // If not JSON, try to parse as a V2Ray URI (vmess://, vless://, etc.)
        else if (line.contains('://')) {
          final config = _parseUriConfig(line);
          if (config != null) {
            servers.add(config);
            debugPrint('Added URI config: ${config.remark}');
          } else {
            debugPrint(
              'Failed to parse URI: ${line.substring(0, line.length > 30 ? 30 : line.length)}...',
            );
          }
        } else {
          debugPrint(
            'Line is not JSON or URI format: ${line.substring(0, line.length > 30 ? 30 : line.length)}...',
          );
        }
      } catch (e) {
        debugPrint('Error parsing server line: $e');
      }
    }
    return servers;
  }

  // Parse a JSON configuration
  V2RayConfig? _parseJsonConfig(Map<String, dynamic> json) {
    try {
      return V2RayConfig(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        remark: json['remark'] ?? json['ps'] ?? 'Unknown Server',
        address: json['address'] ?? json['add'] ?? '',
        port:
            int.tryParse(json['port']?.toString() ?? '') ??
            int.tryParse(json['port']?.toString() ?? '') ??
            443,
        configType: json['type'] ?? json['net'] ?? 'vmess',
        fullConfig: jsonEncode(json),
      );
    } catch (e) {
      debugPrint('Error parsing JSON config: $e');
      return null;
    }
  }

  // Parse a URI configuration (vmess://, vless://, etc.)
  V2RayConfig? _parseUriConfig(String uri) {
    try {
      debugPrint(
        'Parsing URI: ${uri.substring(0, uri.length > 30 ? 30 : uri.length)}...',
      );

      // Use V2ray to parse the URL
      if (uri.startsWith('vmess://') ||
          uri.startsWith('vless://') ||
          uri.startsWith('trojan://') ||
          uri.startsWith('ss://')) {
        try {
          V2RayURL parser = V2ray.parseFromURL(uri);
          String configType = '';

          if (uri.startsWith('vmess://')) {
            configType = 'vmess';
          } else if (uri.startsWith('vless://')) {
            configType = 'vless';
          } else if (uri.startsWith('ss://')) {
            configType = 'shadowsocks';
          } else if (uri.startsWith('trojan://')) {
            configType = 'trojan';
          }

          // Use the parsed address and port from the V2RayURL parser
          String address = parser.address;
          int port = parser.port;

          debugPrint(
            'Parsed URI with V2ray: remark=${parser.remark}, address=$address, port=$port',
          );

          return V2RayConfig(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            remark: parser.remark,
            address: address,
            port: port,
            configType: configType,
            fullConfig: uri,
          );
        } catch (e) {
          debugPrint('Error parsing with V2ray: $e');
          return null;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error parsing URI config: $e');
      return null;
    }
  }
}