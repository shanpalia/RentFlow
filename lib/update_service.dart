import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

const rentFlowCurrentVersion = '1.0.0';
const rentFlowCurrentBuild = 2;
const rentFlowUpdateManifest =
    'https://shanpalia.github.io/WebsitePaliaAPK_V.2/rentflow_update.json';

class UpdateInfo {
  final String version;
  final int build;
  final String updateUrl;
  final String apkUrl;
  final String releaseNotes;
  final bool forceUpdate;

  const UpdateInfo({
    required this.version,
    required this.build,
    required this.updateUrl,
    required this.apkUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });

  bool get isNewer =>
      build > rentFlowCurrentBuild ||
      _compareVersion(version, rentFlowCurrentVersion) > 0;

  static int _compareVersion(String a, String b) {
    final av = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bv = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final x = i < av.length ? av[i] : 0;
      final y = i < bv.length ? bv[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}

class UpdateService {
  static Future<UpdateInfo?> check() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client
          .getUrl(Uri.parse(rentFlowUpdateManifest))
          .timeout(const Duration(seconds: 6));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response =
          await request.close().timeout(const Duration(seconds: 6));
      if (response.statusCode != HttpStatus.ok) return null;
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      return UpdateInfo(
        version: '${data['latest_version'] ?? rentFlowCurrentVersion}',
        build: int.tryParse(
                '${data['latest_version_code'] ?? rentFlowCurrentBuild}') ??
            rentFlowCurrentBuild,
        updateUrl: '${data['update_url'] ?? data['apk_url'] ?? ''}',
        apkUrl: '${data['apk_url'] ?? data['update_url'] ?? ''}',
        releaseNotes:
            '${data['release_notes'] ?? 'New improvements are available.'}',
        forceUpdate: data['force_update'] == true,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<bool> openUpdate(UpdateInfo info) async {
    final url = info.apkUrl.isNotEmpty ? info.apkUrl : info.updateUrl;
    if (url.isEmpty) return false;
    return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
