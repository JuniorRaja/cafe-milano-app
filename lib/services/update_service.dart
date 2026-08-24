import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _releasesUrl =
    'https://api.github.com/repos/JuniorRaja/cafe-milano-app/releases/latest';
final _tagPattern = RegExp(r'^v(.+)-(\d+)$');

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
  });

  final String version;
  final String releaseNotes;
  final String downloadUrl;
}

/// Thrown when the update check itself fails — network, timeout, or an
/// unexpected response from GitHub. Distinct from "no update available",
/// which is a normal `null` result.
class UpdateCheckException implements Exception {
  UpdateCheckException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Checks GitHub for a release newer than [installedBuild].
/// Returns null when already up to date. Throws [UpdateCheckException] on
/// any failure — no network, timeout, bad response, missing APK asset —
/// so callers can tell "up to date" apart from "couldn't check".
Future<UpdateInfo?> checkForUpdate(int installedBuild) async {
  final client = HttpClient();
  try {
    final request = await client
        .getUrl(Uri.parse(_releasesUrl))
        .timeout(const Duration(seconds: 10));
    request.headers
        .set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final response =
        await request.close().timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      await response.drain<void>();
      throw UpdateCheckException(
          'GitHub returned an error (HTTP ${response.statusCode}). Please try again later.');
    }

    final body = await response.transform(utf8.decoder).join();
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw UpdateCheckException(
          'Received an unexpected response from GitHub.');
    }

    final match = _tagPattern.firstMatch(json['tag_name'] as String? ?? '');
    if (match == null) {
      throw UpdateCheckException(
          'Received an unexpected response from GitHub.');
    }
    final remoteBuild = int.parse(match.group(2)!);
    if (remoteBuild <= installedBuild) return null;

    final assets = (json['assets'] as List?) ?? const [];
    final apkAsset = assets.cast<Map<String, dynamic>>().firstWhere(
          (asset) => (asset['name'] as String? ?? '').endsWith('.apk'),
          orElse: () => <String, dynamic>{},
        );
    final downloadUrl = apkAsset['browser_download_url'] as String?;
    if (downloadUrl == null) {
      throw UpdateCheckException(
          'The latest release has no APK attached. Please try again later.');
    }

    final notes = (json['body'] as String?)?.trim();
    return UpdateInfo(
      version: match.group(1)!,
      releaseNotes: notes?.isNotEmpty == true ? notes! : 'No release notes.',
      downloadUrl: downloadUrl,
    );
  } on UpdateCheckException {
    rethrow;
  } on TimeoutException {
    throw UpdateCheckException('The update check timed out. Please try again.');
  } on SocketException {
    throw UpdateCheckException(
        'No internet connection. Check your network and try again.');
  } catch (e) {
    throw UpdateCheckException('Could not check for updates: $e');
  } finally {
    client.close(force: true);
  }
}
