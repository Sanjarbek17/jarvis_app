import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../services/remote_control_client.dart';
import '../services/log_service.dart';
import '../utils/platform_util.dart';

class UpdatePanel extends StatefulWidget {
  const UpdatePanel({super.key});

  @override
  State<UpdatePanel> createState() => _UpdatePanelState();
}

class _UpdatePanelState extends State<UpdatePanel> {
  bool _isChecking = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = 'App Version: ${RemoteControlClient.appVersion}';
  String? _latestVersion;
  bool _updateAvailable = false;

  String _getHttpUrl() {
    try {
      final wsUri = Uri.parse(remoteControlClient.serverUrl);
      final scheme = wsUri.scheme == 'wss' ? 'https' : 'http';
      return '$scheme://${wsUri.host}:${wsUri.port}';
    } catch (e) {
      return 'http://95.46.161.3:10555';
    }
  }

  Future<void> _checkForUpdate() async {
    if (_isChecking || _isDownloading) return;

    setState(() {
      _isChecking = true;
      _statusMessage = 'Checking for updates...';
    });

    try {
      final httpUrl = _getHttpUrl();
      final dio = Dio();
      final response = await dio.get('$httpUrl/version');
      
      if (response.statusCode == 200 && response.data != null) {
        final latest = response.data['latest_version'] as String;
        final current = RemoteControlClient.appVersion;
        
        setState(() {
          _latestVersion = latest;
          _isChecking = false;
          if (latest != current) {
            _updateAvailable = true;
            _statusMessage = 'New version available: $latest';
          } else {
            _updateAvailable = false;
            _statusMessage = 'Up to date (Version $current)';
          }
        });
      } else {
        throw Exception('Invalid server response');
      }
    } catch (e) {
      logger.log('Update check error: $e');
      setState(() {
        _isChecking = false;
        _statusMessage = 'Failed to check: Server offline';
      });
    }
  }

  Future<void> _downloadAndInstall() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Downloading update...';
    });

    try {
      final httpUrl = _getHttpUrl();
      final tempDir = await getTemporaryDirectory();
      final apkPath = '${tempDir.path}/app-update.apk';
      
      final dio = Dio();
      await dio.download(
        '$httpUrl/apk',
        apkPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      setState(() {
        _isDownloading = false;
        _statusMessage = 'Download complete. Installing...';
      });

      final success = await PlatformUtil.installApk(apkPath);
      if (!success) {
        setState(() {
          _statusMessage = 'Failed to start installation';
        });
      }
    } catch (e) {
      logger.log('Download error: $e');
      setState(() {
        _isDownloading = false;
        _statusMessage = 'Download failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.system_update_alt,
                color: _updateAvailable ? Colors.blueAccent : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SYSTEM UPDATE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                minHeight: 6,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_updateAvailable)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Update Now'),
                  onPressed: _isDownloading ? null : _downloadAndInstall,
                )
              else
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white60,
                  ),
                  icon: _isChecking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white60),
                          ),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(_isChecking ? 'Checking...' : 'Check Update'),
                  onPressed: _isChecking ? null : _checkForUpdate,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
