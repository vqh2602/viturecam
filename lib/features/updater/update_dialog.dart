import 'dart:io';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/update_service.dart';

enum UpdateDialogState {
  idle,
  downloading,
  installing,
  error,
}

class UpdateDialog extends StatefulWidget {
  final AppReleaseInfo release;
  final String currentVersion;
  final UpdateService updateService;

  const UpdateDialog({
    super.key,
    required this.release,
    required this.currentVersion,
    required this.updateService,
  });

  static Future<void> show(
    BuildContext context, {
    required AppReleaseInfo release,
    required String currentVersion,
    required UpdateService updateService,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(
        release: release,
        currentVersion: currentVersion,
        updateService: updateService,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  UpdateDialogState _state = UpdateDialogState.idle;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String _errorMessage = '';
  bool _isCancelled = false;
  File? _downloadedFile;

  void _startUpdate() async {
    setState(() {
      _state = UpdateDialogState.downloading;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = widget.release.dmgSizeBytes;
      _errorMessage = '';
      _isCancelled = false;
    });

    try {
      final dmgFile = await widget.updateService.downloadDmg(
        downloadUrl: widget.release.dmgDownloadUrl,
        targetVersion: widget.release.version,
        onProgress: (received, total) {
          if (!mounted || _isCancelled) return;
          setState(() {
            _receivedBytes = received;
            if (total > 0) {
              _totalBytes = total;
              _progress = received / total;
            }
          });
        },
        isCancelled: () => _isCancelled,
      );

      if (_isCancelled) return;

      _downloadedFile = dmgFile;

      setState(() {
        _state = UpdateDialogState.installing;
      });

      // Gọi native macOS để cài đặt đè bản mới
      await widget.updateService.applyUpdate(dmgFile.path);
    } catch (e) {
      if (!mounted) return;
      if (_isCancelled) return;
      setState(() {
        _state = UpdateDialogState.error;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _cancelDownload() {
    _isCancelled = true;
    setState(() {
      _state = UpdateDialogState.idle;
      _progress = 0.0;
      _receivedBytes = 0;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFF7597).withValues(alpha: 0.3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: const Color(0xFFFF7597).withValues(alpha: 0.15),
              blurRadius: 25,
              spreadRadius: -5,
            ),
          ],
        ),
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon + Title + Version Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7597), Color(0xFFFF5277)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF7597).withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.updateAvailableTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            'v${widget.currentVersion}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFFFF7597)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7597).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFF7597).withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'v${widget.release.version}',
                              style: const TextStyle(
                                color: Color(0xFFFF8DA1),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_state == UpdateDialogState.idle)
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                    splashRadius: 18,
                  ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),

            // Release Notes / Changelog Box
            Text(
              l10n.updateReleaseNotes,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 140,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF141419),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.release.body.trim().isNotEmpty
                      ? widget.release.body
                      : 'Bản cập nhật tối ưu hiệu năng và sửa các lỗi tồn tại.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Progress / Status Section
            if (_state == UpdateDialogState.downloading) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.updateDownloading,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${(_progress * 100).toStringAsFixed(0)}% (${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)})',
                    style: const TextStyle(
                      color: Color(0xFFFF8DA1),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF7597)),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 14),
            ] else if (_state == UpdateDialogState.installing) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF222C24),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.updateInstalling,
                        style: const TextStyle(
                          color: Color(0xFF81C784),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ] else if (_state == UpdateDialogState.error) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF331C1F),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.updateError(_errorMessage),
                        style: const TextStyle(color: Color(0xFFFFB4AB), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_state == UpdateDialogState.idle || _state == UpdateDialogState.error) ...[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white60,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text(l10n.updateLater),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _startUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7597),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(0xFFFF7597).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.download_rounded, size: 17),
                        const SizedBox(width: 6),
                        Text(
                          _state == UpdateDialogState.error ? 'Thử lại' : l10n.updateNow,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ] else if (_state == UpdateDialogState.downloading) ...[
                  OutlinedButton(
                    onPressed: _cancelDownload,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: Text(l10n.updateCancel),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
